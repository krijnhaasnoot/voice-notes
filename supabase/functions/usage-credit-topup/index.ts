// Edge Function: usage-credit-topup
// POST  https://<ref>.functions.supabase.co/usage-credit-topup
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-analytics-token",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST")   return json({ error: "method_not_allowed" }, 405);

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
  const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    return json({ error: "server env missing (SUPABASE_URL or SERVICE_ROLE_KEY)" }, 500);
  }
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { user_key, seconds, transaction_id, price_paid, currency } = await req.json().catch(() => ({}));
  if (!user_key || !seconds || !transaction_id) return json({ error: "Missing required fields" }, 400);
  if (seconds !== 10800) return json({ error: "Invalid seconds amount" }, 400);

  // Get current period (YYYY-MM)
  const currentPeriod = new Date().toISOString().slice(0, 7);

  // Idempotency
  const { data: exists } = await sb.from("topup_purchases")
    .select("transaction_id").eq("transaction_id", transaction_id).maybeSingle();
  if (exists) {
    const { data: usage } = await sb.from("user_usage")
      .select("topup_seconds_available")
      .eq("user_key", user_key)
      .eq("period_ym", currentPeriod)
      .maybeSingle();
    return json({ success: true, message: "Purchase already credited", new_topup_balance: usage?.topup_seconds_available ?? 0 });
  }

  // user_usage ophalen/aanmaken
  const { data: usage } = await sb.from("user_usage")
    .select("*")
    .eq("user_key", user_key)
    .eq("period_ym", currentPeriod)
    .maybeSingle();

  let newTopup = 0;
  if (usage) {
    newTopup = (usage.topup_seconds_available ?? 0) + seconds;
    const { error } = await sb.from("user_usage")
      .update({ topup_seconds_available: newTopup, updated_at: new Date().toISOString() })
      .eq("user_key", user_key)
      .eq("period_ym", currentPeriod);
    if (error) return json({ error: error.message }, 500);
  } else {
    newTopup = seconds;
    const { error } = await sb.from("user_usage").insert({
      user_key,
      period_ym: currentPeriod,
      plan: "free",
      subscription_seconds_limit: 1800,
      topup_seconds_available: seconds,
      seconds_used: 0,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
    if (error) return json({ error: error.message }, 500);
  }

  // aankoop registreren
  const ins = await sb.from("topup_purchases").insert({
    transaction_id, user_key, seconds_credited: seconds,
    purchased_at: new Date().toISOString(),
    price_paid: price_paid ?? null, currency: currency ?? null,
  });
  if (ins.error && ins.error.code !== "23505") return json({ error: ins.error.message }, 500);

  return json({ success: true, seconds_credited: seconds, new_topup_balance: newTopup });
});

function json(obj: unknown, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { "Content-Type": "application/json", ...cors } });
}
