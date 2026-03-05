# Portfolio View Refresh Status Implementation

## Overview

Added the same refresh cooldown indicators to the **Portfolio tab** that exist on the Dashboard, ensuring consistent UI/UX across the app.

## Changes Made

### grouped_portfolio_view.swift

#### 1. Added State Variable
```swift
@State private var refreshStatus: RefreshStatus?
```

#### 2. Added Cooldown Banner at Top of ScrollView
When cooldown is active, shows prominent orange banner:
```
┌─────────────────────────────────────┐
│ 🕐 Refresh Cooldown Active          │
│    Next refresh in 8h 23m           │
│    Available at 3:45 PM             │
└─────────────────────────────────────┘
```

#### 3. Updated Portfolio Summary Card
Shows refresh status in footer:
- **Cooldown active:** "🕐 Next refresh in 8h 23m"
- **Refresh available:** "Pull to refresh"
- **Always shows:** "Updated 3h 37m ago" (last update time)

#### 4. Added Helper Methods

**loadRefreshStatus():**
```swift
private func loadRefreshStatus() async {
    let status = await MarketstackService.shared.getRefreshStatus()
    await MainActor.run {
        refreshStatus = status
    }
}
```

**refreshCooldownBanner():**
- Displays prominent orange banner when cooldown is active
- Shows remaining time and next available refresh time
- Matches Dashboard styling

**timeAgo():**
- Formats relative time ("3h 37m ago", "just now", etc.)
- Reused from Dashboard implementation

#### 5. Updated View Lifecycle

**On appear:**
```swift
.task {
    await loadRefreshStatus()
}
```

**On refresh:**
```swift
.refreshable {
    await portfolioVM.refreshPrices()
    await loadRefreshStatus()  // ← Update status after refresh
}
```

**On price update completion:**
```swift
.onChange(of: portfolioVM.isUpdatingPrices) { _, isUpdating in
    if !isUpdating {
        Task {
            await loadRefreshStatus()
        }
    }
}
```

## UI Behavior

### Scenario 1: Cooldown Active (< 12 hours since last refresh)

**Portfolio Summary Card:**
```
Total Value: $1,234,567.89

Expected Return: 7.2%    Volatility: 12.5%

🕐 Next refresh in 8h 23m
Updated 3h 37m ago
```

**Top of View:**
```
┌─────────────────────────────────────┐
│ 🕐 Refresh Cooldown Active          │
│    Next refresh in 8h 23m           │
│    Available at 3:45 PM             │
└─────────────────────────────────────┘
```

**User action:**
- Pulls to refresh → Uses cached data, no API call
- Cooldown banner remains visible
- Status updates to show remaining time

### Scenario 2: Refresh Available (> 12 hours since last refresh)

**Portfolio Summary Card:**
```
Total Value: $1,234,567.89

Expected Return: 7.2%    Volatility: 12.5%

Pull to refresh
Updated 12h 5m ago
```

**Top of View:**
- No cooldown banner shown

**User action:**
- Pulls to refresh → Makes API call, gets fresh data
- Cooldown resets to 12 hours
- Banner appears after refresh

### Scenario 3: Adding New Assets (Bypass Active)

**User adds new asset with ticker:**
- Asset price lookup → Bypasses cooldown ✅
- Gets fresh price immediately
- Portfolio refresh status → Still shows cooldown ✅
- Consistent with Dashboard behavior

## Consistency with Dashboard

Both views now show:
- ✅ Orange cooldown banner when active
- ✅ Clock icon with remaining time
- ✅ "Updated X ago" timestamp
- ✅ "Pull to refresh" when available
- ✅ Real-time status updates
- ✅ Same styling and colors

## User Experience

### Before
- No indication of cooldown on Portfolio tab
- Users confused why refresh doesn't work
- Inconsistent with Dashboard

### After
- Clear visual feedback on cooldown status
- Users know exactly when next refresh is available
- Consistent across Dashboard and Portfolio
- Professional, polished experience

## Testing

### Test Case 1: View Consistency
1. Open Dashboard → See cooldown banner
2. Switch to Portfolio tab → See same cooldown banner
3. Times should match ✅

### Test Case 2: Refresh Updates Status
1. Portfolio tab with cooldown active
2. Pull to refresh (uses cache)
3. Status updates to reflect action ✅

### Test Case 3: Status Persists Across Tab Switches
1. Portfolio tab shows "Next refresh in 8h 23m"
2. Switch to Dashboard
3. Switch back to Portfolio
4. Status still shows correct time ✅

### Test Case 4: Adding Asset Doesn't Affect Cooldown
1. Portfolio shows "Next refresh in 8h 23m"
2. Add new asset with ticker (bypass)
3. Portfolio still shows "Next refresh in 8h 23m" ✅
4. Bypass doesn't update global cooldown

## Summary

✅ Portfolio tab now has full refresh status visibility
✅ Consistent UI/UX with Dashboard
✅ Users always know when refresh is available
✅ Professional, transparent experience
✅ Matches Apple design guidelines for status feedback
