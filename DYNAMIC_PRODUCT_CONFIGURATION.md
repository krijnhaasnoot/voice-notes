# Dynamic Product Configuration

## Overview

The app **automatically adapts** to changes you make in App Store Connect. No app updates needed when you change:
- ✅ Price (automatically localized per region)
- ✅ Display name
- ✅ Description
- ✅ Duration (extracted from description)

## How It Works

### 1. Product Information is Fetched from StoreKit

```swift
// In TopUpManager.swift
@Published var threeHoursProduct: Product?

// Load product from App Store Connect via StoreKit
let products = try await Product.products(for: ["com.kinder.echo.3hours"])
threeHoursProduct = products.first

// All product metadata comes from App Store Connect:
let price = product.displayPrice      // "$9.99", "€9,99", etc.
let name = product.displayName        // "3 Hours Recording Time"
let description = product.description // "Add 3 hours of recording time"
```

### 2. Duration is Extracted from Description

The app intelligently parses the product description to determine how many seconds to credit:

```swift
var secondsGranted: Int {
    // Extracts duration from description using regex
    // Supports: "X hours" or "X minutes"
    if let duration = extractDuration(from: product.description) {
        return duration
    }
    return 10800 // Default: 3 hours
}
```

**Examples:**
- Description: "Add **3 hours** of recording time" → 10,800 seconds
- Description: "Add **5 hours** of recording time" → 18,000 seconds
- Description: "Add **90 minutes** of recording time" → 5,400 seconds
- Description: "Add **1 hour** of recording time" → 3,600 seconds

### 3. UI Displays Dynamic Content

```swift
// SettingsView automatically uses dynamic properties
Text(TopUpManager.shared.displayName)        // From App Store Connect
Text(TopUpManager.shared.displayDescription) // From App Store Connect
Text(TopUpManager.shared.displayPrice)       // Localized for user's region
```

### 4. Backend Receives Actual Values

```swift
// When user purchases, backend receives:
{
  "seconds": 10800,          // Extracted from description
  "price_paid": 9.99,        // Actual amount paid
  "currency": "USD",         // User's currency
  "transaction_id": "..."    // Unique ID
}
```

## What You Can Change Without App Updates

### ✅ **Change Price**

**In App Store Connect:**
1. Go to your product
2. Change price tier (e.g., Tier 10 → Tier 8)
3. Save

**Result:**
- App automatically shows new price
- All regions update automatically
- Users see "$7.99" instead of "$9.99"
- Backend receives actual price paid

### ✅ **Change Duration**

**In App Store Connect:**
1. Edit product description
2. Change from "Add **3 hours**..." to "Add **5 hours**..."
3. Save

**Result:**
- App extracts "5 hours" = 18,000 seconds
- Backend credits 18,000 seconds instead of 10,800
- Toast shows "5 hours added — happy recording!"
- No code change needed

### ✅ **Change Display Name**

**In App Store Connect:**
1. Edit display name
2. Change from "3 Hours Recording Time" to "Premium Recording Package"
3. Save

**Result:**
- Button text changes to "Premium Recording Package"
- No app update required

### ✅ **Change Description**

**In App Store Connect:**
1. Edit description
2. Change from "Add recording time" to "Unlock more recording power"
3. Save

**Result:**
- Subtitle changes in button
- Duration extraction still works if format is maintained

## Creating New Top-Up Products

### Example: Add a 1-Hour Top-Up

**Step 1: Create in App Store Connect**
- Product ID: `com.kinder.echo.1hour`
- Display Name: `1 Hour Recording Time`
- Description: `Add 1 hour of recording time to your account`
- Price: Tier 5 ($4.99)

**Step 2: Add to TopUpManager (one-time code change)**

```swift
// Add new product ID
static let oneHourProductID = "com.kinder.echo.1hour"
@Published var oneHourProduct: Product?

// Load both products
func loadProducts() async {
    let products = try await Product.products(for: [
        Self.threeHoursProductID,
        Self.oneHourProductID
    ])
    threeHoursProduct = products.first { $0.id == Self.threeHoursProductID }
    oneHourProduct = products.first { $0.id == Self.oneHourProductID }
}
```

**Step 3: Add button to UI**

```swift
// In SettingsView
Button {
    try await TopUpManager.shared.purchaseOneHour()
    let duration = formatDuration(TopUpManager.shared.oneHourSecondsGranted)
    showToast(message: "\(duration) added — happy recording!")
} label: {
    Text(TopUpManager.shared.oneHourDisplayName)
    Text(TopUpManager.shared.oneHourDisplayPrice)
}
```

