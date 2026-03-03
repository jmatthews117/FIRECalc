# Service Comparison: Yahoo Finance vs Marketstack

## 🔍 Quick Comparison

| Feature | Yahoo Finance | Marketstack (Free) | Marketstack (Paid) |
|---------|--------------|-------------------|-------------------|
| **Cost** | Free | Free | $9-$79/mo |
| **API Key** | Not required | Required | Required |
| **Protocol** | HTTPS | HTTP only | HTTPS |
| **Rate Limit** | Unofficial/unlimited | 100 req/month | 10K-50K req/month |
| **Real-time** | Yes (delayed) | No (EOD only) | Yes (with higher tiers) |
| **Crypto** | Yes | Limited | Limited |
| **Reliability** | Unofficial API | Official API | Official API |
| **Historical Data** | Yes | Yes | Yes |

## 📊 Key Differences

### Yahoo Finance
**Pros:**
- ✅ Free and unlimited
- ✅ No API key needed
- ✅ Good crypto coverage
- ✅ Intraday data available

**Cons:**
- ❌ Unofficial API (could break)
- ❌ No support/SLA
- ❌ Rate limiting may be added

### Marketstack
**Pros:**
- ✅ Official, supported API
- ✅ Reliable with SLA
- ✅ Good for stocks/ETFs
- ✅ Historical data available

**Cons:**
- ❌ Limited free tier (100 req/month)
- ❌ Free tier is HTTP only
- ❌ Limited crypto support
- ❌ EOD data only on lower tiers

## 🔄 Code Comparison

Both services use the same interface for easy switching:

```swift
// Yahoo Finance
let quote = try await YahooFinanceService.shared.fetchQuote(ticker: "AAPL")
// Returns: YFStockQuote

// Marketstack Test Service (Phase 1)
let quote = try await MarketstackTestService.shared.fetchQuote(ticker: "AAPL")
// Returns: YFStockQuote (same model!)

// Marketstack Real Service (Phase 2)
let quote = try await MarketstackService.shared.fetchQuote(ticker: "AAPL")
// Returns: YFStockQuote (same model!)
```

## 💡 Recommended Strategy

### Phase 1: Testing (Current)
```swift
// Use test service to verify integration
let service = MarketstackTestService.shared
let quote = try await service.fetchQuote(ticker: "AAPL")
```

### Phase 2: Dual Service with Fallback
```swift
// Try Marketstack first, fall back to Yahoo if needed
func fetchQuote(ticker: String) async throws -> YFStockQuote {
    do {
        // Try Marketstack
        return try await MarketstackService.shared.fetchQuote(ticker: ticker)
    } catch MarketstackError.rateLimitExceeded, MarketstackError.planLimitReached {
        // Fall back to Yahoo if we hit limits
        print("⚠️ Marketstack limit reached, using Yahoo fallback")
        return try await YahooFinanceService.shared.fetchQuote(ticker: ticker)
    } catch {
        // For other errors, still try Yahoo
        print("⚠️ Marketstack error: \(error), trying Yahoo")
        return try await YahooFinanceService.shared.fetchQuote(ticker: ticker)
    }
}
```

### Phase 3: Full Migration (When on paid plan)
```swift
// Use Marketstack exclusively
let service = MarketstackService.shared
let quote = try await service.fetchQuote(ticker: ticker)
```

## 📉 API Usage Optimization

To minimize Marketstack API calls:

### 1. Use Batch Fetching
```swift
// ❌ BAD: 3 API calls
let appleQuote = try await service.fetchQuote(ticker: "AAPL")
let msftQuote = try await service.fetchQuote(ticker: "MSFT")
let googlQuote = try await service.fetchQuote(ticker: "GOOGL")

// ✅ GOOD: 1 API call
let quotes = try await service.fetchBatchQuotes(tickers: ["AAPL", "MSFT", "GOOGL"])
```

