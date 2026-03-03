# Phase 1 Testing Checklist

## ✅ Pre-Testing Setup

Before you start testing, make sure:

- [ ] All new files are added to your Xcode project:
  - `MarketstackTestService.swift`
  - `MarketstackTestView.swift`
  - `MARKETSTACK_PHASE1_README.md`
  - `YAHOO_VS_MARKETSTACK.md`
  - `EXAMPLE_INTEGRATION.swift`
  - `PHASE1_TESTING_CHECKLIST.md` (this file)

- [ ] Project builds successfully with no errors
- [ ] You've read the README to understand what Phase 1 does

## 🧪 Basic Functionality Tests

### Test 1: Launch MarketstackTestView
- [ ] Add `MarketstackTestView()` to your app navigation
- [ ] View displays correctly with "TEST MODE" indicator
- [ ] API call counter shows 0 initially

### Test 2: Single Ticker Fetch
- [ ] Enter "AAPL" in the ticker field
- [ ] Click "Fetch" button
- [ ] Price displays: ~$181.25 (mock data)
- [ ] Console log shows:
  - "🧪 [TEST] API Call #1"
  - "✅ Mock response: $181.25"
  - Symbol, change, and volume info
- [ ] API call counter increments to 1

### Test 3: Multiple Different Tickers
Test these tickers one by one:
- [ ] "MSFT" → Returns ~$418.75
- [ ] "GOOGL" → Returns ~$144.25
- [ ] "TSLA" → Returns ~$250.10
- [ ] "SPY" → Returns ~$507.35
- [ ] API counter increments correctly for each

### Test 4: Crypto Tickers
- [ ] Enter "BTC" → Returns ~$68,500
- [ ] Enter "ETH" → Returns ~$3,475
- [ ] Console shows crypto-specific handling
- [ ] API counter increments

### Test 5: Unknown Ticker
- [ ] Enter "FAKE123"
- [ ] Still returns a price (random mock data)
- [ ] No error occurs
- [ ] API counter increments
- [ ] Console shows it's generating fallback data

### Test 6: Reset Counter
- [ ] After several fetches, note the counter value
- [ ] Click "Reset Counter" button
- [ ] Counter resets to 0
- [ ] Console shows "🔄 Mock API call counter reset"

### Test 7: Loading State
- [ ] Click fetch and watch for:
  - Button becomes disabled
  - "Fetching..." progress indicator appears
  - ~300ms delay (simulated network)
  - Results appear after delay

## 📊 Advanced Integration Tests

### Test 8: Direct Service Call (in code)
Add this code somewhere temporary and run it:

```swift
Task {
    let service = MarketstackTestService.shared
    let quote = try await service.fetchQuote(ticker: "AAPL")
    print("Test passed: \(quote.symbol) = $\(quote.latestPrice)")
}
```

- [ ] Code compiles
- [ ] Console shows mock data
- [ ] No crashes

### Test 9: Batch Fetching
Add this test code:

```swift
Task {
    let service = MarketstackTestService.shared
    let quotes = try await service.fetchBatchQuotes(tickers: ["AAPL", "MSFT", "GOOGL"])
    print("Batch fetch returned \(quotes.count) quotes")
    for (ticker, quote) in quotes {
        print("  \(ticker): $\(quote.latestPrice)")
    }
    let count = await service.getCallCount()
    print("API calls used: \(count)")
}
```

- [ ] Returns all 3 quotes
- [ ] Uses only 1 API call (efficient batching)
- [ ] All prices are reasonable mock values

### Test 10: Portfolio Update (if you have Portfolio in your app)
If your app has a Portfolio with assets:

```swift
Task {
    let service = MarketstackTestService.shared
    let updated = try await service.updatePortfolioPrices(portfolio: yourPortfolio)
    print("Updated \(updated.assets.count) assets")
    let count = await service.getCallCount()
    print("Total API calls: \(count)")
}
```

- [ ] Portfolio updates complete
- [ ] No crashes
- [ ] Assets show new mock prices
- [ ] API call count reflects batch processing

### Test 11: Crypto in Portfolio
If you have crypto assets:

- [ ] Crypto assets update successfully
- [ ] Prices are in reasonable range
- [ ] No errors about missing -USD suffix

## 🔍 Verification Tests

### Test 12: Data Structure Compatibility
Verify the mock service returns the same structure as Yahoo:

```swift
Task {
    let marketstack = try await MarketstackTestService.shared.fetchQuote(ticker: "AAPL")
    let yahoo = try await YahooFinanceService.shared.fetchQuote(ticker: "AAPL")
    
    print("Marketstack type: \(type(of: marketstack))")
    print("Yahoo type: \(type(of: yahoo))")
    // Both should be YFStockQuote
}
```

- [ ] Both return `YFStockQuote` type
- [ ] Same properties available
- [ ] Can use interchangeably

### Test 13: Error Handling
Test that errors don't crash:

