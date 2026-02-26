# Performance Fixes Applied - Quick Reference

## What Was Fixed

### 🔴 Critical Issues Fixed

1. **Constant Price Update Loop**
   - **Symptom:** Debugger showing continuous crypto/stock API calls
   - **Cause:** No cooldown period or debouncing on refresh calls
   - **Fix:** Added 5-minute cooldown and refresh task cancellation

2. **Expensive UI Recalculations**
   - **Symptom:** UI lag when viewing Dashboard
   - **Cause:** `FIRETimelineCard` running 100-year projections on every render
   - **Fix:** Implemented calculation caching with smart dirty-checking

### 🟡 Secondary Improvements

3. **Overlapping Refresh Operations**
   - **Fix:** Added guard to prevent multiple simultaneous refreshes
   - **Benefit:** Reduced network calls and race conditions

4. **Redundant Recalculations**
   - **Fix:** Only recalculate when portfolio changes by $100+ (configurable)
   - **Benefit:** Reduced CPU usage on minor price updates

## How to Test

### 1. Verify No Constant Polling
```
1. Open Xcode debugger
2. Run app on simulator/device
3. Navigate to Dashboard tab
4. Watch debugger console for 5+ minutes
5. ✅ Should see NO automatic refresh calls
6. ❌ If you see continuous API calls, the fix didn't work
```

### 2. Test Manual Refresh
```
1. Go to Dashboard
2. Pull down to refresh
3. Wait for completion
4. Immediately pull down again
5. ✅ Second refresh should be skipped with log message
6. Check console for: "⏭️ Prices refreshed recently - skipping"
```

### 3. Test Calculation Caching
```
1. Go to Dashboard with FIRE card visible
2. Watch console during price updates
3. ✅ Should see very few recalculation triggers
4. Portfolio needs to change by $100+ to trigger recalc
```

### 4. Test App Background/Foreground
```
1. Refresh prices manually
2. Note the time
3. Background the app (Home button)
4. Wait 2-3 minutes
5. Foreground the app
6. ✅ Should skip refresh with "recently refreshed" message
```

## Configuration Options

### Adjust Calculation Sensitivity
In `ContentView.swift`, find `CalculationInputs.Equatable`:

```swift
static func ==(lhs: CalculationInputs, rhs: CalculationInputs) -> Bool {
    return abs(lhs.currentValue - rhs.currentValue) < 100 && // <- Change this
```

- **Lower value (e.g., 10):** More responsive, slightly more CPU
- **Higher value (e.g., 1000):** Less responsive, better performance
- **Recommended:** 100 for most users

### Adjust Refresh Cooldown
In `portfolio_viewmodel.swift`, find `refreshPricesIfNeeded()`:

```swift
if let lastRefresh = lastRefreshTime, Date().timeIntervalSince(lastRefresh) < 300 { // <- 300 = 5 minutes
```

- **Lower value (e.g., 60):** More frequent updates, more network usage
- **Higher value (e.g., 600):** Less frequent updates, better battery
- **Recommended:** 300 (5 minutes) for most users

## Still Having Issues?

### If you still see constant API calls:

1. **Check for additional price refresh triggers:**
   ```bash
   # Search for these in your codebase:
   - .onAppear { refreshPrices() }
   - Timer.publish
   - Task { while true { ... } }
   ```

2. **Check if AlternativePriceService is being called directly:**
   - All price fetching should go through `PortfolioViewModel.refreshPrices()`
   - Direct calls bypass the debouncing logic

3. **Verify the fix was applied:**
   - Check `ContentView.swift` for `cachedProjection`
   - Check `portfolio_viewmodel.swift` for `refreshTask` and `lastRefreshTime`

### If calculations still seem slow:

1. **Profile with Instruments:**
   - Use Time Profiler to find bottlenecks
   - Look for hot paths in `FIRETimelineCard` body evaluation

2. **Check Portfolio Model:**
   - Ensure `weightedExpectedReturn` and similar properties are cached
   - Consider adding memoization if they're computed properties

3. **Increase cache threshold:**
   - Raise the $100 threshold to $500 or $1000
   - This will reduce recalculation frequency

## Migration Notes

### Breaking Changes
None - these are pure performance optimizations that don't affect functionality.

### Data Migration
Not required - no changes to saved data structures.

### Rollback
If issues occur, revert these files:
- `ContentView.swift` - FIRETimelineCard section
- `portfolio_viewmodel.swift` - refreshPrices methods

## Monitoring

Add these temporary debug logs to monitor performance:

```swift
// In FIRETimelineCard body:
let _ = print("🎯 FIRE card rendered at \(Date())")

// In PortfolioViewModel.refreshPrices():
print("🔄 Refresh requested at \(Date())")
```

After 5 minutes of app use, you should see:
- **Many** "FIRE card rendered" logs (this is normal)
- **Very few** "Refresh requested" logs (only manual refreshes + one on launch)

If you see lots of refresh requests, there's still an issue to investigate.
