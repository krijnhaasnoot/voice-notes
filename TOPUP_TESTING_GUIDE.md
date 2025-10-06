# 3-Hour Top-Up Testing Guide

## Quick Start Testing

### 1. Local Testing (No Backend Required)

Using the StoreKit configuration file, you can test the entire purchase flow locally:

1. **Run the app in Xcode Simulator or Device**
2. **Navigate to Settings**
3. **Find "Buy 3 Hours" button** (blue/purple gradient)
4. **Tap the button**
5. **Xcode will show StoreKit transaction UI**
6. **Approve the purchase**
7. **Mock backend will need to be set up OR modify code temporarily**

### 2. Sandbox Testing (With Backend)

#### Prerequisites:
- Sandbox Apple ID (create at appstoreconnect.apple.com)
- Backend deployed with new edge function
- Database migration applied

#### Steps:

1. **Sign out of your production Apple ID on test device**
   - Settings → App Store → Sign Out

2. **Run app on physical device (not simulator)**

3. **In app, tap "Buy 3 Hours"**

4. **Sign in with sandbox Apple ID when prompted**

5. **Complete purchase (won't be charged)**

6. **Verify backend received request:**
   ```bash
   # Check Supabase logs
   # Look for: "Credited 10800s to user..."
   ```

7. **Verify balance updated in app**
   - Should show new total immediately
   - Settings should reflect 3 more hours

### 3. Backend Testing

#### Test Backend Locally (Optional)

Using Supabase CLI:

```bash
# Navigate to project
cd /Users/krijnhaasnoot/Documents/Voice\ Notes

# Serve functions locally
supabase functions serve usage-credit-topup

# In another terminal, test the endpoint
curl -X POST http://localhost:54321/functions/v1/usage-credit-topup \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "user_key": "test-user-123",
    "seconds": 10800,
    "transaction_id": "test-txn-001"
  }'

# Expected response:
{
  "success": true,
  "seconds_credited": 10800,
  "new_topup_balance": 10800
}

# Test idempotency (send same request again)
curl -X POST http://localhost:54321/functions/v1/usage-credit-topup \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "user_key": "test-user-123",
    "seconds": 10800,
    "transaction_id": "test-txn-001"
  }'

# Expected response (should still succeed):
{
  "success": true,
  "message": "Purchase already credited",
  "new_topup_balance": 10800
}
```

#### Deploy Backend

```bash
# Deploy the new edge function
supabase functions deploy usage-credit-topup

# Apply database migration
supabase db push
```

### 4. Test Scenarios

#### Scenario 1: First Purchase
- **Start**: User with 30min free tier, 0 used
- **Action**: Purchase 3 hours
- **Expected**: Backend shows 3h 30min total available

#### Scenario 2: Multiple Purchases
- **Start**: User with 30min, already bought 3h once
- **Action**: Purchase 3 hours again
- **Expected**: Backend shows 6h 30min total available

#### Scenario 3: Using Top-Up Balance
- **Start**: User with 30min subscription (all used) + 3h top-up
- **Action**: Record for 10 minutes
- **Expected**:
  - Subscription: 30min used / 30min
  - Top-up: 2h 50min remaining
  - Recording continues normally

#### Scenario 4: Depleted Balance
- **Start**: User with all time used (subscription + top-up)
- **Action**: Try to record
- **Expected**:
  - Record button is disabled
  - UI shows "0:00 remaining"
  - Can still purchase more time

#### Scenario 5: Network Failure
- **Start**: Enable airplane mode
- **Action**: Purchase 3 hours
- **Expected**:
  - StoreKit completes transaction
  - Backend call fails
  - Transaction listener will retry when online
  - Balance eventually updates

#### Scenario 6: Duplicate Transaction
- **Start**: Purchase completed, backend credited
- **Action**: Backend receives same transaction_id again
- **Expected**: Backend returns success, no duplicate credit

### 5. Database Verification

Query the database to verify purchases:

```sql
-- Check user's balance
SELECT
  user_key,
  plan,
  subscription_seconds_limit,
  seconds_used_this_month,
  topup_seconds_available,
  (subscription_seconds_limit - seconds_used_this_month) + topup_seconds_available as total_available
FROM user_usage
WHERE user_key = 'your-user-key';

-- Check purchases
SELECT
  transaction_id,
  user_key,
  seconds_credited,
  purchased_at
FROM topup_purchases
ORDER BY purchased_at DESC
LIMIT 10;

-- Check for duplicate transaction IDs (should be 0)
SELECT transaction_id, COUNT(*)
FROM topup_purchases
GROUP BY transaction_id
HAVING COUNT(*) > 1;
```

### 6. UI Testing Checklist

- [ ] Button appears in Settings
- [ ] Price displays correctly (€9.99)
- [ ] Loading spinner shows during purchase
- [ ] Button is disabled during purchase
- [ ] Success toast appears: "3 hours added — happy recording!"
- [ ] Usage balance updates immediately
- [ ] Record button enables if previously disabled
- [ ] Error message shows on failure

### 7. Edge Cases to Test

#### App Reinstall
1. Purchase 3 hours
2. Delete app
3. Reinstall app
4. Verify balance persists (backend-driven)

#### Multiple Devices
1. Purchase on Device A
2. Open app on Device B (same Apple ID)
3. Verify balance syncs

#### Purchase During Recording
1. Start recording
2. Purchase 3 hours mid-recording
3. Verify balance updates
4. Continue recording

#### Rapid Purchases
1. Purchase 3 hours
2. Immediately purchase again
3. Verify both credit properly (no race condition)

### 8. Production Checklist

Before releasing to production:

- [ ] All test scenarios pass
- [ ] Backend logging is in place
- [ ] Analytics events are tracked
- [ ] Error handling is graceful
- [ ] UI is polished
- [ ] App Store Connect product is configured
- [ ] Receipt validation is working
- [ ] Idempotency is confirmed
- [ ] Database indices are created
- [ ] RLS policies are configured (if applicable)

### 9. Monitoring in Production

Track these metrics:

- **Purchase Success Rate**: Successful purchases / total attempts
- **Backend Credit Rate**: Backend credits / StoreKit completions
- **Average Purchases per User**: Total purchases / unique users
- **Revenue**: Purchases × price
- **Usage After Purchase**: Recording duration within 24h of purchase

### 10. Troubleshooting

#### Purchase doesn't credit
- Check Supabase logs for errors
- Verify transaction_id is being sent
- Check network connectivity
- Verify edge function is deployed

#### Duplicate credits
- Check `topup_purchases` table for duplicate transaction_ids
- Verify idempotency logic in edge function

#### Balance doesn't update
- Verify `UsageViewModel.refresh()` is called after purchase
- Check network requests in Xcode console
- Verify backend returns updated balance

#### Recording still disabled
- Check `isOverLimit` calculation
- Verify backend returns combined balance (subscription + top-up)
- Check UI refresh timing

## Support

For issues, check:
1. Xcode console logs
2. Supabase function logs
3. Database query results
4. Network inspector

Good luck testing! 🚀
