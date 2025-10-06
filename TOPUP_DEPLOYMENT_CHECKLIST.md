# 3-Hour Top-Up Deployment Checklist

Use this checklist to deploy the consumable purchase feature to production.

## Pre-Deployment

### Code Review
- [x] TopUpManager.swift implemented
- [x] UsageQuotaClient.swift updated with creditTopUp()
- [x] SettingsView.swift updated with Buy button
- [x] StoreKit configuration includes consumable
- [x] All code compiles without errors
- [x] Documentation complete

### Testing Preparation
- [ ] Xcode project builds successfully
- [ ] No compiler warnings related to new code
- [ ] StoreKit configuration file loads properly

## Backend Deployment

### Database Migration
```bash
cd /Users/krijnhaasnoot/Documents/Voice\ Notes

# Review the migration
cat supabase/migrations/20250104_add_topup_support.sql

# Apply migration (dry run first if available)
supabase db push

# Verify tables created
supabase db query "SELECT * FROM topup_purchases LIMIT 1"
supabase db query "SELECT topup_seconds_available FROM user_usage LIMIT 1"
```

- [ ] Migration executed successfully
- [ ] `topup_purchases` table exists
- [ ] `topup_seconds_available` column added to `user_usage`
- [ ] Indices created
- [ ] Functions created

### Edge Function Deployment
```bash
# Deploy the function
supabase functions deploy usage-credit-topup

# Test with curl
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/usage-credit-topup \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "user_key": "test-deployment-123",
    "seconds": 10800,
    "transaction_id": "test-txn-deployment"
  }'
```

- [ ] Function deployed successfully
- [ ] Function responds to test request
- [ ] Returns 200 status code
- [ ] Idempotency works (same request returns success)
- [ ] User record created/updated
- [ ] Purchase record created

### Update Check Endpoint (If Needed)

Ensure `/usage/check` returns the combined balance:

```typescript
// In your existing check endpoint
const totalLimit = user.subscription_seconds_limit + user.topup_seconds_available;

return {
  secondsUsed: user.seconds_used_this_month,
  limitSeconds: totalLimit,  // Combined!
  currentPlan: user.plan
}
```

- [ ] Check endpoint returns combined limit
- [ ] Test with user who has top-up balance
- [ ] Mobile app displays correct total

## App Store Connect Configuration

### Create Consumable Product

1. **Go to**: https://appstoreconnect.apple.com
2. **Navigate**: My Apps → Your App → In-App Purchases
3. **Create**: New In-App Purchase
4. **Type**: Consumable
5. **Configure**:
   - Product ID: `com.kinder.echo.3hours`
   - Reference Name: `3 Hours Recording Time`
   - **Price**: Select **Tier 10** (equivalent to $9.99/€9.99)
     - This automatically sets region-specific pricing:
       - 🇺🇸 $9.99 USD
       - 🇪🇺 €9,99 EUR
       - 🇬🇧 £9.99 GBP
       - 🇯🇵 ¥1,200 JPY
       - etc. (all regions automatically priced)
   - Description: "Add 3 hours of recording time to your account"

- [ ] Product created in App Store Connect
- [ ] Product ID matches code: `com.kinder.echo.3hours`
- [ ] Price tier set to **Tier 10** (auto-localizes to all regions)
- [ ] Verified pricing shows correctly in different regions
- [ ] Available in all required territories
- [ ] Screenshots/description added (if required)
- [ ] Product submitted for review (if first time)

**💡 Tip**: StoreKit automatically fetches the localized price. The app will show:
- "$9.99" for US users
- "€9,99" for European users
- "£9.99" for UK users
- etc.

### Sandbox Testing Account

- [ ] Created sandbox Apple ID at appstoreconnect.apple.com
- [ ] Verified sandbox account email
- [ ] Account ready for testing

## iOS App Testing

### Sandbox Testing

1. **Sign out** of production Apple ID on device
2. **Run app** on physical device (required for IAP)
3. **Navigate** to Settings
4. **Tap** "Buy 3 Hours"
5. **Sign in** with sandbox Apple ID when prompted
6. **Complete** purchase (no charge)

- [ ] Purchase flow works end-to-end
- [ ] StoreKit UI appears
- [ ] Purchase completes successfully
- [ ] Backend receives credit request
- [ ] Database shows purchase record
- [ ] Balance updates in app
- [ ] Toast shows success message
- [ ] Recording enables (if was disabled)

### Test Scenarios

