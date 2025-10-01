# Backend Quota Verification Guide

## Summary
To ensure users cannot get free minutes by manipulating local data, the backend (Supabase) is the source of truth for usage tracking.

## Implementation Details

### 1. Dual Tracking System
- **Backend (Supabase)**: Authoritative source via UsageQuotaClient
- **Local (MinutesTracker)**: Immediate UI feedback, synced from backend

### 2. Security Measures Implemented

#### On App Launch/Resume
```swift
// AlternativeHomeView.onAppear
await usageVM.refresh()  // Fetch from backend
syncBackendToLocal()     // Sync local tracker
```

#### Before Starting Recording
```swift
// AlternativeHomeView.startRecording()
await usageVM.refresh()     // Check backend quota
if usageVM.isOverLimit {    // Block if over limit
    return
}
```

#### After Recording Completes
```swift
// AlternativeHomeView.stopRecording()
MinutesTracker.shared.addUsage(seconds: result.duration)  // Local update
await UsageViewModel.shared.book(seconds: ...)             // Backend booking
// UsageViewModel.book() calls refresh() to sync back
```

### 3. Sync Logic
```swift
func syncBackendToLocal() {
    let backendMinutesUsed = Double(usageVM.secondsUsed) / 60.0
    let localMinutesUsed = minutesTracker.minutesUsed

    // If difference > 0.1 min (6 seconds), sync from backend
    if abs(backendMinutesUsed - localMinutesUsed) > 0.1 {
        minutesTracker.syncFromBackend(backendMinutesUsed: backendMinutesUsed)
    }
}
```

## What You Need to Verify on Backend

### 1. User Identification
**Current Implementation:**
```swift
func resolveUserKey() async -> String {
    // 1. Try appAccountToken
    // 2. Try originalTransactionID
    // 3. Fallback: Keychain UUID
}
```

**⚠️ SECURITY CONCERN:**
- Keychain UUID can be reset if user deletes app and reinstalls
- Need to verify StoreKit originalTransactionID is properly captured

**TO VERIFY:**
- [ ] Check if `originalTransactionID` is being saved correctly for subscribed users
- [ ] Test: Subscribe → Use minutes → Delete app → Reinstall → Should restore same usage

### 2. Backend Endpoint Security

**Ingest Endpoint** (`/ingest`)
```typescript
// What to verify:
- Does it validate the user's plan from StoreKit receipt?
- Does it prevent booking more than plan allows?
- Does it validate timestamps to prevent backdating?
- Does it handle duplicate requests (idempotency)?
```

**Usage Endpoint** (`/usage`)
```typescript
// What to verify:
- Does it return accurate usage for current period (YYYY-MM)?
- Does it validate the user owns this subscription?
- Does it rate limit requests?
```

### 3. Critical Backend Validations Needed

#### A. Plan Validation
```typescript
// Backend should validate plan on EVERY request
async function validateUserPlan(userKey: string): Promise<Plan> {
    // Query StoreKit Server API to verify subscription
    // Return actual entitled plan, not what client claims
}
```

#### B. Monthly Reset Logic
```typescript
// Backend should handle monthly resets
function getCurrentPeriod(): string {
    return new Date().toISOString().slice(0, 7) // "YYYY-MM"
}

// Usage should be scoped to period
SELECT seconds_used FROM usage
WHERE user_key = ? AND period = ?
```

#### C. Rate Limiting
```typescript
// Prevent abuse
- Max 1000 requests/hour per user
- Max 10 recordings/minute
- Flag suspicious patterns (e.g., many recordings of exactly plan limit)
```

### 4. Attack Vectors to Test

#### A. Time Travel Attack
**Attack:** User changes device time to future to reset period
**Prevention:** Backend uses server time, not client time
```typescript
// Use server timestamp
const recordedAt = request.body.recordedAt || Date.now()
const serverTime = Date.now()

// Reject if client time is more than 1 hour in future
if (recordedAt > serverTime + 3600000) {
    throw new Error('Invalid timestamp')
}
```

#### B. Replay Attack
**Attack:** User replays old JWT/tokens to spoof identity
**Prevention:** Short-lived tokens, nonce validation
```typescript
// Add nonce to requests
// Store processed nonces in Redis with 5-min TTL
```

#### C. App Deletion Attack
**Attack:** User deletes app to reset local storage
**Prevention:** Backend tracks by originalTransactionID
```typescript
// Always use StoreKit originalTransactionID as primary key
// Keychain UUID is only for free tier users
```

#### D. Plan Downgrade Exploit
**Attack:** User subscribes to Premium, uses minutes, downgrades to Standard
**Prevention:** Track plan changes, prorate usage
```typescript
// When plan changes mid-period
if (planChanged) {
    // Option 1: Keep current period usage, apply new limit next period
    // Option 2: Prorate based on days in each plan
}
```

## Testing Checklist

### Manual Tests
- [ ] Subscribe to Premium → Use 100 minutes → Check backend shows 100
- [ ] Delete app → Reinstall → Check minutes still shows 100
- [ ] Try recording when at limit → Should be blocked
- [ ] Complete recording → Verify usage increments in backend
- [ ] Close app → Reopen → Verify usage syncs from backend

### Automated Tests (Backend)
```typescript
describe('Usage Quota', () => {
    it('should prevent exceeding plan limits', async () => {
        const user = createTestUser('free') // 30 min
        await bookMinutes(user, 29) // OK
        await bookMinutes(user, 2)  // Should reject
    })

    it('should handle monthly resets', async () => {
        const user = createTestUser('standard')
        await bookMinutes(user, 120, '2025-01')
        const jan = await getUsage(user, '2025-01')
        const feb = await getUsage(user, '2025-02')
        expect(jan.seconds_used).toBe(7200)
        expect(feb.seconds_used).toBe(0)
    })
})
```

## Monitoring & Alerts

**Set up alerts for:**
1. Users exceeding plan limits (possible exploit)
2. High request rates (possible abuse)
3. Negative usage values (data corruption)
4. Large time discrepancies (time travel attacks)

**Metrics to track:**
- Average recordings per user per day
- Peak usage times
- Plan distribution
- Usage vs plan limit ratio

## Next Steps

1. **Verify backend implementation** matches these security requirements
2. **Add server-side validation** for all plan checks
3. **Implement idempotency** for booking requests
4. **Add monitoring** for suspicious patterns
5. **Test attack vectors** from the checklist
6. **Document backend API** with security requirements
