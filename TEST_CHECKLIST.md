# Supabase Analytics Test Checklist

## Quick Start
```bash
# 1. Add the Supabase key
./add_supabase_key.sh

# 2. Build the project
xcodebuild -scheme "Voice Notes" -destination "platform=iOS Simulator,name=iPhone 15" build

# 3. Run the app and navigate to Usage Analytics
```

## Manual Testing

### ✅ Test 1: Basic Connectivity
1. Launch app
2. Navigate to **Usage Analytics**
3. **Expected**: Loading indicator appears briefly
4. **Expected**: Header shows "🌍 Global Analytics" or "📊 Personal Analytics (offline)"

### ✅ Test 2: Data Display
1. Check the metrics cards
2. **Expected**: Real numbers (NOT the old placeholder "2847")
3. **Expected**: Platform distribution shows real platforms (ios, android, etc.)
4. **Expected**: If backend works, should see "Aggregated data from all users"

### ✅ Test 3: Refresh
1. Pull down to refresh
2. **Expected**: Loading indicator appears
3. **Expected**: Data updates
4. **Expected**: Console logs show either "✅ Successfully fetched" or "❌ Backend analytics failed"

### ✅ Test 4: Network Failure (Fallback)
1. Enable Airplane Mode on device/simulator
2. Kill and relaunch app
3. Navigate to Usage Analytics
4. **Expected**: Shows "📊 Personal Analytics"
5. **Expected**: Subtitle shows "Local data only (offline)" in orange
6. **Expected**: Console shows "❌ Backend analytics failed"
7. **Expected**: Console shows "ℹ️ Using local fallback analytics"

### ✅ Test 5: Network Recovery
1. Disable Airplane Mode
2. Pull to refresh in Usage Analytics
3. **Expected**: Switches back to "🌍 Global Analytics"
4. **Expected**: Shows real backend data

### ✅ Test 6: Empty Data Handling
1. Check that N/A appears for missing fields (duration, sessions)
2. **Expected**: App doesn't crash on missing data
3. **Expected**: Optional fields show "N/A" gracefully

## Automated Smoke Test

### Option A: Code-based test
Add this to your app (DEBUG builds only):
```swift
import SwiftUI

struct DebugView: View {
    var body: some View {
        Button("Run Analytics Test") {
            Task {
                await SupabaseAnalyticsSmokeTest.runSmokeTest()
            }
        }
        .padding()
    }
}
```

### Option B: Navigation-based test
Add to your settings:
```swift
NavigationLink("Analytics Debug") {
    SupabaseAnalyticsDebugView()
}
```

### Expected Output
```
🧪 ===== SUPABASE ANALYTICS SMOKE TEST =====
Testing connection to: https://rhfhateyqdiysgooiqtd.supabase.co

1️⃣  Testing totalEvents(since: 30 days ago)...
   ✅ SUCCESS: [number] total events

2️⃣  Testing distinctUsers(since: 30 days ago)...
   ✅ SUCCESS: [number] distinct users

3️⃣  Testing topEvents(since: 30 days ago, limit: 5)...
   ✅ SUCCESS: [number] events
      1. event_name_1: [count]
      2. event_name_2: [count]
      ...

4️⃣  Testing platformDistribution(since: 30 days ago)...
   ✅ SUCCESS: [number] platforms
      - ios: [count]
      - android: [count]
      ...

5️⃣  Testing dailySeries(since: 14 days)...
   ✅ SUCCESS: [number] data points
      - Oct 01: [count]
      - Oct 02: [count]
      ...

6️⃣  Testing feedbackSplit(since: 30 days ago)...
   ✅ SUCCESS: 👍 [count] / 👎 [count]

7️⃣  Testing AggregatedAnalyticsService integration...
   ✅ SUCCESS: Service fetched metrics
      - Total Users: [number]
      - Total Events: [number]
      - Platforms: [distribution]
      - Using Fallback: false

✅ ===== SMOKE TEST COMPLETE =====
```

