# Top-Up Banking Feature

## Overview
Top-up minutes purchased via in-app purchases now **persist across months** and do not reset with the monthly subscription quota.

## How It Works

### Before (Without Banking)
- User has Echo Standard subscription: 120 min/month
- User purchases 3-hour top-up (180 min) in January
- User uses 50 minutes in January
- **February 1st**: Subscription resets to 120 min, **top-up minutes lost** ❌
- User effectively lost 130 unused top-up minutes

### After (With Banking) ✅
- User has Echo Standard subscription: 120 min/month
- User purchases 3-hour top-up (180 min) in January
- User uses 50 minutes in January (30 subscription + 20 top-up)
- **February 1st**:
  - Subscription resets to 120 min
  - Top-up balance carries over: **160 min remaining** ✅
- User has 120 (subscription) + 160 (top-up) = **280 min total in February**

## Technical Implementation

### Backend Changes

**File**: `supabase/functions/ingest/index.ts`

#### 1. Added `getPreviousPeriod()` helper
```typescript
function getPreviousPeriod(currentPeriod: string): string {
  const [year, month] = currentPeriod.split("-").map(Number);
  const date = new Date(year, month - 1, 1);
  date.setMonth(date.getMonth() - 1);
  const prevYear = date.getFullYear();
  const prevMonth = String(date.getMonth() + 1).padStart(2, "0");
  return `${prevYear}-${prevMonth}`;
}
```

#### 2. Updated `handleUsageFetch()`
- When no record exists for current month (new period)
- Queries previous month's `user_usage` record
- Extracts `topup_seconds_available` from previous month
- Creates new month's record with carried-over top-up balance

```typescript
const previousPeriod = getPreviousPeriod(currentPeriod);
const { data: previousUsage } = await supabase
  .from("user_usage")
  .select("topup_seconds_available, plan")
  .eq("user_key", user_key)
  .eq("period_ym", previousPeriod)
  .maybeSingle();

const carriedOverTopup = previousUsage?.topup_seconds_available || 0;
```

#### 3. Updated `handleUsageBook()`
- Same carryover logic when creating a new record mid-month
- Ensures consistent behavior whether user checks usage or records usage first

### Database Schema

**Table**: `user_usage`

| Column | Type | Description |
|--------|------|-------------|
| `user_key` | VARCHAR | User identifier (device ID) |
| `period_ym` | VARCHAR | Period in YYYY-MM format |
| `month_year` | VARCHAR | Legacy column (same as period_ym) |
| `plan` | VARCHAR | Subscription tier (free/standard/premium/own_key) |
| `seconds_used` | INT | Subscription seconds used this month |
| `subscription_seconds_limit` | INT | Monthly subscription quota |
| `topup_seconds_available` | INT | **Persistent top-up balance** ✅ |

**Key**: `topup_seconds_available` is **NOT reset monthly** - it carries forward automatically.

## Deduction Order

Top-ups are consumed **before** subscription minutes:

1. **First**: Deduct from `topup_seconds_available`
2. **Then**: Deduct from remaining subscription quota

This ensures:
- Top-ups are used immediately
- Subscription quota is preserved
- Users get full value from purchases

## Example Scenarios

### Scenario 1: Single Month Usage
**January**:
- Plan: Standard (120 min/month)
- Purchases: 3-hour top-up (180 min)
- Total available: 300 min
- Records 50 min: Deducts from top-up → 130 min top-up left
- Records 100 min: Deducts from top-up → 30 min top-up left

**February 1st**:
- Subscription resets: 120 min
- Top-up carries over: 30 min
- **Total available: 150 min**

### Scenario 2: Multiple Top-Ups
**January**:
- Plan: Standard (120 min)
- Purchases: 3-hour top-up (180 min)
- Uses: 50 min from subscription, 50 min from top-up
- Remaining: 70 min subscription, 130 min top-up

**Mid-January**:
- Purchases: Another 3-hour top-up (180 min)
- Total top-up: 310 min

**February 1st**:
- Subscription resets: 120 min
- Top-up carries over: **310 min** ✅
- **Total available: 430 min**

### Scenario 3: Year Boundary
**December 2024**:
- Plan: Standard (120 min)
- Purchases: 3-hour top-up (180 min)
- Uses: 20 min
- Remaining top-up: 160 min

**January 2025**:
- Subscription resets: 120 min
- Top-up carries over: 160 min ✅
- **Total available: 280 min**

The carryover works across year boundaries seamlessly.

## iOS Client

**No changes required** - the iOS client already handles combined limits correctly.

The backend returns:
```json
{
  "limit_seconds": 7200,  // Combined: subscription + top-up
  "subscription_seconds_limit": 7200,
  "topup_seconds_available": 10800,
  "seconds_used": 0
}
```

iOS displays: `"X/Y min"` where Y = `limit_seconds / 60`

## Benefits

1. **Fair to users**: Purchased minutes never expire
2. **Encourages purchases**: Users know their money won't be wasted
3. **Flexible usage**: Users can "bank" minutes for busier months
4. **Transparent**: Clear distinction between subscription and purchased minutes
5. **Automatic**: No user action required - happens seamlessly

## Testing

### Manual Test: Month Rollover
```bash
# 1. Create user with top-up in "2024-12"
curl -X POST "https://.../usage-credit-topup" \
  -H "x-analytics-token: $TOKEN" \
  -d '{"user_key":"test_user","seconds":10800,"transaction_id":"test_txn_1"}'

# 2. Book some usage in December
curl -X POST "https://.../ingest/usage/book" \
  -H "x-analytics-token: $TOKEN" \
  -d '{"user_key":"test_user","seconds":3600,"plan":"standard"}'

# 3. Manually insert December record with remaining top-up
# (Simulate December state)

# 4. Fetch in January (2025-01) - should carry over top-up
curl -X POST "https://.../ingest/usage/fetch" \
  -H "x-analytics-token: $TOKEN" \
  -d '{"user_key":"test_user","plan":"standard"}'

# Verify response shows:
# - subscription_seconds_limit: 7200 (standard plan)
# - topup_seconds_available: 7200 (carried over from December)
# - seconds_used: 0 (fresh month)
```

## Monitoring

Look for these log entries:
```
📊 New period for {user}, plan: {plan}, limit: {limit}s, carried-over topup: {topup}s
📊 handleUsageBook: Carrying over {topup}s top-up from {previous_period}
```

## Future Enhancements

1. **Top-up expiration**: Add optional expiration (e.g., 12 months) for compliance
2. **Top-up history**: Show users their top-up purchase and consumption history
3. **Rollover notifications**: Notify users when minutes carry over to new month
4. **Analytics**: Track average carried-over balances, purchase patterns

## Deployment

Deployed: 2025-10-06
Function: `ingest`
Endpoints affected:
- `/ingest/usage/fetch`
- `/ingest/usage/book`

Backward compatible: Yes ✅
Database migration required: No (uses existing columns)

---

**Status**: ✅ **Active** - Top-up banking is live in production
