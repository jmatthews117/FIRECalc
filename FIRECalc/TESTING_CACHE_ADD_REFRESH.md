# 🧪 Testing: Cache Between Add Asset and Portfolio Refresh

## 🎯 Expected Behavior

When you add an asset with a ticker and load its price, then refresh the portfolio, **it should use the cache**.

---

## ✅ How It Should Work

### Flow:
```
1. Add Asset → Type "AAPL" → Click "Load Price"
   📡 API call → Caches "AAPL" at 14:30:00
   
2. Save asset

3. Refresh Portfolio (within 15 minutes)
   🔍 Checking cache for AAPL...
   💾 Cache HIT for AAPL (age: 30s / 900s)
   💾 ✅ All X tickers served from cache - NO API CALL!
```

**Result:** Only 1 API call total! ✅

---

## 🧪 Test Scenario

### Step 1: Add an asset
1. Go to Add Asset
2. Type ticker: **"NVDA"** (use a ticker NOT in your portfolio)
3. Click **"Load Price for NVDA"**
4. Watch console:
   ```
   🔍 fetchQuote called for: 'NVDA' → cleaned: 'NVDA'
   ❌ Cache MISS for NVDA in fetchQuote (not in cache)
   📡 API call for NVDA in fetchQuote
   💾 Caching NVDA at 2026-03-02 14:30:00 in fetchQuote
   📊 API Calls: 1/100 this month
   ```
5. Enter quantity and save

### Step 2: Immediately refresh portfolio
1. Go to portfolio
2. Pull to refresh
3. Watch console:
   ```
   🔍 Checking cache for 6 tickers...
   💾 Cache HIT for AAPL (age: 45s / 900s)
   💾 Cache HIT for MSFT (age: 45s / 900s)
   💾 Cache HIT for NVDA (age: 15s / 900s)  ← From add asset!
   ...
   💾 ✅ All 6 tickers served from cache - NO API CALL!
   📊 API Calls: 1/100 this month  ← SAME COUNT!
   ```

**Expected:** Cache HIT for NVDA, no API call increase! ✅

---

## 🔍 What to Look For

### In Console (Add Asset):
```
🔍 fetchQuote called for: 'TICKER' → cleaned: 'TICKER'
❌ Cache MISS for TICKER in fetchQuote
📡 API call for TICKER in fetchQuote
💾 Caching TICKER at [timestamp] in fetchQuote
```

### In Console (Portfolio Refresh):
```
🔍 Checking cache for X tickers...
💾 Cache HIT for TICKER (age: XXs / 900s)  ← Should see your new ticker!
💾 ✅ All X tickers served from cache - NO API CALL!
```

### API Counter:
- After add asset: Shows **N calls**
- After portfolio refresh: Shows **N calls** (same number!) ✅

---

## ❌ If Cache ISN'T Working

### You'd See This:
```
// After add asset:
📊 API Calls: 1/100 this month

// After portfolio refresh:
❌ Cache MISS for TICKER (not in cache)  ← WRONG!
📡 🔴 Making API call for 1/X tickers: TICKER
📊 API Calls: 2/100 this month  ← Increased! WRONG!
```

### Possible Causes:
1. **Different ticker capitalization** - Fixed (we uppercase all tickers)
2. **Cache cleared** - Happens if you restart app
3. **>15 min passed** - Cache expired
4. **Different service instances** - We use `.shared` singleton
5. **Cache not being stored** - Bug in caching logic

---

## 🐛 Debugging

### Enhanced Logging Added:

I've added detailed logging to show:
- What ticker is being requested
- Whether it's in cache or not
- Age of cached items
- When items are cached

### Check These Logs:

**When adding asset:**
```
🔍 fetchQuote called for: 'AAPL' → cleaned: 'AAPL'
```
→ Shows the exact ticker and how it's cleaned

**When checking cache:**
```
💾 Cache HIT for AAPL (age: 45s / 900s)
```
→ Shows age and expiration time

