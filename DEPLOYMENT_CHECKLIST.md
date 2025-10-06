# 3-Hour Top-Up Deployment Checklist

## Pre-Deployment

### 1. Environment Variables
Ensure these secrets are set in Supabase:

```bash
# Check if secrets are configured
supabase secrets list

# Set if missing (get actual token from your env)
supabase secrets set SERVICE_ROLE_KEY=your_service_role_key
supabase secrets set ANALYTICS_INGEST_TOKEN=your_analytics_token
```

### 2. Database Schema
Verify tables exist with correct schema:

```sql
-- Check user_usage table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'user_usage';

-- Check topup_purchases table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'topup_purchases';
```

Expected columns in `user_usage`:
- user_key (text)
- period_ym (text)
- plan (text)
- seconds_used (integer)
- subscription_seconds_limit (integer)
- topup_seconds_available (integer)
- created_at (timestamptz)
- updated_at (timestamptz)

Expected columns in `topup_purchases`:
- transaction_id (varchar, PRIMARY KEY)
- user_key (text)
- seconds_credited (integer)
- purchased_at (timestamptz)
- price_paid (numeric)
- currency (varchar)

## Deployment Steps

### Step 1: Deploy Functions

```bash
cd "/Users/krijnhaasnoot/Documents/Voice Notes"

# Deploy updated ingest function (with /usage/check, /usage/book, /usage/fetch)
supabase functions deploy ingest

# Deploy usage-credit-topup function
supabase functions deploy usage-credit-topup
```

### Step 2: Test Backend

```bash
# Edit test script to add your actual ANALYTICS_TOKEN
nano test-backend-topup.sh

# Run tests
./test-backend-topup.sh
```

**Expected Test Results:**
- ✅ Test 1: New user returns default free tier (1800 seconds)
- ✅ Test 2: Credit succeeds, returns new_topup_balance=10800
- ✅ Test 3: limitSeconds increases to 12600 (1800 + 10800)
- ✅ Test 4: Recording deducts from top-up, topup_used=600
- ✅ Test 5: limitSeconds shows 12000 (1800 + 10200)
- ✅ Test 6: Idempotency works, same transaction returns "already credited"
- ✅ Test 7: Fetch shows correct topup_seconds_available

### Step 3: Configure App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app
3. Go to **In-App Purchases**
4. Create new consumable:
   - **Product ID**: `com.kinder.echo.3hours`
   - **Reference Name**: `3 Hours Recording Time`
   - **Price**: Tier 10 (€9.99 / $9.99)
   - **Display Name (all localizations)**: `3 Hours Recording Time`
   - **Description (all localizations)**: `Add 3 hours of recording time to your account`

   ⚠️ **Important**: The description MUST contain "3 hours" for duration extraction to work!

5. Submit for review (if required)
6. Enable for testing in Sandbox

### Step 4: Test iOS App (Sandbox)

1. Sign out of App Store on device
2. Build and run app on device (not simulator for IAP testing)
3. Go to Settings → Usage section
4. Tap "Buy 3 Hours" button
5. Sign in with Sandbox Test User when prompted
6. Complete purchase

**Expected Behavior:**
- ✅ Purchase dialog shows correct localized price (e.g., "$9.99" in US, "€9,99" in EU)
- ✅ After purchase: Toast shows "3 hours added — happy recording!"
- ✅ Usage display updates: "12 hours 30 minutes remaining" (if starting from 30 min free)
- ✅ Record button becomes enabled (no longer greyed out)
- ✅ Start recording to verify deduction works correctly

### Step 5: Verify Backend Data

Check that purchase was recorded:

```bash
# Using psql or Supabase SQL Editor
SELECT * FROM topup_purchases
WHERE user_key = 'YOUR_TEST_USER_KEY'
ORDER BY purchased_at DESC
LIMIT 5;

SELECT * FROM user_usage
WHERE user_key = 'YOUR_TEST_USER_KEY'
ORDER BY period_ym DESC
LIMIT 1;
```

**Expected Data:**
- topup_purchases: Has row with transaction_id, 10800 seconds, price/currency
- user_usage: topup_seconds_available shows credited amount (minus any used)

## Post-Deployment Verification

### Functional Tests

- [ ] Purchase completes successfully in sandbox
- [ ] Toast notification shows correct duration
- [ ] Usage display updates immediately
- [ ] Record button becomes enabled after purchase
- [ ] Recording deducts from top-up balance first
- [ ] Idempotency: Duplicate transaction doesn't double-credit
- [ ] Localized pricing shows correct currency

### Edge Cases

- [ ] Purchase with 0 free minutes remaining works
- [ ] Purchase while recording in progress (should queue)
- [ ] Network failure during crediting (transaction listener handles)
- [ ] App restart after purchase (usage persists)
- [ ] Multiple purchases stack correctly
- [ ] Top-up depletes before subscription quota

### Analytics

Monitor these metrics:
- Purchase conversion rate
- Average revenue per user
- Top-up exhaustion rate
- Regional pricing effectiveness

## Rollback Plan

If issues occur:

1. **Disable IAP in App Store Connect** (stops new purchases)
2. **Rollback functions**:
   ```bash
   # Check previous versions
   supabase functions list

   # Deploy previous version if needed
   git checkout <previous-commit>
   supabase functions deploy ingest
   supabase functions deploy usage-credit-topup
   ```

3. **Manual credit fixes** (if users affected):
   ```sql
   -- Manually credit user
   UPDATE user_usage
   SET topup_seconds_available = topup_seconds_available + 10800
   WHERE user_key = 'affected_user_key'
   AND period_ym = '2025-10';

   -- Record manual credit
   INSERT INTO topup_purchases (transaction_id, user_key, seconds_credited, purchased_at)
   VALUES ('manual_credit_123', 'affected_user_key', 10800, NOW());
   ```

## Production Release

After sandbox testing passes:

1. Submit app update to App Review (if needed for UI changes)
2. Enable IAP for production users
3. Monitor error logs:
   ```bash
   supabase functions logs usage-credit-topup
   supabase functions logs ingest
   ```
4. Watch for common errors:
   - "quota_exceeded" (expected when users run out)
   - "unauthorized" (token issues)
   - "db_insert_failed" (schema issues)

## Success Criteria

✅ All tests pass
✅ No errors in function logs
✅ Users can purchase and see updated balance
✅ Recording deducts correctly from top-up
✅ Toast notifications work
✅ Localized pricing displays correctly
✅ Idempotency prevents duplicate credits
✅ Backend data matches expected values

## Support Resources

- [StoreKit Testing Guide](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox)
- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- Local docs:
  - `LOCALIZED_PRICING.md` - How localized pricing works
  - `DYNAMIC_PRODUCT_CONFIGURATION.md` - Changing price/duration
  - `test-backend-topup.sh` - Backend test script