**That's it!** From then on, all price/duration changes happen in App Store Connect.

## Best Practices

### Format Product Descriptions Consistently

**Good formats** (will be parsed correctly):
- ✅ "Add **3 hours** of recording time to your account"
- ✅ "Get **5 hours** of extra recording"
- ✅ "**90 minutes** of recording time"
- ✅ "Unlock **1 hour** of recording"

**Bad formats** (won't parse, will use default):
- ❌ "Add three hours of recording" (no number)
- ❌ "Recording time package" (no duration mentioned)
- ❌ "3h of recording" (abbreviation not supported)

**Tip:** Always include the duration as "X hours" or "X minutes" in the description.

### Price Tiers

Use standard Apple price tiers for consistency:
- Tier 5: $4.99 / €4.99 (1 hour)
- Tier 10: $9.99 / €9.99 (3 hours)
- Tier 15: $14.99 / €14.99 (5 hours)
- Tier 20: $19.99 / €19.99 (10 hours)

### Localization

Product names and descriptions can be localized in App Store Connect:
- English: "3 Hours Recording Time"
- Dutch: "3 Uur Opnametijd"
- French: "3 Heures d'Enregistrement"
- German: "3 Stunden Aufnahmezeit"

The app will show the localized version automatically!

## Testing Dynamic Updates

### Test Changing Price

1. **Current state**: Product shows $9.99
2. **In App Store Connect**: Change to Tier 8 ($7.99)
3. **In app**: Kill and relaunch app
4. **Result**: Button shows $7.99

### Test Changing Duration

1. **Current state**: Description says "Add 3 hours..."
2. **In App Store Connect**: Change to "Add 5 hours..."
3. **In app**: Kill and relaunch app
4. **Purchase**: Backend receives 18,000 seconds (5 hours)
5. **Toast**: Shows "5 hours added — happy recording!"

### Test Changing Name

1. **Current state**: Button says "3 Hours Recording Time"
2. **In App Store Connect**: Change display name to "Premium Package"
3. **In app**: Kill and relaunch app
4. **Result**: Button text changes to "Premium Package"

## Edge Cases

### What if Description Doesn't Contain Duration?

The app falls back to default:
```swift
return 10800 // 3 hours default
```

**Recommendation**: Always include duration in description for clarity.

### What if StoreKit is Unavailable?

Shows placeholder text:
```swift
displayPrice: "Loading..."
displayName: "Add Recording Time"
displayDescription: "Add recording time to your account"
```

Once StoreKit loads, updates automatically.

### What if User Has Outdated App Version?

Only an issue if you:
- Change product ID (e.g., `3hours` → `5hours`)
- Remove the product entirely

**Solution**: Keep product ID constant, only change metadata.

## Benefits

### For You (Developer)

✅ **Change pricing** without submitting app updates
✅ **Test different price points** in real-time
✅ **Run promotions** by temporarily reducing price
✅ **Add new durations** (1h, 5h, 10h) with single code change
✅ **Localize content** in App Store Connect

### For Users

✅ **Always see current pricing** (no stale prices in app)
✅ **See prices in their currency** automatically
✅ **Get accurate descriptions** that match what they're buying

### For Business

✅ **A/B test pricing** without releases
✅ **Regional pricing** handled automatically
✅ **Seasonal promotions** easy to manage
✅ **Analytics** track actual prices paid per region

## Migration Path

If you want to change from 3-hour to 5-hour product:

### Option 1: Update Existing Product (Recommended)
1. Keep product ID: `com.kinder.echo.3hours`
2. Change display name: "5 Hours Recording Time"
3. Change description: "Add **5 hours** of recording time"
4. Change price if desired

**Result**: No app update needed!

### Option 2: Create New Product
1. Create: `com.kinder.echo.5hours`
2. Add to `loadProducts()` in TopUpManager
3. Add button in UI
4. Keep 3-hour option or remove it

**Result**: Requires one app update for code change.

## Summary

The implementation is **fully dynamic** and powered by App Store Connect:

| What | Source | Can Change Without Update? |
|------|--------|---------------------------|
| Price | StoreKit | ✅ Yes |
| Currency | StoreKit | ✅ Yes (automatic) |
| Display Name | StoreKit | ✅ Yes |
| Description | StoreKit | ✅ Yes |
| Duration | Parsed from description | ✅ Yes (if format maintained) |
| Product ID | Hardcoded | ❌ No (requires update) |

**Bottom line:** You control almost everything from App Store Connect, no code deployments needed! 🎉
