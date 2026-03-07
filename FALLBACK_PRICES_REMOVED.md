# Hardcoded Fallback Prices - REMOVED

## Date: March 6, 2026

## Problem

The app was using hardcoded fallback prices when API calls failed:
```swift
private let fallbackPrices: [String: Double] = [
    "SPY": 485.50, "VTI": 338.19, "QQQ": 415.30, "DIA": 385.20,
    "META": 425.60, "UBER": 68.50, ...
]
```

These prices:
- ❌ Were static/outdated
- ❌ Could be completely wrong
- ❌ Showed as "success" even though no real data was fetched
- ❌ Misleading to users (showing fake prices as real)

## Solution

Removed ALL hardcoded fallback prices. Now the app only uses:
- ✅ **Fresh data from API** (when cooldown allows)
- ✅ **Cached data** (from previous successful API calls)
- ✅ **User-entered prices** (the original `unitValue` they input)

If a price can't be fetched, it **fails gracefully** instead of using fake data.

## Changes Made

### 1. ✅ Removed `fallbackPrices` Dictionary

**File:** `alternative_price_service.swift`

**Removed:**
```swift
private let fallbackPrices: [String: Double] = [
    "SPY": 485.50, "VTI": 338.19, "QQQ": 415.30, "DIA": 385.20,
    "AAPL": 185.50, "MSFT": 380.20, "AMZN": 155.80, "GOOGL": 140.50,
    "TSLA": 245.30, "NVDA": 495.20, "META": 425.60, "BRK.B": 385.40,
    "UBER": 68.50, "LYFT": 15.20, "NFLX": 485.60, "DIS": 95.30,
    // ... 40+ more hardcoded prices
]
```

This entire dictionary has been deleted.

### 2. ✅ Removed `fetchFromFallback()` Method

**Removed:**
```swift
private func fetchFromFallback(ticker: String) throws -> Double {
    guard let price = fallbackPrices[ticker] else {
        throw PriceServiceError.tickerNotFound(ticker)
    }
    return price
}
```

### 3. ✅ Updated `fetchPriceAndChange()` to Throw Errors

**Before:**
```swift
func fetchPriceAndChange(for asset: Asset, bypassCooldown: Bool) async throws -> (price: Double, changePercent: Double?) {
    do {
        let result = try await fetchFromYahooWithChange(...)
        return result
    } catch {
        // Fall back to hardcoded price
        let fallbackPrice = try fetchFromFallback(ticker: cleanTicker)
        return (fallbackPrice, nil)  // ← Fake success!
    }
}
```

**After:**
```swift
func fetchPriceAndChange(for asset: Asset, bypassCooldown: Bool) async throws -> (price: Double, changePercent: Double?) {
    // Fetch from API or cache - NO hardcoded fallbacks
    let result = try await fetchFromYahooWithChange(...)
    return result
    // ← If fails, throws error (honest failure)
}
```

### 4. ✅ Updated Error Messages

**Before:**
```swift
case .tickerNotFound(let ticker):
    return "Ticker '\(ticker)' not found. Using fallback prices - add IEX API key in Settings for live data."
```

**After:**
```swift
case .tickerNotFound(let ticker):
    return "Unable to fetch price for '\(ticker)'. Check ticker symbol or try again later."
```

### 5. ✅ Updated Log Messages

**File:** `portfolio_viewmodel.swift`

**Changed:**
```swift
// Before:
AppLogger.debug("   ✅ [\(ticker)] Updated to $\(price) (fallback)")

// After:
AppLogger.debug("   ✅ [\(ticker)] Updated to $\(price) (individual fetch)")
```

## New Behavior

### Scenario 1: API Returns Price ✅
```
📡 Fetching price for SPY
✅ Got price from API/cache: SPY = $485.50
✅ [SPY] Updated to $485.50
```
**Result:** Asset updated with real price

### Scenario 2: Price in Cache ✅
```
💾 Cache HIT for SPY (age: 2h 15m)
✅ [SPY] Updated to $485.50
```
**Result:** Asset updated with cached price (from previous API call)

