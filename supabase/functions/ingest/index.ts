// deno-lint-ignore-file no-explicit-any
import { createClient } from "npm:@supabase/supabase-js@2";

// Project URL hardcoded (geen SUPABASE_* env variabelen hier)
const PROJECT_REF = "rhfhateyqdiysgooiqtd";
const supabaseUrl = `https://${PROJECT_REF}.supabase.co`;

// Secrets uit Function Secrets (CLI: supabase secrets set …)
const supabaseKey = Deno.env.get("SERVICE_ROLE_KEY");
const expectedIngestToken = Deno.env.get("ANALYTICS_INGEST_TOKEN");
if (!supabaseKey) throw new Error("SERVICE_ROLE_KEY not configured");
if (!expectedIngestToken) throw new Error("ANALYTICS_INGEST_TOKEN not configured");

// Supabase client met service role (bypasst RLS)
const supabase = createClient(supabaseUrl, supabaseKey);

// CORS
const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type, x-analytics-token",
  "access-control-allow-methods": "POST, OPTIONS",
  "content-type": "application/json",
};

// Helper: force array
function toArray<T>(x: T | T[] | null | undefined): T[] {
  if (!x) return [];
  return Array.isArray(x) ? x : [x];
}

// Denormalize 1 event → db row
function normalizeEvent(e: any) {
  return {
    event_name: String(e.event_name ?? ""),
    user_id: e.user_id ?? null,
    session_id: e.session_id ?? null,
    platform: e.platform ?? null,
    app_version: e.app_version ?? null,
    build: e.build ?? null,
    provider: e.provider ?? null,
    properties: e.properties ?? null,
  };
}

// Helper: Get current period (YYYY-MM)
function getCurrentPeriod(): string {
  return new Date().toISOString().slice(0, 7);
}

// Helper: Get previous period (YYYY-MM)
function getPreviousPeriod(currentPeriod: string): string {
  const [year, month] = currentPeriod.split("-").map(Number);
  const date = new Date(year, month - 1, 1); // month is 0-indexed
  date.setMonth(date.getMonth() - 1); // Go back one month
  const prevYear = date.getFullYear();
  const prevMonth = String(date.getMonth() + 1).padStart(2, "0");
  return `${prevYear}-${prevMonth}`;
}

// Route handlers
async function handleUsageCheck(body: any) {
  const { user_key } = body;
  if (!user_key) {
    return { status: 400, data: { error: "user_key required" } };
  }

  const currentPeriod = getCurrentPeriod();

  const { data: usage, error } = await supabase
    .from("user_usage")
    .select("*")
    .eq("user_key", user_key)
    .eq("period_ym", currentPeriod)
    .single();

  if (error || !usage) {
    // Return default for new users
    return {
      status: 200,
      data: {
        secondsUsed: 0,
        limitSeconds: 1800, // 30 min free tier
        currentPlan: "free",
      },
    };
  }

  // ⭐ KEY: Return combined limit (subscription + top-ups)
  return {
    status: 200,
    data: {
      secondsUsed: usage.seconds_used,
      limitSeconds:
        usage.subscription_seconds_limit +
        (usage.topup_seconds_available || 0),
      currentPlan: usage.plan,
    },
  };
}