```swift
Task {
    do {
        // This should work even with "bad" input
        let quote = try await MarketstackTestService.shared.fetchQuote(ticker: "")
        print("Handled empty ticker: \(quote.symbol)")
    } catch {
        print("Error caught properly: \(error)")
    }
}
```

- [ ] No crashes
- [ ] Error handling works

### Test 14: Concurrent Calls
Test multiple simultaneous calls:

```swift
Task {
    let service = MarketstackTestService.shared
    
    async let apple = service.fetchQuote(ticker: "AAPL")
    async let microsoft = service.fetchQuote(ticker: "MSFT")
    async let google = service.fetchQuote(ticker: "GOOGL")
    
    let results = try await [apple, microsoft, google]
    print("Concurrent fetch got \(results.count) quotes")
}
```

- [ ] All calls complete successfully
- [ ] No race conditions
- [ ] API counter increments by 3

## 📱 UI Integration Tests

### Test 15: View Integration
If you integrate the service into your main UI:

- [ ] Portfolio view displays correctly
- [ ] Refresh button works
- [ ] Loading indicators appear
- [ ] Prices update in the UI
- [ ] No visual glitches

### Test 16: Settings Integration (if you add settings)
If you add a settings screen:

- [ ] Can toggle between Yahoo and Marketstack
- [ ] Selection persists across app launches
- [ ] API counter displays correctly
- [ ] Reset counter button works

## 🎯 Performance Tests

### Test 17: Memory Usage
- [ ] Open Activity Monitor / Instruments
- [ ] Perform 50-100 API calls
- [ ] Memory doesn't grow unbounded
- [ ] No leaks detected

### Test 18: Response Time
- [ ] Note response times for single fetch (~300ms expected)
- [ ] Batch fetches should be similar (~300ms regardless of size)
- [ ] No unexplained delays

### Test 19: App Responsiveness
- [ ] UI stays responsive during fetches
- [ ] Can cancel operations if needed
- [ ] No UI freezes

## 📝 Usage Pattern Analysis

### Test 20: Estimate Your Real Usage
Based on your testing, calculate:

- [ ] How many assets in your portfolio? ___________
- [ ] Batch size used: ___________ (default is 5)
- [ ] API calls per portfolio update: ___________
- [ ] How often do users refresh? ___________ times/day
- [ ] Estimated monthly calls: ___________ 

**Calculation:**
```
Monthly calls = (Portfolio assets ÷ Batch size) × Refreshes per day × 30 days

Example: (20 assets ÷ 5) × 3 refreshes × 30 days = 360 calls/month
```

- [ ] Free tier sufficient? (100 calls/month) ☐ Yes ☐ No
- [ ] Need Basic plan? (10,000 calls/month) ☐ Yes ☐ No

## ✨ Code Quality Checks

### Test 21: Code Review
- [ ] No hardcoded API keys visible
- [ ] Proper error handling in place
- [ ] Actor isolation correct (MarketstackTestService is an actor)
- [ ] No force unwraps or force casts
- [ ] Console logs are appropriate

### Test 22: Documentation
- [ ] README is clear and helpful
- [ ] Code comments explain mock behavior
- [ ] Example integration is understandable

## 🚀 Ready for Phase 2?

Before moving to Phase 2 (real Marketstack implementation), verify:

- [ ] All tests above pass ✅
- [ ] You understand API usage patterns
- [ ] You've decided on Marketstack tier:
  - ☐ Free (100 req/month)
  - ☐ Basic ($9/mo, 10K req/month)
  - ☐ Professional ($49/mo, 50K req/month)
- [ ] You have (or will get) a Marketstack API key
- [ ] You've decided on caching strategy:
  - ☐ No caching (fresh data always)
  - ☐ 15-minute cache
  - ☐ Session-only cache
  - ☐ EOD data (cache until next market day)
- [ ] You've decided on fallback strategy:
  - ☐ Marketstack only (no fallback)
  - ☐ Fall back to Yahoo on rate limit
  - ☐ User-selectable service

## 📞 Phase 2 Planning

When you're ready for Phase 2, you'll need to provide:

1. **API Key:** Your Marketstack API key
2. **Tier:** Free vs Paid (affects HTTP vs HTTPS)
3. **Caching:** How long to cache prices
4. **Fallback:** Whether to keep Yahoo as backup
5. **Features:** Any additional endpoints needed

## 🎉 Completion

Once all tests pass:
- [ ] Document any issues found
- [ ] Note any questions for Phase 2
- [ ] Mark Phase 1 as complete ✅

---

## 📊 Test Results Summary

**Date Tested:** _______________

**Tests Passed:** _____ / 22

**Issues Found:**
- 
- 
- 

**Notes:**
- 
- 
- 

**Ready for Phase 2?** ☐ Yes ☐ No (explain: _______________)

---

Good luck with testing! 🚀
