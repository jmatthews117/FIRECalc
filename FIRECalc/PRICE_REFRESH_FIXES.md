# Price Refresh System - Fixes and Improvements

## Issues Fixed

### 1. **No Automatic Refresh on App Launch**
**Problem**: Prices were only updated when manually triggered via pull-to-refresh or when creating a new asset. The app never refreshed stale price data automatically.

**Solution**: Added automatic price refresh on app initialization and when returning to the foreground.

### 2. **No Scene Phase Monitoring**
**Problem**: When users switched away from the app and returned, prices weren't refreshed even if they were stale.

**Solution**: Added `scenePhase` monitoring to trigger automatic refresh when app becomes active.

### 3. **Limited User Feedback**
**Problem**: Users couldn't tell when prices were last updated or if the refresh was working.

**Solution**: Added "last updated" timestamp display and improved loading indicators.

## Changes Made

### PortfolioViewModel.swift

#### Added Auto-Refresh on Init
```swift
init(portfolio: Portfolio? = nil) {
    // ... existing code ...
    
    // Automatically refresh prices on launch if we have stale data
    Task {
        await refreshPricesIfNeeded()
    }
}
```

#### New Method: `refreshPricesIfNeeded()`
This method intelligently checks if prices need updating before making API calls:
- Checks for assets with stale data (older than 1 hour)
- Checks for assets with tickers but no price data at all
- Only triggers refresh if needed

```swift
func refreshPricesIfNeeded() async {
    let assetsNeedingUpdate = portfolio.assetsNeedingPriceUpdate
    let assetsWithoutPrices = portfolio.assetsWithTickers.filter { $0.currentPrice == nil }
    
    guard !assetsNeedingUpdate.isEmpty || !assetsWithoutPrices.isEmpty else {
        print("✅ All prices are fresh")
        return
    }
    
    print("🔄 Auto-refreshing \(max(assetsNeedingUpdate.count, assetsWithoutPrices.count)) stale/missing prices...")
    await refreshPrices()
}
```

#### Added Public Method: `clearMessages()`
Allows views to manually clear success/error messages.

### ContentView.swift

#### Scene Phase Monitoring
Added environment variable and onChange handler:
```swift
@Environment(\.scenePhase) private var scenePhase

// In body:
.onChange(of: scenePhase) { oldPhase, newPhase in
    if newPhase == .active {
        Task {
            await portfolioVM.refreshPricesIfNeeded()
        }
    }
}
```

#### Enhanced Dashboard Portfolio Card
- Shows "Updating..." text alongside progress indicator
- Displays "last updated" timestamp for assets with live prices
- Shows relative time (e.g., "5m ago", "2h ago")

#### Added Error/Success Feedback
- Error messages shown as alerts
- Success messages shown as green toast at top of screen
- Both auto-dismiss after 3 seconds

## How It Works Now

### On App Launch
1. App loads saved portfolio from persistence
2. Checks all assets with tickers for stale/missing price data
3. If any are found, automatically fetches fresh prices from Yahoo Finance
4. Updates happen in background without blocking UI

### When App Returns to Foreground
1. System detects scene phase change to `.active`
2. Triggers `refreshPricesIfNeeded()` 
3. Only refreshes if data is stale (>1 hour old)
4. Prevents unnecessary API calls

### Manual Refresh (Pull-to-Refresh)
1. User pulls down on Dashboard
2. Always fetches latest prices for all assets with tickers
3. Shows progress indicator and "Updating..." text
4. Displays success/error message when complete

### Staleness Definition
An asset's price data is considered "stale" if:
- `lastUpdated` is more than 1 hour old
- `lastUpdated` is nil (never fetched)
- Asset has a ticker but `currentPrice` is nil

This is defined in `Asset.isStale` property.

## User Experience Improvements

### Before
- ❌ Prices only updated when explicitly requested
- ❌ No indication of when prices were last updated
- ❌ Portfolio value could be outdated for hours/days
- ❌ Limited feedback during updates

### After
- ✅ Prices automatically refresh on app launch (if stale)
- ✅ Prices refresh when returning to app (if stale)
- ✅ Clear "last updated" timestamp shown
- ✅ Better loading indicators with status text
- ✅ Success/error messages with auto-dismiss
- ✅ Intelligent refresh prevents unnecessary API calls

## Testing Checklist

- [ ] Launch app with assets that have tickers - prices should auto-update
- [ ] Background app for 2+ hours, return - prices should auto-update
- [ ] Pull-to-refresh on Dashboard - should always update
- [ ] Create new asset with ticker - should fetch price immediately
- [ ] Check "last updated" timestamp displays correctly
- [ ] Verify success toast appears after manual refresh
- [ ] Test with no internet - error alert should appear
- [ ] Test with invalid ticker - error should be shown for that asset

## Performance Considerations

- **Rate Limiting**: Yahoo Finance service includes 200ms delay between requests
- **Smart Updates**: Only updates stale data, not everything every time
- **Background Tasks**: All price fetching happens off the main thread
- **Cached Values**: `Asset.totalValue` uses cached `currentPrice` until next refresh

## API Usage

The app uses Yahoo Finance's public chart endpoint which:
- Requires no API key
- Has no explicit rate limits (but we rate-limit ourselves)
- Is free to use
- Works for stocks, ETFs, crypto (with -USD suffix)

## Future Enhancements

Possible improvements:
1. Allow users to configure staleness threshold (default 1 hour)
2. Add background fetch capability for iOS to update even when app closed
3. Show per-asset update status in detail view
4. Add "Force Refresh All" button in Settings
5. Cache historical price data for offline viewing
