# Selective Cooldown Bypass Implementation

## Overview

Modified the 12-hour API cooldown to be **smart about context**:
- ✅ **Portfolio refreshes**: Respect 12-hour cooldown (conserve API tokens)
- ✅ **Adding new assets**: Bypass cooldown (users expect immediate prices)

## Problem Solved

**Before:**
- User adds new asset → Cooldown blocks price fetch → Shows fallback/stale price
- User frustration: "Why can't I see the current price for my new stock?"

**After:**
- User adds new asset → Bypasses cooldown → Gets fresh price immediately
- Portfolio refresh → Respects cooldown → Conserves API quota

## Implementation Details

### 1. MarketstackService.swift

**Added `bypassCooldown` parameter to methods:**

```swift
func fetchQuote(ticker: String, bypassCooldown: Bool = false) async throws -> YFStockQuote
func fetchCryptoQuote(symbol: String, bypassCooldown: Bool = false) async throws -> YFCryptoQuote
```

**Behavior with bypass enabled:**
- ✅ Returns cache if less than 5 minutes old (not 12 hours)
- ✅ Allows API call even during cooldown
- ✅ Does NOT update global refresh timestamp (preserves cooldown for portfolio refreshes)
- ✅ Still caches the result for future use

**Behavior with bypass disabled (default):**
- Returns cache if less than 12 hours old
- Blocks API calls during cooldown
- Updates global refresh timestamp
- Standard portfolio refresh behavior

### 2. AlternativePriceService.swift

**Updated methods to accept bypass flag:**

```swift
func fetchPrice(for asset: Asset, bypassCooldown: Bool = false) async throws -> Double
func fetchPriceAndChange(for asset: Asset, bypassCooldown: Bool = false) async throws -> (Double, Double?)
```

Passes bypass flag through to MarketstackService.

### 3. AddAssetView.swift

**Modified price loading to bypass cooldown:**

```swift
private func loadPrice() {
    // ...
    let price = try await AlternativePriceService.shared.fetchPrice(
        for: tempAsset, 
        bypassCooldown: true  // ← Users expect immediate price when adding
    )
    // ...
}
```

### 4. QuickAddTickerView.swift

**Modified popular asset selection to bypass cooldown:**

```swift
private func selectAsset(_ asset: ...) {
    // ...
    let price = try await AlternativePriceService.shared.fetchPrice(
        for: tempAsset,
        bypassCooldown: true  // ← Users expect immediate price when selecting
    )
    // ...
}
```

## Usage Patterns

### Portfolio Refresh (Respects Cooldown)

```swift
// In PortfolioViewModel.refreshPrices()
let (price, change) = try await AlternativePriceService.shared.fetchPriceAndChange(for: asset)
// Uses default bypassCooldown: false
// Respects 12-hour cooldown
```

### Adding New Asset (Bypasses Cooldown)

```swift
// In AddAssetView.loadPrice()
let price = try await AlternativePriceService.shared.fetchPrice(
    for: asset, 
    bypassCooldown: true
)
// Bypasses cooldown
// Gets fresh price immediately
```

## API Token Conservation

### Scenario: User Adds 3 New Assets During Cooldown

**Before (broken):**
1. Add AAPL → Cooldown blocks → Shows fallback $185.50 ❌
2. Add MSFT → Cooldown blocks → Shows fallback $380.20 ❌
3. Add GOOGL → Cooldown blocks → Shows fallback $140.50 ❌
- **API calls made:** 0
- **User experience:** Poor (stale prices)

**After (fixed):**
1. Add AAPL → Bypass cooldown → Fresh API call → $225.37 ✅
2. Add MSFT → Use cache (< 5 min) → $419.82 ✅
3. Add GOOGL → Use cache (< 5 min) → $145.23 ✅
- **API calls made:** 3 (acceptable for manual additions)
- **User experience:** Great (current prices)
- **Global cooldown:** Still active for portfolio refresh

### Token Usage Impact

**Monthly API quota: 100 calls**