- [ ] **First purchase**: User with no top-ups buys 3h
- [ ] **Second purchase**: Same user buys another 3h
- [ ] **With subscription**: Premium user buys 3h
- [ ] **Out of quota**: User with 0 balance buys, then records
- [ ] **Network failure**: Airplane mode during purchase (transaction listener handles)
- [ ] **App restart**: Purchase persists after restart
- [ ] **Idempotency**: Backend handles duplicate transaction_id

### Error Cases

- [ ] **Cancelled purchase**: User cancels, no charge
- [ ] **Failed payment**: Shows error message
- [ ] **Network timeout**: Graceful failure, retry works
- [ ] **Backend error**: User sees error, can retry

## Production Release

### Final Code Check

- [ ] Remove any debug logging
- [ ] Verify production Supabase URLs
- [ ] Check error messages are user-friendly
- [ ] Analytics events are tracked
- [ ] Haptic feedback works

### Build & Submit

- [ ] Archive app in Xcode
- [ ] Upload to App Store Connect
- [ ] Submit for review
- [ ] Mention IAP in review notes

### App Review

- [ ] Provide test account for reviewer
- [ ] Include instructions to test IAP
- [ ] Mention backend integration
- [ ] Wait for approval ☕

## Post-Launch Monitoring

### Day 1

- [ ] Monitor purchase success rate
- [ ] Check Supabase function logs
- [ ] Watch for error reports
- [ ] Verify receipts in App Store Connect

### Week 1

- [ ] Analyze purchase metrics
- [ ] Check for duplicate transaction IDs (should be 0)
- [ ] Review user feedback
- [ ] Monitor revenue

### Metrics to Track

```sql
-- Total purchases
SELECT COUNT(*) FROM topup_purchases;

-- Revenue (if storing price)
SELECT SUM(price_paid) FROM topup_purchases;

-- Purchases per user
SELECT user_key, COUNT(*) as purchase_count
FROM topup_purchases
GROUP BY user_key
ORDER BY purchase_count DESC;

-- Top-up balance distribution
SELECT
  CASE
    WHEN topup_seconds_available = 0 THEN '0h'
    WHEN topup_seconds_available < 3600 THEN '<1h'
    WHEN topup_seconds_available < 10800 THEN '1-3h'
    WHEN topup_seconds_available < 21600 THEN '3-6h'
    ELSE '6h+'
  END as balance_range,
  COUNT(*) as user_count
FROM user_usage
GROUP BY balance_range;
```

- [ ] Dashboard created for monitoring
- [ ] Alerts set up for errors
- [ ] Weekly reports scheduled

## Rollback Plan

If something goes wrong:

### Backend Rollback
```bash
# Revert edge function
supabase functions delete usage-credit-topup

# Revert migration (if needed)
# Create a down migration to remove columns/tables
```

### App Rollback
- Release app update without IAP button
- Or hide button with feature flag

### Data Integrity
- All purchases are recorded in `topup_purchases`
- Can manually credit users if needed
- Transaction IDs prevent duplicates

## Success Criteria

✅ **Technical Success:**
- [ ] 95%+ purchase success rate
- [ ] No duplicate credits
- [ ] Backend response time < 2s
- [ ] Zero critical errors

✅ **Business Success:**
- [ ] X purchases in first week
- [ ] X% conversion rate
- [ ] Positive user feedback
- [ ] Revenue meets projections

✅ **User Success:**
- [ ] Clear purchase flow
- [ ] Balance updates immediately
- [ ] Recording works after purchase
- [ ] Support tickets < Y per week

## Support Documentation

For support team:

**Common Issues:**
1. "Purchase didn't work" → Check backend logs, verify transaction ID
2. "Balance didn't update" → Trigger manual refresh, check backend
3. "Charged but no credit" → Verify transaction ID in database
4. "Want refund" → Process through App Store Connect

**How to Credit Manually:**
```sql
-- If backend failed but purchase went through
INSERT INTO topup_purchases (transaction_id, user_key, seconds_credited, purchased_at)
VALUES ('manual-credit-xxx', 'user-key', 10800, NOW());

UPDATE user_usage
SET topup_seconds_available = topup_seconds_available + 10800
WHERE user_key = 'user-key';
```

## Done! 🎉

Once all checkboxes are complete, the feature is live and users can purchase 3-hour top-ups!

---

**Questions?** Check:
- CONSUMABLE_PURCHASE_IMPLEMENTATION.md (technical details)
- TOPUP_TESTING_GUIDE.md (testing procedures)
- TOPUP_IMPLEMENTATION_SUMMARY.md (overview)
