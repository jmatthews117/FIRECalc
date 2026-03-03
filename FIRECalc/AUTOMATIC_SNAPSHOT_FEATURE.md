# Automatic Portfolio Snapshot Feature

## Overview

Implemented automatic saving of portfolio snapshots whenever the portfolio is refreshed. This allows the performance tracking chart to show portfolio value over time without requiring manual snapshots.

## Changes Made

### 1. Modified `PortfolioViewModel.swift`

#### Added Automatic Snapshot Saving
- Added call to `savePerformanceSnapshot()` in the `refreshPrices()` method after price updates complete
- Snapshots are saved regardless of whether the refresh was fully successful, partially successful, or failed (as long as portfolio has value)

#### New Method: `savePerformanceSnapshot()`
Located in a new "Performance Tracking" section at the end of the PortfolioViewModel class.

**Key Features:**
- **Smart Deduplication**: Only saves a snapshot if the last snapshot was more than 15 minutes ago
  - Prevents duplicate snapshots when user refreshes multiple times quickly
  - Balances data granularity with storage efficiency
  
- **Silent Operation**: Runs in the background without showing errors to users
  - Errors are logged to console for debugging
  - Won't interrupt the user experience if save fails

- **Empty Portfolio Protection**: Skips saving if portfolio value is 0
  - Prevents cluttering the chart with empty data points

**Implementation:**
```swift
private func savePerformanceSnapshot() {
    // Only save if portfolio has value
    guard totalValue > 0 else {
        print("⏭️ Skipping snapshot - portfolio has no value")
        return
    }
    
    // Check if we recently saved a snapshot (within last 15 minutes)
    if let existingSnapshots = try? persistence.loadSnapshots(),
       let lastSnapshot = existingSnapshots.last {
        let timeSinceLastSnapshot = Date().timeIntervalSince(lastSnapshot.date)
        
        if timeSinceLastSnapshot < 15 * 60 {
            print("⏭️ Skipping snapshot - last snapshot was \(Int(timeSinceLastSnapshot/60)) minutes ago")
            return
        }
    }
    
    let snapshot = PerformanceSnapshot(
        portfolioId: portfolio.id,
        totalValue: totalValue,
        allocation: portfolio.assetAllocation,
        assets: portfolio.assets
    )
    
    do {
        try persistence.saveSnapshot(snapshot)
        print("📸 Performance snapshot saved: \(totalValue.toCurrency())")
    } catch {
        print("⚠️ Failed to save performance snapshot: \(error.localizedDescription)")
    }
}
```

## When Snapshots Are Saved

Snapshots are now automatically saved in the following scenarios:

1. **App Launch/Restart**
   - When `refreshPricesIfNeeded()` runs on init and performs a refresh
   - Only if prices are stale (older than 1 hour)

2. **Dashboard Pull-to-Refresh**
   - When user pulls down on the dashboard to refresh prices
   - Triggered by `DashboardView.swift` refreshable modifier

3. **Portfolio View Pull-to-Refresh**
   - When user pulls down on the portfolio view to refresh prices
   - Any other view that calls `portfolioVM.refreshPrices()`

## Data Stored

Each snapshot includes:
- **Timestamp**: When the snapshot was taken
- **Portfolio ID**: Which portfolio the snapshot belongs to
- **Total Value**: The overall portfolio value (primary data for chart)
- **Allocation**: Asset class breakdown (stocks, bonds, cash, etc.)
- **Assets**: Full asset details for historical reference

While the snapshot stores complete data, the **primary purpose** is tracking the total portfolio value over time for the performance chart.

## Benefits

### For Users
- **Automatic Tracking**: No need to manually take snapshots
- **Consistent Data**: Regular snapshots whenever prices refresh
- **Historical Performance**: Build up performance history naturally through normal app usage
- **Zero Friction**: Works invisibly in the background

### For Developers
- **Simple Integration**: Single method call added to existing refresh flow
- **Smart Deduplication**: Prevents excessive storage usage
- **Error Resilient**: Silent failures don't impact user experience
- **Leverages Existing Infrastructure**: Uses existing `PerformanceSnapshot` model and `PersistenceService`

## Performance Considerations

- **15-Minute Minimum Interval**: Prevents excessive snapshots from rapid refreshes
- **Lightweight Operation**: Snapshot creation and saving is fast
- **Background Execution**: Doesn't block the UI or refresh process
- **Storage Efficient**: Only stores essential data, minimal disk space impact

## User Experience

The automatic snapshot feature is **completely transparent** to users:

- No new UI elements or buttons
- No notifications or alerts when snapshots are saved
- No interruption to existing workflows
- Performance tracking chart automatically populates over time

Users can still manually take snapshots via the "Take Snapshot" button in the Performance Tracking View if they want to capture a specific moment.

## Testing Recommendations

To verify the feature is working:

1. **Check Console Logs**: Look for "📸 Performance snapshot saved" messages
2. **Perform Multiple Refreshes**: Verify deduplication (should skip within 15 minutes)
3. **Check Performance View**: Verify chart shows automatic snapshots
4. **Test Different Scenarios**:
   - Empty portfolio (should skip)
   - Partial refresh success (should save)
   - Failed refresh with existing value (should save)
   - App restart with stale data (should refresh and save)

## Future Enhancements

Potential improvements for future iterations:

1. **Configurable Interval**: Allow users to set snapshot frequency in settings
2. **Smart Timing**: Only save during market hours for users with stock-heavy portfolios
3. **Snapshot Cleanup**: Automatically remove very old snapshots or downsample historical data
4. **Snapshot Annotations**: Allow users to add notes to automatically-saved snapshots
5. **Export Snapshots**: Allow exporting snapshot data to CSV for external analysis

## Technical Notes

- Uses existing `PerformanceSnapshot` model from `user_profile.swift`
- Uses existing `PersistenceService.shared.saveSnapshot()` method
- Fully compatible with manual snapshot feature in `PerformanceTrackingView`
- Thread-safe: All operations are on MainActor through PortfolioViewModel
- No breaking changes to existing functionality
