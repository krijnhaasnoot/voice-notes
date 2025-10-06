// Supabase Edge Function: usage
// Routes:
//   POST /usage/fetch  -> haal server-autoritatieve quota op (subscription + topup)
//   POST /usage/book   -> boek verbruikte seconden (eerst topup verlagen, rest naar subscription-used)
//
// Tabel: user_usage
//   cols: user_key, month_year(YYYY-MM), seconds_used_this_month, subscription_seconds_limit,
//         topup_seconds_available, plan, updated_at
//
// Auth: verwacht ANALYTICS_TOKEN / ANALYTICS_INGEST_TOKEN (zelfde als ingest)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-analytics-token",
};

type FetchBody = { user_key: string; period_ym: string };
type BookBody  = { user_key: string; seconds: number; recorded_at?: string; period_ym?: string; plan?: string };

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const url = new URL(req.url);
    const path = url.pathname; // /functions/v1/usage/fetch

    // ---- Token check (Bearer of x-analytics-token) ----
    const hdrAuth = req.headers.get("authorization") ?? "";
    const bearer = hdrAuth.toLowerCase().startsWith("bearer ") ? hdrAuth.slice(7) : null;
    const token  = bearer || req.headers.get("x-analytics-token");
    const expected = Deno.env.get("ANALYTICS_TOKEN") ?? Deno.env.get("ANALYTICS_INGEST_TOKEN") ?? "";
    if (!token || token !== expected) return j({ error: "unauthorized" }, 401);

    // ---- Supabase client (service role) ----
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
    if (!SUPABASE_URL || !SERVICE_ROLE_KEY) return j({ error: "server env missing (SUPABASE_URL or SERVICE_ROLE_KEY)" }, 500);
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // Helpers
    const ensureRow = async (user_key: string, period_ym: string) => {
      const { data, error } = await sb.from("user_usage")
        .select("*").eq("user_key", user_key).eq("month_year", period_ym).maybeSingle();
      if (error) throw error;
      if (data) return data;
      const init = {
        user_key,
        month_year: period_ym,
        plan: "free",
        subscription_seconds_limit: 1800,
        topup_seconds_available: 0,
        seconds_used_this_month: 0,
        updated_at: new Date().toISOString(),
      };
      const { error: insErr } = await sb.from("user_usage").insert(init);
      if (insErr) throw insErr;
      return init;
    };

    // ------- /usage/fetch -------
    if (req.method === "POST" && path.endsWith("/usage/fetch")) {
      const body = (await req.json().catch(() => ({}))) as FetchBody;
      const user_key = String(body.user_key || "").trim();
      const period_ym = String(body.period_ym || "").trim();
      if (!user_key || !period_ym) return j({ error: "missing user_key or period_ym" }, 400);

      const usage = await ensureRow(user_key, period_ym);
      const secondsUsed = usage.seconds_used_this_month ?? 0;
      const subLimit    = usage.subscription_seconds_limit ?? 1800;
      const topup       = usage.topup_seconds_available ?? 0;
      const plan        = usage.plan ?? "free";

      return j({
        secondsUsed,
        limitSeconds: subLimit + topup,   // gecombineerd
        currentPlan: plan,
        period: period_ym,
      });
    }

    // ------- /usage/book -------
    if (req.method === "POST" && path.endsWith("/usage/book")) {
      const body = (await req.json().catch(() => ({}))) as BookBody;
      const user_key = String(body.user_key || "").trim();
      const seconds  = Number(body.seconds || 0);
      const period_ym = String(body.period_ym || new Date().toISOString().slice(0, 7));
      if (!user_key || !seconds || seconds < 0) return j({ error: "missing user_key or seconds" }, 400);

      const usage = await ensureRow(user_key, period_ym);

      // verbruik: eerst top-up, rest naar subscription-used
      let topupAvail = usage.topup_seconds_available ?? 0;
      const usedFromTopup = Math.min(topupAvail, seconds);
      topupAvail -= usedFromTopup;

      const newUsed = (usage.seconds_used_this_month ?? 0) + seconds;

      const { error: updErr } = await sb.from("user_usage").update({
        topup_seconds_available: topupAvail,
        seconds_used_this_month: newUsed,
        updated_at: new Date().toISOString(),
      }).eq("user_key", user_key).eq("month_year", period_ym);
      if (updErr) throw updErr;

      const subLimit = usage.subscription_seconds_limit ?? 1800;
      return j({
        ok: true,
        period: period_ym,
        booked: seconds,
        usedFromTopup,
        secondsUsed: newUsed,
        limitSeconds: subLimit + topupAvail,
      });
    }

    return j({ error: "not_found" }, 404);
  } catch (e: any) {
    console.error(e);
    return j({ error: String(e?.message ?? e) }, 500);
  }
});

function j(obj: unknown, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { "Content-Type": "application/json", ...cors } });
}
