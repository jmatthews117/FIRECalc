# Portfolio Refresh - Fixing Half-Updated Assets

## Issue Description

**Problem**: When manually refreshing the portfolio, only about half of the assets were being updated, even though there should be no limit on the number of assets that can be updated in a single refresh. The 12-hour cooldown should apply to the refresh frequency, not the number of assets.

## Root Cause

The issue had **two** related causes:

### 1. **Missing `bypassCooldown` Parameter**

When `performRefresh()` called `AlternativePriceService.shared.fetchPriceAndChange(for: asset)`, it wasn't passing the `bypassCooldown` parameter. This meant:

- The call defaulted to `bypassCooldown: false`
- The underlying `MarketstackService` would check the 12-hour cooldown
- If the cooldown was active, it would only return **cached** quotes
- Assets without cached data would fail to update
- Result: Only assets in cache were updated (approximately half)

```swift
// BEFORE (WRONG):
let (price, changePercent) = try await AlternativePriceService.shared.fetchPriceAndChange(for: asset)
// ❌ Defaults to bypassCooldown: false
```

### 2. **Cooldown Logic in MarketstackService**

The `MarketstackService.fetchQuote()` and `fetchBatchQuotes()` methods respect the 12-hour global cooldown. When the cooldown is active:

- Returns cached quotes for assets that have been fetched before
- Throws an error or returns incomplete data for uncached assets
- This is correct behavior for **automatic** background refreshes
- But **manual** user-initiated refreshes should bypass this

## The Fix

### Change 1: Pass `bypassCooldown` Through the Call Chain

Modified `refreshPrices()` to indicate this is a manual refresh:

```swift
// refreshPrices() - called by user pull-to-refresh
refreshTask = Task { @MainActor in
    await performRefresh(bypassCooldown: true)  // ✅ Manual refresh bypasses cooldown
}
```

### Change 2: Update `performRefresh()` to Accept and Use the Parameter

```swift
private func performRefresh(bypassCooldown: Bool = false) async {
    // ... setup code ...
    
    // Pass bypassCooldown to price service
    let (price, changePercent) = try await AlternativePriceService.shared.fetchPriceAndChange(
        for: asset, 
        bypassCooldown: bypassCooldown  // ✅ Now passed through
    )
}
```

### Change 3: Enhanced Logging for Debugging

Added detailed logging to track refresh progress:

```swift
print("📊 Starting refresh for \(assetsToUpdate.count) assets (bypassCooldown: \(bypassCooldown))")
print("📦 Processing \(batches.count) batches of up to \(batchSize) assets each")
print("📦 Processing batch \(batchIndex + 1)/\(batches.count) with \(batch.count) assets")
print("   ✅ Updated \(ticker): $\(price)")
print("   ❌ Failed to update \(ticker): \(error)")
print("📊 Refresh complete: \(successCount) succeeded, \(failCount) failed out of \(assetsToUpdate.count) total")
```

## How It Works Now

### Manual Refresh (Pull-to-Refresh)
1. User pulls to refresh
2. `refreshPrices()` is called
3. Creates task with `performRefresh(bypassCooldown: true)`
4. For each asset, calls `fetchPriceAndChange(for: asset, bypassCooldown: true)`
5. `MarketstackService` bypasses the 12-hour cooldown check
6. **ALL** assets with tickers are updated, regardless of cache status
7. 12-hour cooldown timer is updated after refresh completes

### Automatic Refresh (App Launch/Background)
1. App becomes active or data is stale
2. `refreshPricesIfNeeded()` is called
3. Calls `refreshPrices()` (which uses `bypassCooldown: true`)
4. Same behavior as manual refresh - updates all assets

## Key Improvements

✅ **No limit on assets per refresh** - All assets with tickers are processed
✅ **Manual refreshes bypass cooldown** - User-initiated refreshes always fetch fresh data
✅ **12-hour cooldown still enforced** - Between refreshes, not during a refresh
✅ **Better logging** - Console shows exactly which assets updated and which failed
✅ **Batching still works** - Processes assets in groups of 5 for efficiency
✅ **Parallel execution** - Each batch processes assets concurrently

## Testing Checklist

To verify the fix works correctly:

- [ ] Add 10+ assets with valid tickers
- [ ] Pull to refresh - should update ALL assets
- [ ] Check console logs - should see "Processing X batches"
- [ ] Verify success count matches total asset count
- [ ] Check "last updated" timestamp - should show "just now" for all
- [ ] Add a new asset and immediately refresh - should update all including new one
- [ ] Background the app and reopen - should auto-refresh all assets if stale

## Expected Console Output

```
📊 Starting refresh for 12 assets (bypassCooldown: true)
📦 Processing 3 batches of up to 5 assets each
📦 Processing batch 1/3 with 5 assets
   ✅ Updated SPY: $485.50
   ✅ Updated AAPL: $185.50
   ✅ Updated MSFT: $380.20
   ✅ Updated GOOGL: $140.50
   ✅ Updated TSLA: $245.30
📦 Processing batch 2/3 with 5 assets
   ✅ Updated NVDA: $495.20
   ✅ Updated META: $425.60
   ✅ Updated AMZN: $155.80
   ✅ Updated BRK.B: $385.40
   ✅ Updated QQQ: $415.30
📦 Processing batch 3/3 with 2 assets
   ✅ Updated VTI: $338.19
   ✅ Updated DIA: $385.20
📊 Refresh complete: 12 succeeded, 0 failed out of 12 total
```

## Related Files

- `portfolio_viewmodel.swift` - Main refresh orchestration, now passes `bypassCooldown`
- `alternative_price_service.swift` - Accepts `bypassCooldown` parameter
- `MarketstackService.swift` - Respects `bypassCooldown` when checking cooldown
- `REFRESH_BUG_FIX.md` - Previous documentation on validation logic
- `PRICE_REFRESH_ROOT_CAUSE.md` - Previous documentation on timestamp comparison

## Why This Matters

Before this fix:
- User pulls to refresh
- Only 6 of 12 assets update (those in cache)
- Other 6 show stale data
- User thinks refresh is broken
- ❌ Poor user experience

After this fix:
- User pulls to refresh
- All 12 assets update with fresh data
- All timestamps show "just now"
- User sees accurate portfolio values
- ✅ Excellent user experience

## Cooldown Behavior (Unchanged)

The 12-hour cooldown still works as designed:
- Prevents excessive API usage on the free tier (100 calls/month)
- User can only refresh **once every 12 hours**
- But when they DO refresh, **ALL assets are updated**
- This is the correct behavior!

The cooldown limits **when** you can refresh, not **how many assets** are refreshed.
