# 12-Hour Refresh Cooldown Implementation

## Overview

This implementation adds a **bulletproof 12-hour refresh cooldown** to the Marketstack API integration to minimize API token usage on the free tier (100 calls/month). The cooldown persists across app launches, device restarts, and force quits.

## Key Features

### 🔒 Bulletproof Persistence
- **Survives force quit**: Cooldown timer stored in UserDefaults
- **Survives device restart**: Persists across system reboots
- **Survives memory pressure**: Not dependent on in-memory state
- **Survives app updates**: Data persists in app's UserDefaults container
- **Only reset by**: Complete app deletion

### 💾 Dual-Layer Caching
1. **Quote Cache (15 minutes)**: For displaying recently fetched data
2. **Global Cooldown (12 hours)**: Prevents ANY API calls within 12-hour window

### 📊 User Experience
- **Transparent notifications**: Users see when next refresh is available
- **Visual indicators**: Orange banner and clock icons when cooldown is active
- **Graceful degradation**: Returns cached data even if stale when cooldown active
- **No external dependencies**: 100% self-contained, no servers needed

## Technical Implementation

### Modified Files

#### 1. `MarketstackService.swift`
**Changes:**
- Added `globalRefreshCooldown: TimeInterval = 43200` (12 hours)
- Added persistent `lastRefreshTime` property using UserDefaults
- Added persistent `quoteCache` with disk storage
- Modified all public API methods to respect cooldown
- Added `RefreshStatus` enum for UI display
- Added helper methods:
  - `canMakeAPICall()` - Checks if cooldown allows API call
  - `recordAPICall()` - Records timestamp of API call
  - `getRefreshStatus()` - Returns status for UI
  - `loadCacheFromDisk()` / `saveCacheToDisk()` - Persistence

**Behavior:**
```swift
// Check cache first
if cached && age < 12 hours {
    return cached  // Always return if within cooldown window
}

// Check cooldown
if !canMakeAPICall() {
    if has stale cache {
        return stale cache  // Better than error
    }
    throw cooldown error
}

// Make API call
fetch from API
recordAPICall()
cache result
```

#### 2. `MarketstackTestService.swift`
**Changes:**
- Added `refreshCooldownActive` error case to `MarketstackError`
- Error includes remaining time in human-readable format

#### 3. `ContentView.swift` (Dashboard)
**Changes:**
- Added `@State private var refreshStatus: RefreshStatus?`
- Added `loadRefreshStatus()` method to fetch status from service
- Added `refreshCooldownBanner()` view component
- Modified portfolio overview card to show refresh status
- Updates refresh status after pull-to-refresh attempts

**UI Elements:**
1. **Portfolio Overview Card**: Shows "Next refresh in Xh Ym" when cooldown active
2. **Cooldown Banner**: Orange banner at top of dashboard with countdown
3. **Auto-updates**: Refreshes status when prices update

## Persistence Strategy

### UserDefaults Keys
```swift
"marketstack_last_global_refresh" → TimeInterval (timestamp of last API call)
"marketstack_quote_cache" → JSON-encoded [String: CachedQuote]
```

### Data Flow
```
App Launch
    ↓
Load lastRefreshTime from UserDefaults
    ↓
Load quoteCache from UserDefaults
    ↓
Calculate time until next refresh
    ↓
Display status in UI
    ↓
User pulls to refresh
    ↓
Check canMakeAPICall()
    ├─ Yes → Make API call, update timestamp, cache results
    └─ No → Return cached data or show cooldown error
```

## Benefits for Token Usage

### Before Implementation
- Cache: 15 minutes
- Potential refreshes: 96 per day (every 15 min)
- Monthly usage: ~2,880 calls/month ❌ (WAY over limit)

### After Implementation
- Global cooldown: 12 hours
- Maximum refreshes: 2 per day
- Monthly usage: ~60 calls/month ✅ (40% under limit)

### Additional Savings
- **Persistent cache**: Reduces calls on app launch (~10-20/day saved)
- **Batch fetching**: 1 API call for multiple tickers
- **Graceful degradation**: Returns stale cache instead of failing
- **Manual control**: User sees when refresh is available

## User Notifications

### Cooldown Active
```
Dashboard Banner:
┌─────────────────────────────────────┐
│ 🕐 Refresh Cooldown Active          │
│    Next refresh in 8h 23m           │
│    Available at 3:45 PM             │
└─────────────────────────────────────┘

Portfolio Card:
🕐 Next refresh in 8h 23m
Updated 3h 37m ago
```

