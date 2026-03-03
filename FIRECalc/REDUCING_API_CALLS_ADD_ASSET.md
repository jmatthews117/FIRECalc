# 💰 Reducing API Calls When Adding Assets

## ✅ Good News: It's Already Optimized!

Your `AddAssetView` already uses the **Marketstack cache** automatically!

---

## 🎯 How It Works

### When You Type a Ticker:

1. **You type:** "AAPL"
2. **After 0.8 seconds**, it calls `AlternativePriceService.shared.fetchPrice()`
3. **The service checks cache first:**
   - If AAPL was fetched in last 15 min → **Uses cache, NO API call!** ✅
   - If AAPL not cached → Makes API call ❌

---

## 📊 Real-World Scenarios

### Scenario 1: Adding Assets After Portfolio Refresh

```
1. User refreshes portfolio (all tickers cached)
   📡 API call → Cache: AAPL, MSFT, GOOGL, TSLA, SPY

2. User adds new asset with ticker "AAPL"
   💾 Cache HIT! Shows price, NO API call ✅

3. User adds another asset with ticker "MSFT"
   💾 Cache HIT! Shows price, NO API call ✅
```

**Result:** 0 additional API calls when adding assets! 🎉

### Scenario 2: Adding Asset with New Ticker

```
1. Portfolio has: AAPL, MSFT, GOOGL (cached)

2. User adds new asset with ticker "NVDA"
   ❌ Cache MISS → Makes 1 API call
   
3. User adds another "NVDA" asset within 15 min
   💾 Cache HIT! NO API call ✅
```

**Result:** Only 1 API call for the new ticker

### Scenario 3: Adding Assets Without Recent Refresh

```
1. User opens app (empty cache)

2. User adds asset with ticker "AAPL"
   ❌ Cache MISS → Makes 1 API call
   
3. User adds asset with ticker "MSFT"  
   ❌ Cache MISS → Makes 1 API call
   
4. User adds another "AAPL" within 15 min
   💾 Cache HIT! NO API call ✅
```

**Result:** 1 API call per unique ticker, but cached for 15 minutes

---

## 💡 Strategies to Minimize API Calls

### Strategy 1: Refresh Portfolio First (Recommended!)

**Before adding multiple assets:**
1. Go to portfolio
2. Pull to refresh
3. All existing tickers are now cached
4. Add your assets
5. Most will use cache!

**Example:**
```
Portfolio has: AAPL, MSFT, GOOGL, TSLA, SPY, VTI, QQQ, DIA, BND, GLD

1. Refresh portfolio: 1 API call (batched)
   → All 10 tickers cached for 15 minutes
   
2. Edit any of these 10 assets: 0 API calls! ✅
3. Add new assets using any of these tickers: 0 API calls! ✅
```

### Strategy 2: Disable Auto-Load Price (If Needed)

If you want to completely avoid API calls while adding:

**Option A:** Don't enter a ticker
- Add asset without ticker
- Enter price manually
- Update ticker later
- Next portfolio refresh will fetch the price

**Option B:** Add ticker but ignore price
- Type ticker
- Don't wait for price to load
- Save immediately
- Next portfolio refresh will fetch the price

### Strategy 3: Batch Add Assets

Instead of:
```
Add AAPL → wait for price → save
Add MSFT → wait for price → save
Add GOOGL → wait for price → save
```

Do:
```
Add AAPL → save (don't wait)
Add MSFT → save (don't wait)
Add GOOGL → save (don't wait)
Then: Refresh portfolio once (1 API call for all 3)
```

---

## 🔍 How to Tell if Cache Was Used

### Look at the console when adding an asset:

**Cache Hit (No API call):**
```
🔍 Checking cache for 1 tickers...
💾 Cache HIT for AAPL (age: 45s / 900s)
💾 ✅ All 1 tickers served from cache - NO API CALL!
```

**Cache Miss (API call made):**
```
🔍 Checking cache for 1 tickers...
❌ Cache MISS for NVDA (not in cache)
📡 🔴 Making API call for 1/1 tickers: NVDA
📊 API Calls: 2/100 this month
```

---

## 📊 Estimated API Usage

### Conservative Workflow:
```
Morning:
- Refresh portfolio: 1 API call
- Add 3 assets with existing tickers: 0 API calls (cached)
- Add 1 asset with new ticker: 1 API call

Afternoon:
- Refresh portfolio: 1 API call
- Add 2 assets: 0 API calls (cached)

Total: 3 API calls/day → 90 calls/month ✅ Under free tier!
```

### Heavy Usage:
```
Daily:
- Refresh portfolio 3 times: 1 API call (others use cache)
- Add 5 new unique tickers: 5 API calls

Total: 6 calls/day → 180 calls/month ❌ Need Basic tier
```

---

## 🎯 Best Practices

### ✅ DO:
1. **Refresh portfolio before adding many assets** - Populates cache
2. **Add assets quickly** - Cache lasts 15 minutes
3. **Reuse tickers from your portfolio** - They're already cached
4. **Check console logs** - See cache hits vs misses

### ❌ AVOID:
1. **Adding many unique new tickers** - Each needs an API call
2. **Waiting >15 min between adding assets** - Cache expires
3. **Closing app between adds** - Cache is in-memory only

---

## 💾 Understanding Cache Behavior

### Cache Persistence:
- **Lives:** In app memory only
- **Lasts:** 15 minutes per ticker
- **Cleared:** When you close/restart app
- **Shared:** Same cache for portfolio refresh AND add asset

### This Means:
- Portfolio refresh populates cache
- Adding assets uses that cache
- Both features share the same cache!

---

## 🔧 Optional: Completely Disable Auto-Load

If you want to **never** fetch prices when adding assets:

### Modify AddAssetView:

Find this line in `add_asset_view.swift`:
```swift
if !newValue.isEmpty && newValue.count >= 1 {
    scheduleAutoLoad()
}
```

Change to:
```swift
// Disabled: Auto-load prices (use manual entry or portfolio refresh)
// if !newValue.isEmpty && newValue.count >= 1 {
//     scheduleAutoLoad()
// }
```

**Result:** No price fetching when adding assets. Prices update on next portfolio refresh.

---

## 📝 Summary

**Current Behavior:**
- ✅ AddAssetView uses Marketstack cache automatically
- ✅ If ticker was recently fetched, NO API call
- ✅ Shares cache with portfolio refresh
- ✅ 15-minute cache duration

**To Minimize Calls:**
1. Refresh portfolio before adding assets
2. Add assets within 15 minutes
3. Reuse existing tickers when possible
4. Check console for cache hits

**API Impact:**
- Adding assets with cached tickers: **0 calls** ✅
- Adding assets with new tickers: **1 call each** ⚠️
- Cache expires: After 15 minutes

---

## ✅ You're Already Optimized!

Your setup is already using the cache efficiently. Just **refresh your portfolio before adding multiple assets** and most will use the cache!

The current implementation is the sweet spot between:
- **User experience** (shows prices immediately)
- **API efficiency** (uses cache when available)

No changes needed! 🎉
