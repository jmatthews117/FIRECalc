# Auto-Refresh Implementation

## Summary
Disabled pull-to-refresh gesture and replaced it with automatic refresh on app open/foreground, while maintaining the existing cooldown protection.

## Changes Made

### 1. Disabled Pull-to-Refresh UI
**Files Modified:**
- `ContentView.swift` - `DashboardTabView` body
- `grouped_portfolio_view.swift` - `GroupedPortfolioView` body

Changes:
- Commented out the `.refreshable` modifier while keeping the code for potential future re-enable
- Added comment: "PULL-TO-REFRESH DISABLED: Auto-refresh on app open/foreground instead"

### 2. Updated UI Text
**Files Modified:**
- `ContentView.swift` - Dashboard portfolio overview card
- `grouped_portfolio_view.swift` - Portfolio summary card

Changes:
- Changed "Pull to refresh" to "Auto-refreshes on open"
- Located in the portfolio overview/summary card sections
- Shows when user has assets (Dashboard also checks Pro subscription status)

### 3. Added Auto-Refresh Logic - Dashboard
- **File**: `ContentView.swift`
- **Location**: `DashboardTabView.portfolioOverviewCard`

Added scene phase monitoring that:
- Detects when the app becomes active (`.active` state)
- Automatically calls `portfolioVM.refreshPricesIfNeeded()` which respects the cooldown
- Updates refresh status after attempting refresh
- Includes debug logging: "📱 Dashboard active - attempting auto-refresh (subject to cooldown)"

### 4. Added Auto-Refresh Logic - Portfolio
- **File**: `grouped_portfolio_view.swift`
- **Location**: `GroupedPortfolioView` body

Added scene phase monitoring that:
- Detects when the app becomes active (`.active` state)
- Automatically calls `portfolioVM.refreshPricesIfNeeded()` which respects the cooldown
- Updates refresh status after attempting refresh
- Includes debug logging: "📱 Portfolio active - attempting auto-refresh (subject to cooldown)"

### 5. Environment Variables Added
**Files Modified:**
- `ContentView.swift` - `DashboardTabView`
- `grouped_portfolio_view.swift` - `GroupedPortfolioView`

Changes:
- Added `@Environment(\.scenePhase) private var scenePhase`
- Enables monitoring of app lifecycle states

## Behavior

### When App Opens (Cold Start)
1. App launches
2. ContentView's `onChange(of: scenePhase)` triggers when entering `.active`
3. DashboardTabView and GroupedPortfolioView also detect `.active` if visible
4. All call `portfolioVM.refreshPricesIfNeeded()` (cooldown ensures only one succeeds)
5. If cooldown allows, prices are refreshed

### When Returning from Background
1. User switches back to app from another app
2. ContentView, DashboardTabView, and/or GroupedPortfolioView detect `.active` state
3. `refreshPricesIfNeeded()` is called (only one will succeed due to cooldown protection)
4. Refresh status is updated to reflect any cooldown

### When Tab Switching
1. User switches between Dashboard and Portfolio tabs
2. Scene phase remains `.active`, so no refresh triggered
3. This prevents unnecessary refreshes when navigating within the app

### Multi-Layer Protection
The app has multiple layers calling auto-refresh:
- **ContentView level**: Triggers on any app activation
- **DashboardTabView level**: Triggers when Dashboard becomes active
- **GroupedPortfolioView level**: Triggers when Portfolio becomes active

This redundancy ensures refreshes happen regardless of which tab is visible, but the cooldown system prevents duplicate API calls.

## Cooldown Protection
All auto-refresh attempts go through `refreshPricesIfNeeded()` which:
- Checks if enough time has elapsed since last refresh
- Respects the API rate limiting cooldown period
- Prevents excessive API calls
- Updates UI to show cooldown status when active

## User Experience Improvements
1. **No Manual Action Required**: Prices update automatically when opening the app
2. **No Accidental Refreshes**: Removed pull-to-refresh prevents unintentional triggers
3. **Clear Status**: UI shows "Auto-refreshes on open" to set expectations
4. **Cooldown Visibility**: Cooldown banner still appears when refresh isn't available
5. **Seamless Updates**: Users get fresh data without thinking about it

## Code Preservation
- All pull-to-refresh code is preserved in comments
- Can be quickly re-enabled if needed
- `lastPullRefresh` state variable maintained for consistency

## Testing Recommendations
1. **Cold Launch**: Test app launch from scratch → should auto-refresh (subject to cooldown)
2. **Background Return**: Test switching to another app and back → should auto-refresh (subject to cooldown)
3. **Dashboard Tab**: Open app on Dashboard → should trigger refresh
4. **Portfolio Tab**: Open app on Portfolio → should trigger refresh
5. **Tab Switching**: Switch between tabs → should NOT trigger refresh (scene phase stays `.active`)
6. **Rapid Cycles**: Test rapid foreground/background cycles → should be protected by cooldown
7. **Cooldown Banner**: Verify cooldown banner appears on both Dashboard and Portfolio when active
8. **Status Text**: Confirm "Auto-refreshes on open" text displays on both views (Dashboard checks Pro subscription)
9. **Pull Gesture**: Verify pull-to-refresh gesture no longer works
10. **Manual Refresh**: Confirm manual refresh via Settings still works if implemented
