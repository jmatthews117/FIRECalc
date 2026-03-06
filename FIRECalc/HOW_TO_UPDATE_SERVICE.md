# 🔧 How to Update MarketstackService for Backend Proxy

## The Problem

Your `MarketstackService.swift` currently makes direct API calls to Marketstack, which requires:
1. An API key in the app (security risk)
2. HTTP access (App Transport Security issue)

We need to update it to use your backend proxy instead.

## The Solution: Two Simple Changes

### Change 1: Update `fetchQuoteFromAPI()` method

**Find this method** (around line 376-450):

```swift
private func fetchQuoteFromAPI(ticker: String) async throws -> MarketstackQuote {
    // Marketstack endpoint: /eod/latest?symbols=AAPL
    let endpoint = "\(baseURL)/eod/latest"
    
    let apiKey = await getAPIKey()
    
    // ... lots of URL building code ...
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    // ... lots of response parsing code ...
    
    return quote
}
```

**Replace it with this:**

```swift
private func fetchQuoteFromAPI(ticker: String) async throws -> MarketstackQuote {
    // Call our backend proxy instead of Marketstack directly
    // This keeps the API key secure on the server
    do {
        let quote = try await MarketstackConfig.shared.fetchQuote(symbol: ticker)
        print("✅ Received quote from backend for \(ticker): $\(quote.close)")
        return quote
    } catch let error as ConfigError {
        // Map backend errors to Marketstack errors
        print("❌ Backend error for \(ticker): \(error.localizedDescription)")
        throw MarketstackError.networkError(error)
    }
}
```

### Change 2: Update `fetchBatchQuotesFromAPI()` method

**Find this method** (around line 451-530):

```swift
private func fetchBatchQuotesFromAPI(tickers: [String]) async throws -> [MarketstackQuote] {
    // Marketstack supports multiple symbols: /eod/latest?symbols=AAPL,MSFT,GOOGL
    let endpoint = "\(baseURL)/eod/latest"
    let symbolsString = tickers.joined(separator: ",")
    
    let apiKey = await getAPIKey()
    
    // ... lots of code ...
    
    return apiResponse.data
}
```

**Replace it with this:**

```swift
private func fetchBatchQuotesFromAPI(tickers: [String]) async throws -> [MarketstackQuote] {
    // Call our backend proxy for batch quotes
    do {
        let quotes = try await MarketstackConfig.shared.fetchQuotes(symbols: tickers)
        print("✅ Received \(quotes.count) quotes from backend")
        return quotes
    } catch let error as ConfigError {
        // Map backend errors to Marketstack errors
        print("❌ Backend error for batch: \(error.localizedDescription)")
        throw MarketstackError.networkError(error)
    }
}
```

## That's It!

Those are the ONLY two changes needed in `MarketstackService.swift`.

Everything else (caching, cooldown management, etc.) stays exactly the same because those methods call `fetchQuoteFromAPI()` and `fetchBatchQuotesFromAPI()`.

## Why This Works

**Before:**
```
MarketstackService → Builds URL with API key → Marketstack API
```

**After:**
```
MarketstackService → MarketstackConfig → Your Backend → Marketstack API
```

The service doesn't need to know about API keys or URLs anymore. It just asks `MarketstackConfig` for data!

## Testing After Changes

1. Build your app (Command+B)
2. Run it
3. Try refreshing your portfolio
4. Check the Xcode console for these logs:
   - `🔐 MarketstackConfig initialized - using secure backend proxy`
   - `✅ Received quote from backend for AAPL: $150.25`

## Troubleshooting

**If you see: "Invalid backend URL"**
- You haven't deployed your backend yet
- Or you haven't updated the `backendURL` in `MarketstackConfig.swift`

**For now, while testing locally:**
Update `MarketstackConfig.swift` line 18 to:
```swift
private let backendURL = "http://localhost:3000"
```

Then run your Node.js backend:
```bash
cd firecalc-backend
npm start
```

Now your iOS app will talk to your local backend!

## Next Steps

1. ✅ Make these two changes
2. ✅ Test with local backend (`http://localhost:3000`)
3. ✅ Deploy backend to Render.com
4. ✅ Update `backendURL` to your Render URL
5. ✅ Ship to App Store! 🎉