async function handleUsageBook(body: any) {
  const { user_key, seconds, plan, recorded_at } = body;
  if (!user_key || !seconds) {
    return { status: 400, data: { error: "user_key and seconds required" } };
  }

  const currentPeriod = getCurrentPeriod();

  // Get or create user_usage record
  const { data: usage } = await supabase
    .from("user_usage")
    .select("*")
    .eq("user_key", user_key)
    .eq("period_ym", currentPeriod)
    .maybeSingle();

  let secondsUsed = 0;
  let topupAvailable = 0;
  let subscriptionLimit = 1800; // Default free tier
  let userPlan = plan || "free";

  if (usage) {
    secondsUsed = usage.seconds_used || 0;
    topupAvailable = usage.topup_seconds_available || 0;
    subscriptionLimit = usage.subscription_seconds_limit || 1800;
    userPlan = usage.plan;
  } else {
    // No record for current period - check previous month for carried-over top-up
    const previousPeriod = getPreviousPeriod(currentPeriod);
    const { data: previousUsage } = await supabase
      .from("user_usage")
      .select("topup_seconds_available, plan, subscription_seconds_limit")
      .eq("user_key", user_key)
      .eq("period_ym", previousPeriod)
      .maybeSingle();

    if (previousUsage) {
      userPlan = previousUsage.plan || userPlan;
      subscriptionLimit = previousUsage.subscription_seconds_limit || subscriptionLimit;
      topupAvailable = previousUsage.topup_seconds_available || 0;
      console.log(`📊 handleUsageBook: Carrying over ${topupAvailable}s top-up from ${previousPeriod}`);
    }
  }

  // ⭐ KEY: Deduct from top-up first, then subscription
  let remainingToDeduct = seconds;
  let newTopupAvailable = topupAvailable;
  let newSecondsUsed = secondsUsed;

  if (topupAvailable >= remainingToDeduct) {
    // All from top-up
    newTopupAvailable = topupAvailable - remainingToDeduct;
  } else {
    // Use all top-up, rest from subscription
    remainingToDeduct -= topupAvailable;
    newTopupAvailable = 0;
    newSecondsUsed = secondsUsed + remainingToDeduct;
  }

  // Check if over limit
  const totalLimit = subscriptionLimit + newTopupAvailable;
  const totalUsed = newSecondsUsed;
  if (totalUsed > subscriptionLimit && newTopupAvailable === 0) {
    return {
      status: 403,
      data: { error: "quota_exceeded", message: "Insufficient balance" },
    };
  }

  // Update or insert
  if (usage) {
    const { error: updateError } = await supabase
      .from("user_usage")
      .update({
        seconds_used: newSecondsUsed,
        topup_seconds_available: newTopupAvailable,
      })
      .eq("user_key", user_key)
      .eq("period_ym", currentPeriod);

    if (updateError) {
      console.error("Update error:", updateError);
      return { status: 500, data: { error: "db_update_failed" } };
    }
  } else {
    const { error: insertError } = await supabase
      .from("user_usage")
      .insert({
        user_key,
        period_ym: currentPeriod,
        plan: userPlan,
        seconds_used: newSecondsUsed,
        subscription_seconds_limit: subscriptionLimit,
        topup_seconds_available: newTopupAvailable,
      });

    if (insertError) {
      console.error("Insert error:", insertError);
      return { status: 500, data: { error: "db_insert_failed" } };
    }
  }

  return {
    status: 200,
    data: {
      success: true,
      seconds_used: newSecondsUsed,
      topup_used: topupAvailable - newTopupAvailable,
    },
  };
}