### Scenario 3: API Fails (Cooldown) ❌
```
⏳ Cooldown active - 11h 30m remaining
❌ [SPY] Failed: Refresh cooldown active
```
**Result:** Asset shows as failed. Uses last known price (user's original `unitValue`)

### Scenario 4: API Fails (Network Error) ❌
```
❌ Unable to fetch price for 'SPY': Network error
❌ [SPY] Failed: Network error
```
**Result:** Asset shows as failed. Uses last known price (user's original `unitValue`)

### Scenario 5: Invalid Ticker ❌
```
❌ Unable to fetch price for 'INVALID': Ticker not found
❌ [INVALID] Failed: Ticker not found
```
**Result:** Asset shows as failed. Uses last known price (user's original `unitValue`)

## What Prices Are Used Now?

### Priority Order:

1. **Fresh API data** (if cooldown allows and API succeeds)
   ```swift
   asset.currentPrice = $485.50  // From API
   asset.lastUpdated = Date()     // Just now
   ```

2. **Cached API data** (if within 12-hour window)
   ```swift
   asset.currentPrice = $485.50  // From cache
   asset.lastUpdated = Date()     // 2 hours ago
   ```

3. **User's original price** (if no API data available)
   ```swift
   asset.currentPrice = nil       // No live price
   asset.unitValue = $480.00      // User entered
   ```

### Asset Value Calculation:

From `asset_model.swift`:
```swift
var totalValue: Double {
    if let current = currentPrice {
        return current * quantity  // Use live/cached price if available
    }
    return unitValue * quantity    // Fall back to user's original price
}
```

This is **correct** - the user's originally entered price is the true fallback, not fake hardcoded values.

## Impact

### Before (with hardcoded fallbacks):
```
🔄 REFRESH: Success: 14/28
```
- 4 assets: Real cached prices ✅
- 10 assets: Fake hardcoded prices ❌ (shown as "success")
- 14 assets: Failed (no hardcoded price available)

**Problem:** User sees "success" but 10 assets have fake prices!

### After (no hardcoded fallbacks):
```
🔄 REFRESH: Success: 4/28
🔄 REFRESH: Failed: 24/28
```
- 4 assets: Real cached prices ✅
- 24 assets: Failed (cooldown active) ⏰

**Better:** Honest reporting. User knows 24 assets need fresh data.

The 24 "failed" assets will still display using their **user-entered prices** (`unitValue`), which is the correct fallback.

## User Experience

### What Users See:

**Assets With Live/Cached Prices:**
```
SPY: $485.50 (updated 2 hours ago)
```
Shows real market price.

**Assets Without Live Prices (Cooldown/Error):**
```
META: $420.00 (price from your entry)
```
Shows the price the user originally entered when they added the asset. This is **honest** - it's not claiming to be a current market price.

**When Cooldown Expires:**
All assets will refresh with real prices:
```
📡 BATCH API: Fetching 28 tickers in single request
✅ All 28 assets updated with real prices
```

## Benefits

| Before (Hardcoded Fallbacks) | After (No Fallbacks) |
|------------------------------|---------------------|
| ❌ Shows fake prices | ✅ Shows real prices only |
| ❌ Misleading "success" messages | ✅ Honest success/failure reporting |
| ❌ Users think prices are current | ✅ Users know which prices are stale |
| ❌ Portfolio value could be completely wrong | ✅ Portfolio uses user-entered prices when live data unavailable |
| ❌ No indication prices are fake | ✅ Clear indication when refresh needed |

## Summary

**Removed:**
- ❌ 40+ hardcoded stock prices
- ❌ `fallbackPrices` dictionary
- ❌ `fetchFromFallback()` method
- ❌ References to "using fallback prices" in error messages
- ❌ Fake "success" when using hardcoded data

**Now Only Uses:**
- ✅ Fresh API data (when available)
- ✅ Cached API data (from previous successful calls)
- ✅ User-entered prices (as proper fallback)

**Result:** Honest, accurate portfolio pricing that never lies to users about market prices.
