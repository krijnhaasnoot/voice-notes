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

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    // Token check
    const token = req.headers.get("x-analytics-token");
    if (!token || token !== expectedIngestToken) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: corsHeaders,
      });
    }

    // Body lezen
    const body = await req.json().catch(() => null);
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

    // Insert
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
