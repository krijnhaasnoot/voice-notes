# Task: Replace mock analytics with real Supabase-backed “Global Analytics”

Goal
- Use **real backend data** from Supabase (project ref: `rhfhateyqdiysgooiqtd`) on the "Global Analytics" screen.
- Eliminate all mock/placeholder numbers.
- Keep a safe local fallback if network fails.

Supabase
- REST base: https://rhfhateyqdiysgooiqtd.supabase.co/rest/v1
- Table: `analytics_events`
- Auth:
  - Header: `apikey: {{SUPABASE_ANON_KEY}}`
  - Header: `Authorization: Bearer {{SUPABASE_ANON_KEY}}`
- Ingest (already live): https://rhfhateyqdiysgooiqtd.functions.supabase.co/ingest

What data to show (last 30 days unless noted)
1) Total events (count)
2) Total users (distinct user_id)
3) Events by name (top 5)
4) Platform distribution (ios / watchos / macos / android if present)
5) Avg session length (if `session_duration_sec` exists; else skip gracefully)
6) Daily events time series (last 14 days)
7) Feedback stats (thumbs_up vs thumbs_down) if captured as events (`summary_feedback_submitted` with props)

Implementation (Swift, iOS app)
- Files to touch:
  - `Voice Notes/Services/AggregatedAnalyticsService.swift`
  - `Voice Notes/Views/TelemetryView.swift` (rename “📊 Personal Analytics” back to “🌍 Global Analytics”)
  - New: `Voice Notes/Services/SupabaseAnalyticsClient.swift` (create)

Create `SupabaseAnalyticsClient` (URLSession-based)
- Config:
  - `baseURL = https://rhfhateyqdiysgooiqtd.supabase.co/rest/v1`
  - `anonKey = (read from Info.plist key: SUPABASE_ANON_KEY)`
- Common headers:
  - `apikey: <anonKey>`
  - `Authorization: Bearer <anonKey>`
  - `Accept: application/json`
  - `Prefer: count=exact`
- Helpers:
  - `func count(table:String, filter:String?) async throws -> Int`
    - GET `/{table}?select=*&{filter}`
    - Read `Content-Range` for count (or `Range-Unit`/JSON with `Prefer: count=exact`)
  - `func distinctCount(table:String, column:String, filter:String?) async throws -> Int`
    - GET `/{table}?select={column}&distinct=on&{filter}` and count items (paginate if needed)
  - `func groupByCount(table:String, group:String, filter:String?, limit:Int?) async throws -> [(key:String, count:Int)]`
    - GET using `select=\(group),count:count` with `group` via `&group=\(group)` (or fetch rows then group client-side if PostgREST grouping not enabled)
  - `func dailySeries(table:String, timestampCol:String="created_at", days:Int=14, filter:String?) async throws -> [(date:String, count:Int)]`
    - Either server-side bucketing if enabled, else fetch minimal fields and bucket client-side by day.

Notes
- Filters:
  - last 30d: `created_at=gte.\(ISO8601-30d-ago)`
  - Only valid rows: add filters if needed (e.g. `event_name=not.is.null`)
- Pagination:
  - Use `Range` headers (e.g. `Range: 0-999`) and loop until no more.
  - Keep a max safety cap (e.g. 50k events).
- Timeouts & errors:
  - 8s timeout per call; if any call fails, log and continue with partial data.
- Privacy:
  - Only use anon key; **do not** ship service role to app.
- Keys:
  - Read `SUPABASE_ANON_KEY` from Info.plist (already provided by user).
  - Do not hardcode secrets in git.

Changes in `AggregatedAnalyticsService`
- Replace `mockDataEnabled = false` path with real **backend** fetch:
  - `fetchFromBackend()` → use `SupabaseAnalyticsClient` to fill `aggregatedMetrics`.
  - Fill fields:
    - `totalUsers`: distinct `user_id`
    - `totalRecordings`: number of `event_name='recording_completed'` (if used), else total events
    - `totalDurationHours`: sum of `duration_sec`/3600 if present; otherwise omit or estimate from events
    - `topSummaryModes`: if events contain `summary_mode` in properties → group & count
    - `recordingLengthDistribution`: if you store `duration_sec`, bucket by (<5m, 5–15m, 15–30m, >30m)
    - `platformDistribution`: group by `platform`
    - `summaryFeedbackRate`: ratio of feedback events to total summaries (if events present)
  - Keep previous local methods as **fallback** when network fails.

UI (`TelemetryView`)
- Set headers back to:
  - Title: `🌍 Global Analytics`
  - Subtitle: `Aggregated data from all users`
- If `AggregatedAnalyticsService.isLoading == true` show a loading state.
- If backend returns 0 everywhere, show “No data yet” empty state.
- Do **not** show placeholder numbers anymore.

Testing checklist (add a small debug button or use unit tests)
- Call client with:
  - Count (last 30d): `GET /analytics_events?select=*&created_at=gte.<ISO>`
  - Distinct users: `GET /analytics_events?select=user_id&distinct=on&created_at=gte.<ISO>`
  - Group by event_name: (if server-group not available) fetch rows with `select=event_name,created_at` and group in Swift.
- Verify headers include anon key and that 200 is returned.
- Verify pagination logic when >1k rows.

Non-goals (for now)
- No admin dashboard screens in iOS.
- No write endpoints here (ingest already exists in the app).

Edge cases
- If Supabase not reachable → show soft error + fallback to local stats (with clear “Local only” badge).
- If schema doesn’t have some columns (e.g. `duration_sec`) → omit those metrics gracefully.

Deliverables
- New file: `SupabaseAnalyticsClient.swift`
- Updated: `AggregatedAnalyticsService.swift` wired to client
- Updated: `TelemetryView.swift` (“Global Analytics” labels + loading/empty states)
- Light tests or a quick debug button to trigger a refresh

Values to use
- PROJECT_REF: `rhfhateyqdiysgooiqtd`
- ANON KEY: provided via Info.plist as `SUPABASE_ANON_KEY`
- REST base: `https://rhfhateyqdiysgooiqtd.supabase.co/rest/v1`
- Ingest URL: `https://rhfhateyqdiysgooiqtd.functions.supabase.co/ingest`

Please implement now and keep changes minimal & production-safe (timeouts, pagination, fallback).
