# Marketstack Service Refactor - March 8, 2026

## Problems Fixed

### 1. ❌ Fake "Batch API" That Didn't Save Calls
**Problem:** The code was trying to use a batch endpoint (`/api/quotes?symbols=A,B,C`) thinking it would save API calls, but **Marketstack charges 1 call per symbol regardless of batching**.

**Solution:** Removed the batch API endpoint and switched to individual calls for each symbol. This is more honest about what's happening and allows better error handling per symbol.

### 2. ❌ Incorrect Cooldown Duration
**Problem:** The cooldown was set to `60` seconds (1 minute) but the comment said "12 hours"

```swift
// ❌ BEFORE
private let globalRefreshCooldown: TimeInterval = 60  // 12 hours

// ✅ AFTER  
private let globalRefreshCooldown: TimeInterval = 43_200  // 12 hours (43,200 seconds)
```

### 3. ❌ Cache Loaded 28 Times Per Refresh
**Problem:** The computed property `quoteCache` was loading from disk every time it was accessed, resulting in 28 disk reads when checking cache for 28 tickers.

**Solution:** Load cache once into a local variable before the loop:
```swift
// ✅ Load once
let cache = quoteCache

for ticker in cleanTickers {
    if let cached = cache[ticker] {  // No disk access!
```

## How It Works Now

### Portfolio Refresh Flow

1. **Check Cache First**
   - Load cache from disk **once**
   - Return any tickers with fresh data (< 12 hours old)
   - Identify which tickers need fetching

2. **Check Cooldown**
   - If last refresh was < 12 hours ago → return stale cache only
   - If > 12 hours ago → proceed with API calls

3. **Start Refresh Session**
   ```swift
   isInRefreshSession = true
   ```
   - Allows all individual fetches to complete
   - Prevents cooldown from starting mid-refresh

4. **Fetch Missing Tickers Concurrently**
   ```swift
   await withTaskGroup(of: (String, MarketstackQuote?).self) { group in
       for ticker in tickersToFetch {
           group.addTask {
               try await self.fetchQuoteFromAPI(ticker: ticker)
           }
       }
   }
   ```
   - Makes **N individual API calls** (1 per symbol)
   - Runs them **concurrently** for speed
   - Handles failures gracefully (uses stale cache if available)

5. **End Refresh Session** (called by ViewModel)
   ```swift
   await MarketstackService.shared.endRefreshSession()
   ```
   - Sets `lastRefreshTime = Date()`
   - Starts the 12-hour cooldown timer

## API Call Count

### Example: Portfolio with 28 Assets

**First Refresh (empty cache):**
- Cache: 0 hits
- API calls: 28 (one per ticker)
- Cooldown starts: 12 hours

**Second Refresh (within 12 hours):**
- Cache: 28 hits  
- API calls: 0
- Cooldown continues

**Third Refresh (after 12 hours):**
- Cache: 0 hits (expired)
- API calls: 28 (one per ticker)
- Cooldown restarts: 12 hours

### Monthly Usage
- 100 calls/month free tier
- 28 tickers = ~3 refreshes per month
- For more refreshes, users need Pro subscription

## Testing the Changes

### To Test with Short Cooldown (2 minutes)
```swift
// In MarketstackService.swift
private let globalRefreshCooldown: TimeInterval = 120  // 2 min for testing
```

### To Test with Production Cooldown (12 hours)
```swift
// In MarketstackService.swift  
private let globalRefreshCooldown: TimeInterval = 43_200  // 12 hours
```

## Logs to Expect

### Successful Refresh
```
🔍 Checking cache for 28 tickers...
❌ Cache MISS for AAPL (not in cache)
❌ Cache MISS for GOOGL (not in cache)
...
✅ Pro user - Cooldown expired (12h 5m elapsed) - allowing API call
🔄 Started refresh session
📡 🔴 Making 28 individual API calls for: AAPL, GOOGL, MSFT, TSLA, AMZN...
🌐 [API] Fetching AAPL...
🌐 [API] Fetching GOOGL...
...
✅ [API] Received quote for AAPL: $150.25
✅ [API] Received quote for GOOGL: $2800.50
...
💾 Caching AAPL at 2026-03-08 19:30:00 +0000
💾 Caching GOOGL at 2026-03-08 19:30:01 +0000
...
✅ Fetched 28/28 quotes successfully (0 failed)
📊 API Calls: 28 total, 28 this month
```

### Cooldown Active
```
🔍 Checking cache for 28 tickers...
💾 Cache HIT for AAPL (age: 2h 15m)
💾 Cache HIT for GOOGL (age: 2h 15m)
...
⏳ Pro user - Cooldown active - 9h 45m remaining until next refresh
⏳ Cooldown active - returning cached data only (28/28 tickers)
💾 ✅ All 28 tickers served from cache - NO API CALL!
```

## Backend Changes Needed

Since we're no longer using the batch endpoint, you can simplify your backend:

### Remove This (if it exists)
```javascript
// ❌ No longer needed
app.get('/api/quotes', async (req, res) => {
    const symbols = req.query.symbols.split(',');
    // Complex batching logic...
});
```

### Keep This
```javascript
// ✅ Still needed - one call per symbol
app.get('/api/quote/:symbol', async (req, res) => {
    const symbol = req.params.symbol;
    // Fetch from Marketstack API
    // Return single quote
});
```

## Summary

✅ **Fixed:** Cooldown is now actually 12 hours (was 60 seconds)  
✅ **Fixed:** Cache only loaded once per refresh (was 28 times)  
✅ **Fixed:** Honest about API call count (1 per symbol, not "batched")  
✅ **Improved:** Concurrent fetching for speed  
✅ **Improved:** Better error handling per symbol  
✅ **Improved:** Clearer logging with `[API]` prefix  

Now run your app and you should see proper behavior! 🎉