**Typical usage:**
- Portfolio refreshes: ~2 per day × 30 days = 60 calls
- Adding new assets: ~5 per month = 5 calls
- **Total:** ~65 calls/month ✅

**Edge case (heavy adding during cooldown):**
- Portfolio refreshes: 60 calls
- Adding 20 assets during cooldown periods: 20 calls
- **Total:** ~80 calls/month ✅ (still under limit)

The bypass only affects single asset lookups, not bulk refreshes, so token impact is minimal.

## Console Logging

### Portfolio Refresh (Cooldown Active)

```
🔍 AlternativePriceService fetching price for: VTI (bypass: false)
🔍 fetchQuote called for: 'VTI' → cleaned: 'VTI' (bypass: false)
💾 Loaded 1 cached quotes from disk
   - VTI: 9m old
💾 Returning cached data for VTI (age: 9m)
✅ Got price from Marketstack/Yahoo: VTI = $338.19
```

### Adding New Asset (Bypass Enabled)

```
🔍 AlternativePriceService fetching price for: VTI (bypass: true)
🔍 fetchQuote called for: 'VTI' → cleaned: 'VTI' (bypass: true)
❌ Cache MISS for VTI (not in cache)
✅ Cooldown bypass allowed for single asset lookup
📡 API call for VTI in fetchQuote
📊 Marketstack data for VTI:
   Symbol: VTI
   Close: $338.19
   Date: 2026-03-05
💾 Saved 1 quotes to disk
📝 Single asset lookup - not updating global refresh timestamp
✅ Got price from Marketstack/Yahoo: VTI = $338.19
```

## Benefits

1. **Better UX**: Users get current prices when adding assets
2. **Smart conservation**: Portfolio refreshes still respect cooldown
3. **Minimal token impact**: Single lookups are infrequent
4. **Backwards compatible**: Default behavior unchanged (bypass: false)
5. **Flexible**: Can easily extend to other use cases

## Future Extensions

This pattern can be extended to other scenarios:

### Individual Asset Refresh Button
```swift
// In AssetDetailView
Button("Refresh Price") {
    let price = try await AlternativePriceService.shared.fetchPrice(
        for: asset,
        bypassCooldown: true  // Allow manual per-asset refresh
    )
}
```

### Quick Quote Lookup Tool
```swift
// In a "Quote Lookup" utility view
func lookupQuote(ticker: String) async {
    let quote = try await MarketstackService.shared.fetchQuote(
        ticker: ticker,
        bypassCooldown: true  // Quote lookup doesn't affect portfolio refresh
    )
}
```

### Settings: User-Controlled Bypass
```swift
@AppStorage("allowBypassCooldown") private var allowBypass = true

// Then use:
bypassCooldown: allowBypass && isManualAction
```

## Testing

### Test Case 1: Add Asset During Cooldown
1. Trigger a portfolio refresh
2. Wait 5 minutes (cooldown still active)
3. Add a new asset with ticker
4. Click "Load Price"
5. **Expected:** Price loads immediately despite cooldown

### Test Case 2: Portfolio Refresh Respects Cooldown
1. Trigger a portfolio refresh
2. Wait 5 minutes
3. Pull to refresh portfolio
4. **Expected:** Cooldown error, no API call

### Test Case 3: Cache Sharing
1. Add asset AAPL with bypass (API call)
2. Immediately add asset MSFT with bypass (API call)
3. Within 5 minutes, portfolio refresh expires cooldown
4. Refresh portfolio
5. **Expected:** AAPL and MSFT use cached prices, other assets fetch fresh

## Summary

✅ **Portfolio refreshes** → Respect 12-hour cooldown
✅ **Adding new assets** → Bypass cooldown (< 5 min cache)
✅ **Token conservation** → Minimal impact (~5-10 extra calls/month)
✅ **User experience** → Much better for asset management
✅ **Backwards compatible** → Default behavior unchanged

The implementation strikes the perfect balance between user experience and API quota conservation.