async function handleUsageFetch(body: any) {
  const { user_key, plan: clientPlan } = body;
  if (!user_key) {
    return { status: 400, data: { error: "user_key required" } };
  }

  const currentPeriod = getCurrentPeriod();

  const { data: usage, error } = await supabase
    .from("user_usage")
    .select("*")
    .eq("user_key", user_key)
    .eq("period_ym", currentPeriod)
    .maybeSingle();

  if (error) {
    console.error("Error fetching usage:", error);
    return { status: 500, data: { error: "database_error" } };
  }

  // Plan limits (in seconds)
  const planLimits: Record<string, number> = {
    free: 1800, // 30 min
    standard: 7200, // 120 min
    premium: 36000, // 600 min
    own_key: 600000, // 10,000 min (safety cap)
  };

  if (!usage) {
    // No record yet - check previous month for carried-over top-up balance
    const previousPeriod = getPreviousPeriod(currentPeriod);
    const { data: previousUsage } = await supabase
      .from("user_usage")
      .select("topup_seconds_available, plan")
      .eq("user_key", user_key)
      .eq("period_ym", previousPeriod)
      .maybeSingle();

    const effectivePlan = clientPlan || previousUsage?.plan || "free";
    const subscriptionLimit = planLimits[effectivePlan] || planLimits.free;
    const carriedOverTopup = previousUsage?.topup_seconds_available || 0;

    console.log(
      `📊 New period for ${user_key}, plan: ${effectivePlan}, limit: ${subscriptionLimit}s, carried-over topup: ${carriedOverTopup}s`,
    );

    // Create new record with carried-over top-up balance
    const insertData = {
      user_key,
      period_ym: currentPeriod,
      month_year: currentPeriod, // Legacy column (same as period_ym)
      plan: effectivePlan,
      seconds_used: 0,
      subscription_seconds_limit: subscriptionLimit,
      topup_seconds_available: carriedOverTopup,
    };
    console.log("📊 Inserting new user_usage record:", insertData);

    const { error: insertError } = await supabase
      .from("user_usage")
      .insert(insertData);

    if (insertError) {
      console.error("❌ Insert error:", insertError);
      return { status: 500, data: { error: "db_insert_failed", details: insertError.message } };
    }

    return {
      status: 200,
      data: {
        user_key,
        period_ym: currentPeriod,
        seconds_used: 0,
        limit_seconds: subscriptionLimit + carriedOverTopup,
        subscription_seconds_limit: subscriptionLimit,
        topup_seconds_available: carriedOverTopup,
        plan: effectivePlan,
      },
    };
  }

  // If client plan differs from stored plan, update it
  const effectivePlan = clientPlan || usage.plan || "free";
  let subscriptionLimit = usage.subscription_seconds_limit;

  if (clientPlan && clientPlan !== usage.plan) {
    // Plan changed - update the record with new plan and limit
    subscriptionLimit = planLimits[clientPlan] || planLimits.free;

    console.log(
      `📊 Plan changed for ${user_key}: ${usage.plan} -> ${clientPlan}, updating limit: ${usage.subscription_seconds_limit}s -> ${subscriptionLimit}s`,
    );

    const { error: updateError } = await supabase
      .from("user_usage")
      .update({
        plan: clientPlan,
        subscription_seconds_limit: subscriptionLimit,
      })
      .eq("user_key", user_key)
      .eq("period_ym", currentPeriod);

    if (updateError) {
      console.error("❌ Error updating plan:", updateError);
    }
  }

  // Return combined limit_seconds for iOS app compatibility
  return {
    status: 200,
    data: {
      user_key: usage.user_key,
      period_ym: usage.period_ym,
      seconds_used: usage.seconds_used,
      subscription_seconds_limit: subscriptionLimit,
      topup_seconds_available: usage.topup_seconds_available || 0,
      plan: effectivePlan,
      limit_seconds:
        subscriptionLimit + (usage.topup_seconds_available || 0),
    },
  };
}

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const path = url.pathname;
    console.log("📍 Request URL:", req.url);
    console.log("📍 Request path:", path);

    // Token check
    const token = req.headers.get("x-analytics-token");
    console.log("🔑 Received token:", token ? `${token.substring(0, 10)}...` : "NONE");
    console.log("🔑 Expected token:", expectedIngestToken ? `${expectedIngestToken.substring(0, 10)}...` : "NONE");
    console.log("🔑 Match:", token === expectedIngestToken);

    if (!token || token !== expectedIngestToken) {
      console.log("❌ Token validation failed");
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: corsHeaders,
      });
    }

    console.log("✅ Token validated successfully");

    // Parse body
    const body = await req.json().catch(() => null);

    // Route to appropriate handler
    if (path.endsWith("/usage/check") || path === "/usage/check") {
      const result = await handleUsageCheck(body);
      return new Response(JSON.stringify(result.data), {
        status: result.status,
        headers: corsHeaders,
      });
    }

    if (path.endsWith("/usage/book") || path === "/usage/book") {
      const result = await handleUsageBook(body);
      return new Response(JSON.stringify(result.data), {
        status: result.status,
        headers: corsHeaders,
      });
    }

    if (path.endsWith("/usage/fetch") || path === "/usage/fetch") {
      console.log("✅ Matched /usage/fetch route");
      const result = await handleUsageFetch(body);
      return new Response(JSON.stringify(result.data), {
        status: result.status,
        headers: corsHeaders,
      });
    }

    // Default: Analytics ingest (original functionality)
    const items = toArray(body);

    if (items.length === 0) {
      return new Response(JSON.stringify({ error: "no_events" }), {
        status: 400,
        headers: corsHeaders,
      });
    }

    // Validatie minimaal veld event_name
    const rows = items.map(normalizeEvent).filter((r) => r.event_name);
    if (rows.length === 0) {
      return new Response(JSON.stringify({ error: "invalid_events" }), {
        status: 400,
        headers: corsHeaders,
      });
    }

    // Insert analytics events
    const { error } = await supabase.from("analytics_events").insert(rows);
    if (error) {
      console.error("DB insert error:", error);
      return new Response(JSON.stringify({ error: "db_insert_failed" }), {
        status: 500,
        headers: corsHeaders,
      });
    }

    return new Response(JSON.stringify({ ok: true, inserted: rows.length }), {
      status: 200,
      headers: corsHeaders,
    });
  } catch (err) {
    console.error("Handler error:", err);
    return new Response(JSON.stringify({ error: "bad_request" }), {
      status: 400,
      headers: corsHeaders,
    });
  }
});