**When caching:**
```
💾 Caching AAPL at 2026-03-02 14:30:00 in fetchQuote
```
→ Shows exactly when item was cached and where

---

## 🎯 Test Results

### Test 1: Single New Asset
```
Action: Add NVDA → Load Price → Save → Refresh Portfolio
Expected: 1 API call total
Your Result: _____ API calls
Status: ☐ PASS ☐ FAIL
```

### Test 2: Multiple New Assets
```
Action: 
  Add NVDA → Load Price → Save
  Add AMD → Load Price → Save
  Add INTC → Load Price → Save
  Refresh Portfolio
Expected: 3 API calls (one per new ticker)
Your Result: _____ API calls  
Status: ☐ PASS ☐ FAIL
```

### Test 3: Existing Tickers
```
Action:
  Refresh Portfolio (caches all existing tickers)
  Add asset with existing ticker (e.g., AAPL)
  Click Load Price
Expected: Price loads from cache, 0 new API calls
Your Result: _____ API calls
Status: ☐ PASS ☐ FAIL
```

---

## 💡 Cache Sharing Verification

The cache is **shared** between:
- `fetchQuote()` - Used by AddAssetView
- `fetchBatchQuotes()` - Used by Portfolio refresh

Both access the same `quoteCache` dictionary, so they **should** share cached data.

### Code Verification:
```swift
// Same cache for both methods:
actor MarketstackService {
    private var quoteCache: [String: CachedQuote] = [:]  ← Shared!
    
    func fetchQuote(ticker: String) {
        // Checks quoteCache
        // Stores in quoteCache
    }
    
    func fetchBatchQuotes(tickers: [String]) {
        // Checks quoteCache
        // Stores in quoteCache
    }
}
```

---

## 📝 What Could Go Wrong?

### Issue 1: Cache Key Mismatch
**Problem:** Ticker stored as "AAPL", looked up as "aapl"  
**Status:** ✅ Fixed - All tickers uppercased

### Issue 2: Cache Not Persisting
**Problem:** Cache stored in one place, checked in another  
**Status:** ✅ Fixed - Same `quoteCache` dictionary

### Issue 3: Actor Isolation
**Problem:** Multiple instances of service  
**Status:** ✅ Fixed - Using singleton `.shared`

### Issue 4: Cache Expiration
**Problem:** 15 min passed between add and refresh  
**Status:** Check timestamps in logs

---

## 🧪 Manual Verification

### Print Cache Contents:

If you want to see what's actually in the cache, you could add this debug method:

```swift
// In MarketstackService.swift
func debugPrintCache() {
    print("📦 Cache Contents:")
    for (ticker, cached) in quoteCache {
        let age = Date().timeIntervalSince(cached.timestamp)
        let expired = cached.isExpired(cacheDuration: cacheDuration)
        print("  \(ticker): age=\(Int(age))s, expired=\(expired)")
    }
}
```

Then call it:
```swift
await MarketstackService.shared.debugPrintCache()
```

---

## ✅ Expected Test Results

If caching is working correctly:

### Test: Add NVDA, then refresh portfolio
```
1. Add asset "NVDA" → Load Price
   Console: "📡 API call for NVDA in fetchQuote"
   Console: "💾 Caching NVDA at [timestamp]"
   Counter: 1/100 calls

2. Save asset

3. Refresh portfolio (immediately)
   Console: "💾 Cache HIT for NVDA (age: 10s / 900s)"
   Console: "💾 ✅ All X tickers served from cache"
   Counter: 1/100 calls (NO CHANGE!) ✅
```

---

## 🚀 Try It Now!

1. **Add a new asset** with a ticker not in your portfolio
2. **Click "Load Price"**
3. **Note the API count** in console
4. **Save the asset**
5. **Immediately refresh portfolio**
6. **Check console logs** - should show cache hit
7. **Verify API count** - should be the same!

**Let me know what you see!** Copy the console logs if cache isn't working as expected.