## API Verification (Manual)

Test the raw API endpoints using curl:

### Test 1: Basic Query
```bash
curl -X GET \
  'https://rhfhateyqdiysgooiqtd.supabase.co/rest/v1/analytics_events?limit=1' \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJoZmhhdGV5cWRpeXNnb29pcXRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3NDkxNjEsImV4cCI6MjA3NDMyNTE2MX0.wQXG_26AYWe-euRqtpCuU1BpJJ1jqQQkAAkZtAXZiL0" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJoZmhhdGV5cWRpeXNnb29pcXRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3NDkxNjEsImV4cCI6MjA3NDMyNTE2MX0.wQXG_26AYWe-euRqtpCuU1BpJJ1jqQQkAAkZtAXZiL0"
```
**Expected**: HTTP 200 with JSON array

### Test 2: Date Filter
```bash
curl -X GET \
  'https://rhfhateyqdiysgooiqtd.supabase.co/rest/v1/analytics_events?select=*&created_at=gte.2025-09-01T00:00:00Z&limit=1' \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJoZmhhdGV5cWRpeXNnb29pcXRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3NDkxNjEsImV4cCI6MjA3NDMyNTE2MX0.wQXG_26AYWe-euRqtpCuU1BpJJ1jqQQkAAkZtAXZiL0" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJoZmhhdGV5cWRpeXNnb29pcXRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3NDkxNjEsImV4cCI6MjA3NDMyNTE2MX0.wQXG_26AYWe-euRqtpCuU1BpJJ1jqQQkAAkZtAXZiL0"
```
**Expected**: HTTP 200 with filtered results

### Test 3: Distinct Query
```bash
curl -X GET \
  'https://rhfhateyqdiysgooiqtd.supabase.co/rest/v1/analytics_events?select=user_id&user_id=not.is.null&limit=10' \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJoZmhhdGV5cWRpeXNnb29pcXRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3NDkxNjEsImV4cCI6MjA3NDMyNTE2MX0.wQXG_26AYWe-euRqtpCuU1BpJJ1jqQQkAAkZtAXZiL0" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJoZmhhdGV5cWRpeXNnb29pcXRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3NDkxNjEsImV4cCI6MjA3NDMyNTE2MX0.wQXG_26AYWe-euRqtpCuU1BpJJ1jqQQkAAkZtAXZiL0"
```
**Expected**: HTTP 200 with user_id array

## Common Issues

### Issue: "Missing anon key"
**Fix**:
```bash
./add_supabase_key.sh
```

### Issue: Always shows "Personal Analytics"
**Debug**:
1. Check Xcode console for errors
2. Look for "❌" prefixed messages
3. Run smoke test to isolate the problem

### Issue: Numbers look wrong
**Debug**:
1. Check date range (30 days by default)
2. Verify time zones match
3. Check Supabase RLS policies

### Issue: App crashes
**Debug**:
1. Check for force-unwrapping optionals
2. Verify AggregatedMetrics optional fields
3. Enable Exception Breakpoint in Xcode

## Performance Validation

### Expected Timing
- First load: ~8-10 seconds (parallel fetch of 6 metrics)
- Refresh: ~8-10 seconds
- Fallback (on error): ~300ms (local data)

### Memory
- Client is lightweight, no heavy caching
- Pagination prevents large memory spikes
- Safety limit at 50k rows

### Network
- 6 parallel requests (one per metric)
- Each request: 1-8 seconds (8s timeout)
- Total data transfer: varies by dataset size

## Sign-off

- [ ] All manual tests pass
- [ ] Smoke test shows all ✅
- [ ] No console errors during normal operation
- [ ] Fallback works when network is down
- [ ] Recovery works when network returns
- [ ] No placeholder numbers visible in UI
- [ ] Header correctly indicates data source
- [ ] Pull-to-refresh works

**Tester**: _______________
**Date**: _______________
**Build**: _______________

---

✅ Ready for production deployment
