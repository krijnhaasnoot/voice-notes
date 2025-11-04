// deno-lint-ignore-file no-explicit-any
import { createClient } from "npm:@supabase/supabase-js@2";

// Get secrets from Supabase Edge Function environment
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY");
const expectedToken = Deno.env.get("ANALYTICS_INGEST_TOKEN");

// Validate required secrets
if (!supabaseUrl) throw new Error("SUPABASE_URL not configured");
if (!serviceRoleKey) throw new Error("SERVICE_ROLE_KEY not configured");
if (!expectedToken) throw new Error("ANALYTICS_INGEST_TOKEN not configured");

// Create Supabase client with service role (bypasses RLS)
const supabase = createClient(supabaseUrl, serviceRoleKey);

// CORS headers
const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type, x-analytics-token",
  "access-control-allow-methods": "POST, OPTIONS",
  "content-type": "application/json",
};

// Helper: Validate authentication token
function validateToken(req: Request): boolean {
  const token = req.headers.get("x-analytics-token");
  return token === expectedToken;
}

// Helper: Get current period in YYYY-MM format (UTC)
function getCurrentPeriod(): string {
  return new Date().toISOString().slice(0, 7);
}

function normalizeRecordedAt(input: unknown): string {
  if (!input) return new Date().toISOString();
  if (typeof input === "number") return new Date(input * 1000).toISOString();
  if (typeof input === "string") {
    const d = new Date(input);
    if (!isNaN(d.getTime())) return d.toISOString();
  }
  return new Date().toISOString();
}

// Route: POST /ingest/usage/book
async function handleUsageBook(body: any) {
  console.log("📊 [book] Request:", { user_key: body.user_key, seconds: body.seconds, plan: body.plan });

  const { user_key, seconds, recorded_at, plan } = body;

  // Validate required fields
  if (!user_key || !seconds) {
    console.error("❌ [book] Missing required fields");
    return {
      status: 400,
      data: { error: "user_key and seconds required" },
    };
  }

  const recordedAtTimestamp = normalizeRecordedAt(recorded_at);

  // 1) Book usage (RPC returns void)
  const { error: bookErr } = await supabase.rpc("book_usage", {
    p_user_key: user_key,
    p_seconds: seconds,
    p_recorded_at: recordedAtTimestamp,
    p_plan: plan || "free",
  });
  if (bookErr) {
    console.error("❌ [book] RPC error:", bookErr);
    return { status: 500, data: { error: "database_error", details: bookErr.message } };
  }

  // 2) Fetch updated usage from fetch_usage RPC
  const { data: after, error: fetchErr } = await supabase.rpc("fetch_usage", {
    p_user_key: user_key,
    p_plan: plan || "free",
  });
  if (fetchErr || !after || after.length === 0) {
    console.error("❌ [book] fetch_usage error:", fetchErr);
    return { status: 500, data: { error: "database_error", details: fetchErr?.message } };
  }

  const row = after[0];
  return {
    status: 200,
    data: {
      ok: true,
      seconds_used: row.seconds_used,
      limit_seconds: row.limit_seconds,
      remaining_seconds: row.remaining_seconds,
    },
  };
}

// Route: POST /ingest/usage/topup
async function handleUsageTopUp(body: any) {
  console.log("📊 [topup] Request:", body);

  const { user_key, seconds, transaction_id, price_paid, currency } = body;

  // Validate required fields
  if (!user_key || !seconds || !transaction_id) {
    console.error("❌ [topup] Missing required fields");
    return {
      status: 400,
      data: { error: "user_key, seconds, and transaction_id required" },
    };
  }

  // Validate seconds amount (should be 10800 for 3-hour top-up)
  if (seconds !== 10800) {
    console.error("❌ [topup] Invalid seconds amount:", seconds);
    return {
      status: 400,
      data: { error: "Invalid seconds amount" },
    };
  }

  try {
    const currentPeriod = getCurrentPeriod();

    // Check for idempotency - has this transaction been processed already?
    const { data: existingPurchase } = await supabase
      .from("topup_purchases")
      .select("transaction_id")
      .eq("transaction_id", transaction_id)
      .maybeSingle();

    if (existingPurchase) {
      console.log("⚠️ [topup] Purchase already credited (idempotent)");

      // Return current balance
      const { data: usage } = await supabase
        .from("user_usage")
        .select("topup_seconds_available")
        .eq("user_key", user_key)
        .eq("period_ym", currentPeriod)
        .maybeSingle();

      return {
        status: 200,
        data: {
          success: true,
          message: "Purchase already credited",
          new_topup_balance: usage?.topup_seconds_available ?? 0,
        },
      };
    }

    // Get or create user_usage record
    const { data: usage } = await supabase
      .from("user_usage")
      .select("*")
      .eq("user_key", user_key)
      .eq("period_ym", currentPeriod)
      .maybeSingle();

    let newTopupBalance = 0;

    if (usage) {
      // Update existing record
      newTopupBalance = (usage.topup_seconds_available || 0) + seconds;
      const { error: updateError } = await supabase
        .from("user_usage")
        .update({
          topup_seconds_available: newTopupBalance,
          updated_at: new Date().toISOString(),
        })
        .eq("user_key", user_key)
        .eq("period_ym", currentPeriod);

      if (updateError) {
        console.error("❌ [topup] Update error:", updateError);
        return {
          status: 500,
          data: { error: "database_error", details: updateError.message },
        };
      }
    } else {
      // Create new record
      newTopupBalance = seconds;
      const { error: insertError } = await supabase
        .from("user_usage")
        .insert({
          user_key,
          period_ym: currentPeriod,
          plan: "free",
          topup_seconds_available: seconds,
          seconds_used: 0,
        });

      if (insertError) {
        console.error("❌ [topup] Insert error:", insertError);
        return {
          status: 500,
          data: { error: "database_error", details: insertError.message },
        };
      }
    }

    // Record the purchase
    const { error: purchaseError } = await supabase
      .from("topup_purchases")
      .insert({
        transaction_id,
        user_key,
        seconds_credited: seconds,
        purchased_at: new Date().toISOString(),
        price_paid: price_paid ?? null,
        currency: currency ?? null,
      });

    // Ignore duplicate key errors (23505) - already handled by idempotency check above
    if (purchaseError && purchaseError.code !== "23505") {
      console.error("❌ [topup] Purchase record error:", purchaseError);
      return {
        status: 500,
        data: { error: "database_error", details: purchaseError.message },
      };
    }

    console.log("✅ [topup] Success - credited", seconds, "seconds, new balance:", newTopupBalance);

    return {
      status: 200,
      data: {
        success: true,
        seconds_credited: seconds,
        new_topup_balance: newTopupBalance,
      },
    };
  } catch (err) {
    console.error("❌ [topup] Unexpected error:", err);
    return {
      status: 500,
      data: { error: "internal_error", details: String(err) },
    };
  }
}