### 2. Implement Caching
```swift
// Cache prices for 15 minutes (or longer for EOD data)
struct CachedQuote {
    let quote: YFStockQuote
    let timestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 900  // 15 minutes
    }
}

actor QuoteCache {
    private var cache: [String: CachedQuote] = [:]
    
    func get(ticker: String) -> YFStockQuote? {
        guard let cached = cache[ticker], !cached.isExpired else {
            return nil
        }
        return cached.quote
    }
    
    func set(ticker: String, quote: YFStockQuote) {
        cache[ticker] = CachedQuote(quote: quote, timestamp: Date())
    }
}
```

### 3. Update Only What's Needed
```swift
// Only update assets that have tickers
let assetsNeedingUpdate = portfolio.assets.filter { $0.ticker != nil }

// Skip updates during off-market hours (if using EOD data)
let calendar = Calendar.current
let hour = calendar.component(.hour, from: Date())
let isMarketHours = (9...16).contains(hour)  // Rough estimate
```

### 4. Reduce Update Frequency
```swift
// Instead of updating every time the view appears:
// - Update on app launch
// - Update on manual refresh only
// - Cache for the entire session if using EOD data
```

## 🎯 Estimated API Usage

Based on your app's needs:

### Scenario 1: Portfolio with 10 assets
- **Without batching:** 10 calls/update
- **With batching (groups of 5):** 2 calls/update
- **Updates per day:** Depends on frequency

**Free tier budget:**
- 100 calls/month ÷ 2 calls/update = **50 updates/month**
- ~1-2 updates per day

### Scenario 2: Portfolio with 20 assets
- **With batching:** 4 calls/update
- **Free tier:** 100 ÷ 4 = **25 updates/month**

### Recommendation:
If you have >5 assets and want daily updates, consider the **Basic plan** ($9/mo, 10,000 requests).

## 🔐 Security Notes

### Storing API Keys
```swift
// ❌ DON'T: Hardcode in source
let apiKey = "your-api-key-here"

// ✅ DO: Use a secure configuration
// Option 1: Environment variable (for development)
let apiKey = ProcessInfo.processInfo.environment["MARKETSTACK_API_KEY"]

// Option 2: Configuration file (not in git)
// Create a Config.swift that's in .gitignore

// Option 3: User preference (for user-provided keys)
@AppStorage("marketstackAPIKey") private var apiKey: String = ""
```

## 📱 UI Considerations

Add settings to let users:
1. Choose between Yahoo and Marketstack
2. Enter their own Marketstack API key
3. See their API usage statistics
4. Configure cache duration
5. Toggle automatic updates

Example settings screen:
```swift
struct PriceServiceSettings: View {
    @AppStorage("priceService") private var service = "yahoo"
    @AppStorage("marketstackAPIKey") private var apiKey = ""
    @AppStorage("cacheMinutes") private var cacheMinutes = 15
    
    var body: some View {
        Form {
            Section("Price Data Source") {
                Picker("Service", selection: $service) {
                    Text("Yahoo Finance (Free)").tag("yahoo")
                    Text("Marketstack (Requires API Key)").tag("marketstack")
                }
            }
            
            if service == "marketstack" {
                Section("Marketstack Configuration") {
                    SecureField("API Key", text: $apiKey)
                    Stepper("Cache: \(cacheMinutes) minutes", 
                           value: $cacheMinutes, 
                           in: 5...120, 
                           step: 5)
                }
            }
            
            Section("Usage") {
                // Show API call statistics
                Text("Calls this month: 47/100")
            }
        }
    }
}
```

## ✅ Testing Checklist

Before switching from test to production:

- [ ] Verified mock service returns correct data structure
- [ ] Portfolio updates work with test service
- [ ] API call counter accurately reflects usage
- [ ] Determined optimal batch size for your use case
- [ ] Calculated expected monthly API usage
- [ ] Decided on Marketstack tier (free vs paid)
- [ ] Implemented caching strategy
- [ ] Added error handling for rate limits
- [ ] Set up fallback to Yahoo if needed
- [ ] Tested with real API key in Phase 2
- [ ] Verified costs are acceptable

## 🚀 Next: Phase 2

Ready to implement the real Marketstack service? We'll need:
1. Your Marketstack API key (sign up at marketstack.com)
2. Confirmation on which tier (free or paid)
3. Decision on caching strategy
4. Whether to keep Yahoo as fallback

Let me know when you're ready! 🎉
