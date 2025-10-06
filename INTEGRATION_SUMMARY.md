# 3-Hour Pass Integration Summary

## Overview

The 3-hour consumable in-app purchase is now fully integrated with the backend-authoritative quota system.

## Architecture

### Frontend (iOS)
- **Product ID**: `com.kinder.echo.3hours`
- **Credits**: 10,800 seconds (3 hours)
- **Dynamic Configuration**: Price, name, and duration come from App Store Connect

### Backend (Supabase)
- **usage-credit-topup**: Credits purchases idempotently
- **ingest/usage/fetch**: Returns combined quota (subscription + top-ups)
- **ingest/usage/book**: Deducts from top-up first, then subscription

## Purchase Flow

1. **User taps "Buy 3 Hours"** in Settings
2. **StoreKit handles purchase** with Apple Pay
3. **TopUpManager receives transaction**
   - Extracts user_key (from StoreKit originalTransactionID)
   - Extracts transaction_id (for idempotency)
   - Extracts price and currency from transaction
4. **Calls backend**: `POST /usage-credit-topup`
   ```json
   {
     "user_key": "1234567890",
     "seconds": 10800,
     "transaction_id": "txn_abc123",
     "price_paid": 9.99,
     "currency": "EUR"
   }
   ```
5. **Backend credits purchase**
   - Checks idempotency (prevents double-credit)
   - Updates `user_usage.topup_seconds_available`
   - Records in `topup_purchases` table
6. **Frontend refreshes quota**: `POST /ingest/usage/fetch`
   ```json
   {
     "user_key": "1234567890",
     "period_ym": "2025-10"
   }
   ```
7. **UsageViewModel updates**
   - `limitSeconds` = subscription + topup
   - `isOverLimit` = false (if credits added)
   - Record button becomes enabled
8. **Toast shows**: "3 hours added — happy recording!"

## Recording Flow

When user records:

1. **Check quota**: `isOverLimit || isLoading || isStale` → disable button
2. **Record audio**: Timer tracks duration
3. **Book usage**: `POST /ingest/usage/book`
   ```json
   {
     "user_key": "1234567890",
     "seconds": 120,
     "plan": "free"
   }
   ```
4. **Backend deducts**:
   - Try to deduct from `topup_seconds_available` first
   - If insufficient, deduct remainder from subscription quota
   - Update `seconds_used` accordingly
5. **Refresh quota**: Shows updated balance

## Security

- ✅ **x-analytics-token** required for all API calls
- ✅ **Service role key** never exposed to client
- ✅ **Transaction verification** via StoreKit
- ✅ **Idempotency** prevents duplicate credits
- ✅ **Backend authoritative** - client cannot manipulate quota

## Endpoints

### Base URL
```
https://rhfhateyqdiysgooiqtd.functions.supabase.co
```

### POST /usage-credit-topup
Credits a consumable purchase.

**Headers:**
```
Content-Type: application/json
x-analytics-token: <token>
```

**Request:**
```json
{
  "user_key": "string",
  "seconds": 10800,
  "transaction_id": "string",
  "price_paid": 9.99,      // optional
  "currency": "EUR"         // optional
}
```

**Response (200):**
```json
{
  "success": true,
  "seconds_credited": 10800,
  "new_topup_balance": 10800
}
```

**Response (200, already credited):**
```json
{
  "success": true,
  "message": "Purchase already credited",
  "new_topup_balance": 10800
}
```

### POST /ingest/usage/fetch
Fetches current usage and quota for a user.

**Headers:**
```
Content-Type: application/json
x-analytics-token: <token>
```

**Request:**
```json
{
  "user_key": "string",
  "period_ym": "2025-10"
}
```

**Response (200):**
```json
{
  "user_key": "string",
  "period_ym": "2025-10",
  "seconds_used": 600,
  "subscription_seconds_limit": 1800,
  "topup_seconds_available": 10800,
  "plan": "free"
}
```

### POST /ingest/usage/book
Books recording time, deducting from top-up first.

**Headers:**
```
Content-Type: application/json
x-analytics-token: <token>
```

**Request:**
```json
{
  "user_key": "string",
  "seconds": 120,
  "plan": "free"
}
```

**Response (200):**
```json
{
  "success": true,
  "seconds_used": 600,
  "topup_used": 120
}
```

**Response (403, quota exceeded):**
```json
{
  "error": "quota_exceeded",
  "message": "Insufficient balance"
}
```

## Database Schema

### user_usage
```sql
user_key                   text
period_ym                  text (YYYY-MM)
plan                       text
seconds_used               integer
subscription_seconds_limit integer
topup_seconds_available    integer
created_at                 timestamptz
updated_at                 timestamptz

PRIMARY KEY (user_key, period_ym)
```

### topup_purchases
```sql
transaction_id    varchar(255) PRIMARY KEY
user_key          text
seconds_credited  integer
purchased_at      timestamptz
price_paid        numeric(10,2)
currency          varchar(3)
```

## Key Files

### iOS App
- `TopUpManager.swift` - Handles StoreKit purchases
- `UsageQuotaClient.swift` - API client with x-analytics-token
- `UsageViewModel.swift` - Tracks quota state
- `SettingsView.swift` - Buy button UI

### Backend
- `supabase/functions/usage-credit-topup/index.ts` - Credits purchases
- `supabase/functions/ingest/index.ts` - Usage endpoints

### Configuration
- `ANALYTICS_TOKEN` - Bundle.main (Info.plist or xcconfig)
- Product configuration in App Store Connect

## Testing

See `DEPLOYMENT_CHECKLIST.md` for:
- Backend testing with curl
- iOS sandbox testing
- Verification steps
- Expected results

## Deployment Status

✅ **usage-credit-topup** - Deployed
✅ **ingest** - Deployed
✅ **iOS client** - Updated with correct endpoints and headers

## What's Next

1. Configure product in App Store Connect
2. Test with sandbox user
3. Verify quota updates correctly
4. Monitor logs for errors
5. Go live!

## Troubleshooting

### Purchase succeeds but quota doesn't update
- Check console logs for API errors
- Verify `x-analytics-token` is set correctly
- Check Supabase function logs

### "Unauthorized" errors
- Verify `ANALYTICS_TOKEN` is in Info.plist
- Check token matches backend secret

### Quota shows wrong amount
- Call `/ingest/usage/fetch` to refresh
- Check `period_ym` matches current month
- Verify `topup_seconds_available` in database

## Support

- See `LOCALIZED_PRICING.md` for pricing details
- See `DYNAMIC_PRODUCT_CONFIGURATION.md` for product setup
- See `DEPLOYMENT_CHECKLIST.md` for deployment steps