// Route: POST /ingest/usage/fetch
async function handleUsageFetch(body: any) {
  console.log("📊 [fetch] Request:", { user_key: body.user_key, plan: body.plan });

  const { user_key, plan: clientPlan } = body;

  // Validate required fields
  if (!user_key) {
    console.error("❌ [fetch] Missing user_key");
    return {
      status: 400,
      data: { error: "user_key required" },
    };
  }

  try {
    const currentPeriod = getCurrentPeriod();
    console.log("📊 [fetch] Period:", currentPeriod);

    // Query user_usage_with_remaining view
    const { data: usage, error } = await supabase
      .from("user_usage_with_remaining")
      .select("*")
      .eq("user_key", user_key)
      .eq("period_ym", currentPeriod)
      .maybeSingle();

    if (error) {
      console.error("❌ [fetch] Query error:", error);
      return {
        status: 500,
        data: { error: "database_error", details: error.message },
      };
    }

    // No usage record yet - return defaults from plan_limits
    if (!usage) {
      console.log("📊 [fetch] No usage record, fetching plan defaults");
      const effectivePlan = clientPlan || "free";

      const { data: planLimit, error: planError } = await supabase
        .from("plan_limits")
        .select("limit_seconds")
        .eq("plan", effectivePlan)
        .single();

      if (planError || !planLimit) {
        console.warn("⚠️ [fetch] Plan not found, defaulting to free tier");
        return {
          status: 200,
          data: {
            plan: effectivePlan,
            seconds_used: 0,
            limit_seconds: 1800, // Free tier default
            remaining_seconds: 1800,
            topup_seconds_available: 0,
          },
        };
      }

      console.log("✅ [fetch] New user, returning defaults");
      return {
        status: 200,
        data: {
          plan: effectivePlan,
          seconds_used: 0,
          limit_seconds: planLimit.limit_seconds,
          remaining_seconds: planLimit.limit_seconds,
          topup_seconds_available: 0,
        },
      };
    }

    // Return existing usage
    console.log("✅ [fetch] Success:", usage);

    return {
      status: 200,
      data: {
        plan: usage.plan,
        seconds_used: usage.seconds_used,
        limit_seconds: usage.total_limit || usage.limit_seconds, // Use total_limit (includes top-up)
        remaining_seconds: usage.remaining_seconds, // Include remaining (with top-up)
        topup_seconds_available: usage.topup_seconds_available || 0,
      },
    };
  } catch (err) {
    console.error("❌ [fetch] Unexpected error:", err);
    return {
      status: 500,
      data: { error: "internal_error", details: String(err) },
    };
  }
}

// Main handler
Deno.serve(async (req) => {
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("📍 Request:", req.method, req.url);

  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    // Validate token
    if (!validateToken(req)) {
      console.error("❌ Token validation failed");
      return new Response(
        JSON.stringify({ error: "unauthorized" }),
        { status: 401, headers: corsHeaders }
      );
    }

    console.log("✅ Token validated");

    // Parse request body
    const body = await req.json().catch(() => null);
    if (!body) {
      console.error("❌ Invalid JSON body");
      return new Response(
        JSON.stringify({ error: "invalid_json" }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Route to appropriate handler
    const url = new URL(req.url);
    const path = url.pathname;

    if (path.endsWith("/usage/book") || path === "/usage/book") {
      const result = await handleUsageBook(body);
      return new Response(
        JSON.stringify(result.data),
        { status: result.status, headers: corsHeaders }
      );
    }

    if (path.endsWith("/usage/fetch") || path === "/usage/fetch") {
      const result = await handleUsageFetch(body);
      return new Response(
        JSON.stringify(result.data),
        { status: result.status, headers: corsHeaders }
      );
    }

    if (path.endsWith("/usage/topup") || path === "/usage/topup") {
      const result = await handleUsageTopUp(body);
      return new Response(
        JSON.stringify(result.data),
        { status: result.status, headers: corsHeaders }
      );
    }

    // Unknown route
    console.error("❌ Unknown route:", path);
    return new Response(
      JSON.stringify({ error: "not_found", path }),
      { status: 404, headers: corsHeaders }
    );
  } catch (err) {
    console.error("❌ Unhandled error:", err);
    return new Response(
      JSON.stringify({ error: "internal_error", details: String(err) }),
      { status: 500, headers: corsHeaders }
    );
  }
});
