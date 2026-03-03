# Marketstack Integration - Phase 1 (Test Mode)

## 📋 Overview

This is **Phase 1** of the Marketstack integration. We've created a **mock test service** that simulates Marketstack API behavior without making any real API calls. This allows you to:

- ✅ Test the integration without spending API credits
- ✅ Verify the service works with your existing code
- ✅ See how many API calls your app would make
- ✅ Prepare for the real implementation

## 🗂️ Files Created

### 1. `MarketstackTestService.swift`
The mock service that simulates Marketstack API responses.

**Key Features:**
- Returns hardcoded test data for common tickers (AAPL, MSFT, GOOGL, TSLA, SPY, VTI, BTC, ETH)
- Tracks mock API call count so you can see usage patterns
- Simulates realistic network delays (300ms)
- Uses the same interface as `YahooFinanceService` for easy switching
- Includes the actual Marketstack response structure (`MarketstackQuote`)

**Methods:**
```swift
// Single ticker lookup
await MarketstackTestService.shared.fetchQuote(ticker: "AAPL")

// Crypto lookup
await MarketstackTestService.shared.fetchCryptoQuote(symbol: "BTC")

// Batch lookup (efficient for multiple tickers)
await MarketstackTestService.shared.fetchBatchQuotes(tickers: ["AAPL", "MSFT", "GOOGL"])

// Update entire portfolio
await MarketstackTestService.shared.updatePortfolioPrices(portfolio: myPortfolio)

// Monitor usage
await MarketstackTestService.shared.getCallCount()
await MarketstackTestService.shared.resetCallCounter()
```

### 2. `MarketstackTestView.swift`
A debug UI to test the service (similar to your existing `YahooTestView`).

**Features:**
- Test individual ticker lookups
- Shows mock API call counter
- Displays detailed logs
- Visual indication that it's in TEST MODE

## 🧪 How to Test

### Option 1: Using the Test View

1. Add `MarketstackTestView()` to your app's navigation/debug menu
2. Enter a ticker symbol (try AAPL, MSFT, BTC, etc.)
3. Click "Fetch" to see the mock response
4. Watch the API call counter increment

### Option 2: Manual Testing

Replace Yahoo service calls with Marketstack test calls:

```swift
// OLD (Yahoo):
let quote = try await YahooFinanceService.shared.fetchQuote(ticker: "AAPL")

// NEW (Marketstack Test):
let quote = try await MarketstackTestService.shared.fetchQuote(ticker: "AAPL")
```

The interface is identical, so it's a drop-in replacement!

### Option 3: Portfolio Testing

Test updating your entire portfolio:

```swift
let updatedPortfolio = try await MarketstackTestService.shared.updatePortfolioPrices(portfolio: portfolio)
```

This will:
- Process assets in batches of 5
- Show which assets were updated
- Display total mock API calls used

## 📊 Understanding Mock API Calls

The counter helps you estimate real API usage:

- **Single ticker fetch** = 1 API call
- **Batch of 5 tickers** = 1 API call (if real Marketstack supports batching)
- **Portfolio with 10 assets** = ~2 API calls (batched in groups of 5)

**Free Tier Limits:**
- Marketstack Free: 100 requests/month
- Basic: 10,000 requests/month
- Professional: 50,000 requests/month

## 🚀 Next Steps (Phase 2)

Once you've verified everything works with the test service, we'll create the **real** `MarketstackService`:

1. **Add your API key** - Store it securely (not hardcoded)
2. **Implement real HTTP calls** - Using Marketstack's actual endpoints
3. **Add caching** - Minimize API usage with smart caching
4. **Error handling** - Handle rate limits, invalid tickers, etc.
5. **Usage tracking** - Monitor real API usage to stay within limits

### Marketstack API Endpoints (for reference)

```
GET http://api.marketstack.com/v1/eod/latest
  ?access_key=YOUR_API_KEY
  &symbols=AAPL,MSFT,GOOGL
  &limit=1
```

**Free tier uses:** `http://` (not `https://`)  
**Paid tiers use:** `https://`

## 🔄 Migration Strategy

When ready to switch from Yahoo to Marketstack:

### Option A: Service Wrapper (Recommended)
Create a `PriceService` protocol that both services implement:

```swift
protocol PriceService {
    func fetchQuote(ticker: String) async throws -> YFStockQuote
    func fetchCryptoQuote(symbol: String) async throws -> YFCryptoQuote
    func fetchBatchQuotes(tickers: [String]) async throws -> [String: YFStockQuote]
    func updatePortfolioPrices(portfolio: Portfolio) async throws -> Portfolio
}

// Then use a setting to switch:
let service: PriceService = useMarketstack ? 
    MarketstackService.shared : 
    YahooFinanceService.shared
```

### Option B: Gradual Migration
Keep Yahoo as fallback:

```swift
do {
    return try await MarketstackService.shared.fetchQuote(ticker: ticker)
} catch {
    print("⚠️ Marketstack failed, falling back to Yahoo")
    return try await YahooFinanceService.shared.fetchQuote(ticker: ticker)
}
```

## 📝 Notes

- **No API key needed** for Phase 1 (test mode)
- **No real network calls** are made
- **Mock data is realistic** but not live prices
- **API call counter** is for estimation only
- **Safe to test** as much as you want - it's all local!

## ⚠️ Known Limitations (Test Mode)

1. Returns the same prices every time (not live data)
2. Unknown tickers get random prices
3. No historical data support (only latest prices)
4. No real rate limiting or errors

These will all be addressed in Phase 2 with the real service.

## 📞 Questions?

Before building Phase 2, confirm:
- ✅ Mock service returns data correctly
- ✅ Portfolio updates work
- ✅ API call counting makes sense
- ✅ Interface matches your needs

Then we'll build the real implementation! 🚀
