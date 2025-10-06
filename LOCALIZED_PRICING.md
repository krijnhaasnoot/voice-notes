# Localized Pricing Implementation

## Overview

The 3-hour top-up purchase automatically shows the correct price in each user's local currency, powered by StoreKit's built-in localization.

## How It Works

### 1. **App Store Connect Configuration**

When you set up the product in App Store Connect:
- Select **Price Tier 10** (base: $9.99 USD / €9.99 EUR)
- Apple automatically converts to all regions
- No manual price entry needed for each country

### 2. **StoreKit Fetches Localized Price**

```swift
// In TopUpManager.swift
@Published var threeHoursProduct: Product?

// Load product from StoreKit
let products = try await Product.products(for: ["com.kinder.echo.3hours"])
threeHoursProduct = products.first

// Get localized price string
let localizedPrice = threeHoursProduct?.displayPrice
// Returns: "$9.99" (US), "€9,99" (EU), "£9.99" (UK), etc.
```

### 3. **UI Displays Local Price**

```swift
// In SettingsView.swift
Text(TopUpManager.shared.displayPrice)
    .font(.poppins.body)
    .fontWeight(.bold)

// User sees their local price:
// 🇺🇸 "$9.99"
// 🇪🇺 "€9,99"
// 🇬🇧 "£9.99"
// 🇯🇵 "¥1,200"
```

### 4. **Backend Stores Actual Price Paid**

When the purchase completes:

```swift
// Transaction contains actual price and currency
let pricePaid = transaction.price  // e.g., 9.99
let currency = transaction.currency // e.g., "USD"

// Sent to backend for analytics
try await UsageQuotaClient.shared.creditTopUp(
    userKey: userKey,
    seconds: 10800,
    transactionID: transactionID,
    pricePaid: pricePaid,    // 9.99
    currency: currency       // "USD"
)
```

## Regional Pricing Examples