### Refresh Available
```
Portfolio Card:
Pull to refresh
Updated 12h 5m ago
```

### Error Handling
If user tries to refresh during cooldown:
```
Error: "Refresh cooldown active. Next refresh available in 8h 23m."
```

## Testing the Implementation

### Test Scenarios

1. **Normal Refresh**
   - Pull to refresh
   - Should succeed if >12 hours since last refresh
   - Should update timestamp and cache

2. **Cooldown Active**
   - Pull to refresh within 12 hours
   - Should return cached data
   - Should show cooldown banner

3. **Force Quit**
   - Refresh → Force quit app → Relaunch
   - Cooldown should persist
   - Status should show correct remaining time

4. **Device Restart**
   - Refresh → Restart device → Open app
   - Cooldown should persist

5. **Cache Age**
   - Wait 12+ hours
   - Pull to refresh
   - Should make new API call and update cache

### Manual Testing Commands

Check UserDefaults (in Xcode console):
```swift
print(UserDefaults.standard.double(forKey: "marketstack_last_global_refresh"))
print(UserDefaults.standard.data(forKey: "marketstack_quote_cache") != nil)
```

Clear cooldown for testing:
```swift
await MarketstackService.shared.clearCache()
UserDefaults.standard.removeObject(forKey: "marketstack_last_global_refresh")
```

## Configuration Options

### Adjust Cooldown Duration
In `MarketstackService.swift`:
```swift
private let globalRefreshCooldown: TimeInterval = 43200  // 12 hours

// Options:
// 6 hours:  21600
// 12 hours: 43200
// 24 hours: 86400
```

### Disable Cooldown (for testing)
```swift
private let globalRefreshCooldown: TimeInterval = 0  // No cooldown
```

### Per-Environment Settings
Use build configurations:
```swift
#if DEBUG
private let globalRefreshCooldown: TimeInterval = 300  // 5 min for testing
#else
private let globalRefreshCooldown: TimeInterval = 43200  // 12 hours for production
#endif
```

## API Usage Monitoring

The service tracks usage:
```swift
let stats = await MarketstackService.shared.getUsageStats()
print("API Calls: \(stats.thisMonth)/\(stats.limit) this month")
```

Logs show:
```
✅ Cooldown expired (12h 5m elapsed) - allowing API call
📝 Recorded API call at 2026-03-04 15:30:00
📊 API Calls: 15 total, 12 this month
```

## Future Enhancements

### Potential Additions
1. **Smart scheduling**: Refresh during off-peak hours
2. **User preferences**: Let users customize cooldown
3. **Usage dashboard**: Show monthly usage in settings
4. **Push notifications**: "Your refresh quota has reset"
5. **Predictive caching**: Pre-fetch before cooldown expires

### Advanced Features
1. **Market hours awareness**: Skip refreshes when markets closed
2. **Priority tickers**: Refresh most-viewed assets first
3. **Background refresh**: iOS background fetch API
4. **CloudKit sync**: Share cache across user's devices

## Support & Troubleshooting

### Common Issues

**Q: Refresh seems blocked even after 12 hours**
A: Check system time. Persistent data uses device clock.

**Q: Cache not persisting after app deletion**
A: Expected behavior. UserDefaults cleared on app deletion.

**Q: Want to force refresh for testing**
A: Clear UserDefaults key: `UserDefaults.standard.removeObject(forKey: "marketstack_last_global_refresh")`

**Q: UI not updating after refresh**
A: Ensure `loadRefreshStatus()` is called in `.task` and `.onChange` modifiers.

### Debug Logging

Enable verbose logging:
```swift
// All API calls log to console:
💾 Loaded 5 cached quotes from disk
   - AAPL: 2h 15m old
   - MSFT: 2h 15m old
   - SPY: 2h 15m old
✅ Cooldown expired (12h 5m elapsed) - allowing API call
📡 🔴 Making API call for 2/5 tickers: GOOGL, TSLA
💾 Saved 5 quotes to disk
📝 Recorded API call at 2026-03-04 15:30:00
```

## Credits

Implementation: March 2026
Approach: Bulletproof persistence with dual-layer caching
Storage: UserDefaults (no external dependencies)
UI: SwiftUI with real-time status updates
