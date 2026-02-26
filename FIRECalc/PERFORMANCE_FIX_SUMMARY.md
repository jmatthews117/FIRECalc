# Performance Fix Summary

## Problem
The app was experiencing severe performance degradation with constant price update calls and UI recalculations, especially visible in the debugger showing continuous crypto API calls.

## Root Causes Identified

### 1. **FIRETimelineCard Expensive Calculations**
The `FIRETimelineCard` view was performing expensive 100-year projection calculations on **every SwiftUI body evaluation**, which happens:
- Every time `portfolioVM.objectWillChange` fires (during price updates)
- Every time `benefitManager.objectWillChange` fires
- Multiple times per second during active price refreshes

**Before:**
```swift
private var fireProjection: FIREProjection? {
    // This ran on EVERY render!
    var value = currentValue
    for year in 1...100 {
        // Complex calculations...
    }
    return projection
}
```

**After:**
- Added `@State` cached projection
- Added `CalculationInputs` struct to track what affects the calculation
- Only recalculate when inputs change meaningfully (e.g., portfolio changes by $100+)
- Prevents recalculation on minor price fluctuations

### 2. **No Debouncing on Price Refresh**
Multiple calls to `refreshPrices()` could overlap, causing:
- Duplicate API calls for the same ticker
- Race conditions in portfolio updates
- Wasted network bandwidth

**After:**
- Added `refreshTask` to track and cancel pending refreshes
- Added `lastRefreshTime` to prevent refreshes within 5 minutes
- Check `isUpdatingPrices` flag to prevent overlapping refreshes

### 3. **Missing Guards in refreshPricesIfNeeded**
The auto-refresh on app activation didn't check if:
- A refresh was already in progress
- Prices were recently updated

**After:**
- Added check for `isUpdatingPrices` flag
- Added 5-minute cooldown period
- Only refresh truly stale data

## Changes Made

### ContentView.swift
1. **FIRETimelineCard Performance**
   - Added `@State private var cachedProjection: FIREProjection?`
   - Added `@State private var lastCalculationInputs: CalculationInputs?`
   - Created `CalculationInputs` struct with smart equality checking
   - Split calculation into separate `calculateProjection()` method
   - Body now updates cache asynchronously only when needed

### portfolio_viewmodel.swift
1. **Debouncing & Guards**
   - Added `refreshTask` property to track active refresh operations
   - Added `lastRefreshTime` property for cooldown tracking
   - Modified `refreshPrices()` to cancel pending operations
   - Modified `refreshPricesIfNeeded()` with multiple guard checks
   - Track refresh time in `performRefresh()`

## Expected Results

### Before Fix:
- Constant API calls visible in debugger
- UI lag during price updates
- Battery drain from continuous network activity
- Potential rate limiting from APIs

### After Fix:
- Price updates only when explicitly requested or truly stale
- 5-minute minimum between automatic refreshes
- Calculation caching prevents UI performance degradation
- Single active refresh at a time (no overlaps)

## Testing Recommendations

1. **Verify No Constant Polling:**
   - Open debugger/network inspector
   - Navigate to Dashboard
   - Confirm no continuous API calls

2. **Verify Debouncing:**
   - Pull to refresh multiple times quickly
   - Confirm only one refresh actually executes
   - Check console logs for "skipping" messages

3. **Verify Caching:**
   - Watch Dashboard with FIRETimelineCard visible
   - Minor price changes should NOT trigger recalculation
   - Check logs for reduced calculation frequency

4. **Verify Cooldown:**
   - Refresh prices manually
   - Background app, then return within 5 minutes
   - Confirm no automatic refresh occurs

## Additional Notes

The `CalculationInputs.Equatable` implementation uses a tolerance of $100 for portfolio value changes. This prevents recalculation on every minor price tick while still updating on meaningful changes. Adjust this threshold if needed:

```swift
abs(lhs.currentValue - rhs.currentValue) < 100  // Current: $100 threshold
```

Consider lowering (e.g., to $10) if timeline updates feel too slow, or raising (e.g., to $1000) if you still see performance issues with very large portfolios.