Based on **Tier 10** pricing (Apple's standard conversion):

| Region | Currency | Price | Notes |
|--------|----------|-------|-------|
| 🇺🇸 United States | USD | $9.99 | Base price |
| 🇪🇺 Eurozone | EUR | €9,99 | Includes VAT |
| 🇬🇧 United Kingdom | GBP | £9.99 | Includes VAT |
| 🇨🇦 Canada | CAD | CA$12.99 | |
| 🇦🇺 Australia | AUD | A$14.99 | Includes GST |
| 🇯🇵 Japan | JPY | ¥1,200 | |
| 🇨🇭 Switzerland | CHF | CHF 10.00 | |
| 🇸🇪 Sweden | SEK | 109 kr | Includes VAT |
| 🇳🇴 Norway | NOK | 109 kr | Includes VAT |
| 🇩🇰 Denmark | DKK | 79 kr | Includes VAT |
| 🇵🇱 Poland | PLN | 39,99 zł | Includes VAT |
| 🇲🇽 Mexico | MXN | $199 | |
| 🇧🇷 Brazil | BRL | R$ 54,90 | |
| 🇮🇳 India | INR | ₹799 | |
| 🇨🇳 China | CNY | ¥68 | |
| 🇰🇷 South Korea | KRW | ₩13,000 | |
| 🇸🇬 Singapore | SGD | S$13.98 | |
| 🇭🇰 Hong Kong | HKD | HK$78 | |
| 🇹🇼 Taiwan | TWD | NT$300 | |
| 🇹🇭 Thailand | THB | ฿349 | |
| 🇮🇩 Indonesia | IDR | Rp 149,000 | |
| 🇵🇭 Philippines | PHP | ₱549 | |
| 🇻🇳 Vietnam | VND | 239,000₫ | |
| 🇲🇾 Malaysia | MYR | RM 44.90 | |
| 🇿🇦 South Africa | ZAR | R 179 | |
| 🇦🇪 UAE | AED | 36.99 د.إ | |
| 🇸🇦 Saudi Arabia | SAR | 37.99 ر.س | |
| 🇷🇺 Russia | RUB | 799 ₽ | |
| 🇹🇷 Turkey | TRY | ₺89,99 | |
| 🇦🇷 Argentina | ARS | $4.500 | |
| 🇨🇱 Chile | CLP | $8.900 | |
| 🇨🇴 Colombia | COP | $39.900 | |

*Prices are approximate and may vary based on Apple's current conversion rates and local tax requirements.*

## Benefits of This Approach

### For Users
✅ **Familiar Pricing**: See prices in their own currency
✅ **No Conversion Confusion**: No need to calculate exchange rates
✅ **Localized Formatting**: Proper currency symbols and decimal separators
✅ **Fair Pricing**: Apple adjusts for purchasing power parity

### For Developers
✅ **Automatic**: No manual price entry for 175+ countries
✅ **Revenue Tracking**: Know exact amount earned per region
✅ **Tax Compliance**: Apple handles VAT/GST automatically
✅ **Dynamic Updates**: Apple adjusts prices as exchange rates change

### For Analytics
✅ **Revenue by Currency**: Track which regions generate most revenue
✅ **Conversion Rates**: See purchase rates by country
✅ **Pricing Optimization**: Identify if pricing works in each region

## Backend Revenue Tracking

With price and currency stored, you can analyze:

```sql
-- Total revenue by currency
SELECT
  currency,
  SUM(price_paid) as total_revenue,
  COUNT(*) as purchase_count,
  AVG(price_paid) as avg_price
FROM topup_purchases
GROUP BY currency
ORDER BY total_revenue DESC;

-- Top purchasing countries
SELECT
  currency,
  COUNT(*) as purchases,
  SUM(price_paid) as revenue
FROM topup_purchases
GROUP BY currency
ORDER BY purchases DESC
LIMIT 10;

-- Revenue over time by region
SELECT
  DATE(purchased_at) as date,
  currency,
  SUM(price_paid) as daily_revenue
FROM topup_purchases
WHERE purchased_at > NOW() - INTERVAL '30 days'
GROUP BY date, currency
ORDER BY date DESC;
```

## Testing Different Regions

### In Simulator
1. **Change Region**: Settings → General → Language & Region
2. **Restart App**: StoreKit loads products for new region
3. **Verify Price**: Should show in local currency

### On Device
- Use sandbox accounts from different regions
- Apple automatically shows region-appropriate pricing
- Test with sandbox account from US, EU, UK, etc.

### Expected Behavior
- Product loads with localized price
- Purchase UI shows local currency
- Receipt includes actual amount paid
- Backend receives correct price + currency

## Important Notes

### Price Updates
- Apple may adjust prices based on exchange rates
- You don't need to update the app
- StoreKit always fetches current pricing

### Tax Inclusion
- Some regions show prices **including** VAT/GST
- Others show prices **before** tax
- Apple handles this automatically
- Your backend receives the actual charged amount

### Currency Conversion
- Don't convert currencies yourself
- Use the actual `price_paid` and `currency` from transaction
- This is what the user actually paid

### Revenue Reporting
- App Store Connect shows revenue in your selected currency
- But individual transactions are in local currency
- Store both for accurate regional analysis

## Troubleshooting

### Price Shows "Loading..."
- Product hasn't loaded yet from StoreKit
- Check network connection
- Verify product ID matches App Store Connect

### Wrong Price Displayed
- Check device region settings
- Verify StoreKit configuration includes product
- Ensure price tier is set in App Store Connect

### Backend Receives Wrong Currency
- Check transaction.currency extraction
- Verify payload includes currency field
- Test with sandbox accounts from different regions

## Summary

The implementation automatically handles localized pricing:
1. ✅ **App Store Connect**: Set one price tier (Tier 10)
2. ✅ **StoreKit**: Fetches localized price string
3. ✅ **UI**: Displays in user's currency
4. ✅ **Transaction**: Contains actual price paid
5. ✅ **Backend**: Stores price + currency for analytics

**No manual work required** - it just works! 🌍💰
