//
//  MarketstackService.swift
//  FIRECalc
//
//  PHASE 2: Real Marketstack API integration
//  Uses actual API calls with 15-minute caching to minimize usage on free tier
//

import Foundation

// MARK: - Marketstack Service

actor MarketstackService {
    static let shared = MarketstackService()
    
    // MARK: - Configuration
    
    /// Marketstack API key - fetched from remote config
    /// This allows rotating the key without app updates
    private var apiKey: String?
    
    /// Get API key (fetches from remote config on first use)
    private func getAPIKey() async -> String {
        if let key = apiKey {
            return key
        }
        
        // Fetch from remote config
        let key = await MarketstackConfig.shared.getAPIKey()
        apiKey = key
        return key
    }
    
    /// Base URL for Marketstack API
    /// NOTE: Free tier uses HTTP which requires Info.plist configuration
    /// If you get ATS errors, see FIX_ATS_ISSUE.md for Info.plist setup
    /// Alternative: Use test mode or upgrade to paid tier for HTTPS
    private let baseURL = "http://api.marketstack.com/v1"  // Free tier (HTTP)
    // private let baseURL = "https://api.marketstack.com/v1"  // Paid tier (HTTPS - works without ATS config)
    
    /// Cache duration in seconds (15 minutes = 900 seconds)
    private let cacheDuration: TimeInterval = 900
    
    /// API usage tracking
    private(set) var apiCallCount: Int = 0
    private var callHistory: [Date] = []
    
    /// Cache for quotes
    private var quoteCache: [String: CachedQuote] = [:]
    
    private init() {
        print("📡 MarketstackService initialized (LIVE MODE)")
        print("⚠️ Free tier: 100 calls/month - Caching enabled (15 min)")
    }
    
    // MARK: - Cache Model
    
    private struct CachedQuote {
        let quote: MarketstackQuote
        let timestamp: Date
        
        func isExpired(cacheDuration: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) > cacheDuration
        }
    }
    
    // MARK: - Public API
    
    /// Fetch current price for a single ticker
    func fetchQuote(ticker: String) async throws -> YFStockQuote {
        let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        
        print("🔍 fetchQuote called for: '\(ticker)' → cleaned: '\(cleanTicker)'")
        
        // Validate ticker format
        if cleanTicker.isEmpty {
            throw MarketstackError.invalidTicker(ticker)
        }
        
        // Check cache first
        if let cached = quoteCache[cleanTicker] {
            let age = Date().timeIntervalSince(cached.timestamp)
            let expired = cached.isExpired(cacheDuration: cacheDuration)
            
            if !expired {
                print("💾 Cache HIT for \(cleanTicker) in fetchQuote (age: \(Int(age))s)")
                return cached.quote.toStockQuote()
            } else {
                print("⏰ Cache EXPIRED for \(cleanTicker) in fetchQuote (age: \(Int(age))s)")
            }
        } else {
            print("❌ Cache MISS for \(cleanTicker) in fetchQuote (not in cache)")
        }
        
        // Cache miss - fetch from API
        print("📡 API call for \(cleanTicker) in fetchQuote")
        
        do {
            let quote = try await fetchQuoteFromAPI(ticker: cleanTicker)
            
            // Cache the result
            print("💾 Caching \(cleanTicker) at \(Date()) in fetchQuote")
            quoteCache[cleanTicker] = CachedQuote(quote: quote, timestamp: Date())
            
            // Track API usage
            trackAPICall()
            
            return quote.toStockQuote()
        } catch let error as MarketstackError {
            print("❌ Marketstack error for \(cleanTicker): \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ Unknown error for \(cleanTicker): \(error.localizedDescription)")
            throw MarketstackError.networkError(error)
        }
    }
    
    /// Fetch crypto quote
    func fetchCryptoQuote(symbol: String) async throws -> YFCryptoQuote {
        let cleanSymbol = symbol.uppercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "-USD", with: "")
        
        // Marketstack has limited crypto support - try as regular ticker
        // Note: Free tier may not support crypto at all
        let quote = try await fetchQuote(ticker: cleanSymbol)
        
        return YFCryptoQuote(
            symbol: cleanSymbol,
            latestPrice: quote.latestPrice,
            lastUpdate: Date()
        )
    }
    
    /// Fetch quotes for multiple tickers in batch (HIGHLY RECOMMENDED for free tier)
    /// This uses only 1 API call instead of N calls
    /// Handles partial failures gracefully - returns what it can fetch
    func fetchBatchQuotes(tickers: [String]) async throws -> [String: YFStockQuote] {
        guard !tickers.isEmpty else { return [:] }
        
        let cleanTickers = tickers.map { $0.uppercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !cleanTickers.isEmpty else { return [:] }
        
        print("🔍 Checking cache for \(cleanTickers.count) tickers...")
        
        // Check which tickers are cached
        var results: [String: YFStockQuote] = [:]
        var tickersToFetch: [String] = []
        
        for ticker in cleanTickers {
            if let cached = quoteCache[ticker] {
                let age = Date().timeIntervalSince(cached.timestamp)
                let expired = cached.isExpired(cacheDuration: cacheDuration)
                
                if !expired {
                    print("💾 Cache HIT for \(ticker) (age: \(Int(age))s / \(Int(cacheDuration))s)")
                    results[ticker] = cached.quote.toStockQuote()
                } else {
                    print("⏰ Cache EXPIRED for \(ticker) (age: \(Int(age))s > \(Int(cacheDuration))s)")
                    tickersToFetch.append(ticker)
                }
            } else {
                print("❌ Cache MISS for \(ticker) (not in cache)")
                tickersToFetch.append(ticker)
            }
        }
        
        // If all were cached, return immediately
        guard !tickersToFetch.isEmpty else {
            print("💾 ✅ All \(cleanTickers.count) tickers served from cache - NO API CALL!")
            return results
        }
        
        // Fetch uncached tickers from API (1 API call for all)
        print("📡 🔴 Making API call for \(tickersToFetch.count)/\(cleanTickers.count) tickers: \(tickersToFetch.joined(separator: ", "))")
        
        do {
            let quotes = try await fetchBatchQuotesFromAPI(tickers: tickersToFetch)
            
            // Cache all results
            for quote in quotes {
                print("💾 Caching \(quote.symbol) at \(Date())")
                quoteCache[quote.symbol] = CachedQuote(quote: quote, timestamp: Date())
                results[quote.symbol] = quote.toStockQuote()
            }
            
            // Track API usage (1 call for batch)
            trackAPICall()
            
            // Check for missing tickers
            let fetchedSymbols = Set(quotes.map { $0.symbol })
            let requestedSymbols = Set(tickersToFetch)
            let missingSymbols = requestedSymbols.subtracting(fetchedSymbols)
            
            if !missingSymbols.isEmpty {
                print("⚠️ Some tickers not found: \(missingSymbols.joined(separator: ", "))")
            }
            
            return results
            
        } catch let error as MarketstackError {
            print("❌ Marketstack batch error: \(error.localizedDescription)")
            
            // If batch fails, still return cached results
            if !results.isEmpty {
                print("💾 Returning \(results.count) cached results despite batch error")
                return results
            }
            
            throw error
        } catch {
            print("❌ Unknown batch error: \(error.localizedDescription)")
            
            // If batch fails, still return cached results
            if !results.isEmpty {
                print("💾 Returning \(results.count) cached results despite error")
                return results
            }
            
            throw MarketstackError.networkError(error)
        }
    }
    
    /// Update all assets in a portfolio (uses efficient batching)
    func updatePortfolioPrices(portfolio: Portfolio) async throws -> Portfolio {
        var updatedPortfolio = portfolio
        let assetsWithTickers = portfolio.assetsWithTickers
        
        guard !assetsWithTickers.isEmpty else {
            return portfolio
        }
        
        print("📡 Updating \(assetsWithTickers.count) assets...")
        
        // Extract all tickers
        let tickers = assetsWithTickers.compactMap { $0.ticker }
        
        // Fetch all quotes in one batch (minimizes API calls)
        let quotes = try await fetchBatchQuotes(tickers: tickers)
        
        // Update each asset with its quote
        var successCount = 0
        var failCount = 0
        
        for asset in assetsWithTickers {
            guard let ticker = asset.ticker else { continue }
            
            if let quote = quotes[ticker.uppercased()] {
                let updatedAsset = asset.updatedWithLivePrice(
                    quote.latestPrice,
                    change: quote.changePercent
                )
                updatedPortfolio.updateAsset(updatedAsset)
                successCount += 1
            } else {
                failCount += 1
            }
        }
        
        print("✅ Updated \(successCount) assets, \(failCount) failed")
        
        return updatedPortfolio
    }
    
    // MARK: - API Calls
    
    private func fetchQuoteFromAPI(ticker: String) async throws -> MarketstackQuote {
        // Marketstack endpoint: /eod/latest?symbols=AAPL
        let endpoint = "\(baseURL)/eod/latest"
        
        let apiKey = await getAPIKey()
        
        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: "access_key", value: apiKey),
            URLQueryItem(name: "symbols", value: ticker),
            URLQueryItem(name: "limit", value: "1")
        ]
        
        guard let url = components?.url else {
            throw MarketstackError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MarketstackError.invalidResponse
        }
        
        print("📡 Marketstack response for \(ticker): HTTP \(httpResponse.statusCode)")
        
        // Check for errors
        if httpResponse.statusCode == 401 {
            throw MarketstackError.invalidAPIKey
        } else if httpResponse.statusCode == 429 {
            throw MarketstackError.rateLimitExceeded
        } else if httpResponse.statusCode == 403 {
            throw MarketstackError.planLimitReached
        } else if httpResponse.statusCode != 200 {
            // Try to parse error message from response
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Marketstack error response: \(errorString)")
            }
            throw MarketstackError.invalidResponse
        }
        
        // Parse response
        let decoder = JSONDecoder()
        
        do {
            let apiResponse = try decoder.decode(MarketstackAPIResponse.self, from: data)
            
            guard let quote = apiResponse.data.first else {
                print("⚠️ No data returned for ticker: \(ticker)")
                print("   This ticker may not be supported on free tier or doesn't exist")
                throw MarketstackError.invalidTicker(ticker)
            }
            
            return quote
        } catch {
            if let decodingError = error as? DecodingError {
                print("❌ Failed to decode response for \(ticker): \(decodingError)")
            }
            throw MarketstackError.invalidResponse
        }
    }
    
    private func fetchBatchQuotesFromAPI(tickers: [String]) async throws -> [MarketstackQuote] {
        // Marketstack supports multiple symbols: /eod/latest?symbols=AAPL,MSFT,GOOGL
        let endpoint = "\(baseURL)/eod/latest"
        let symbolsString = tickers.joined(separator: ",")
        
        let apiKey = await getAPIKey()
        
        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: "access_key", value: apiKey),
            URLQueryItem(name: "symbols", value: symbolsString),
            URLQueryItem(name: "limit", value: "1")
        ]
        
        guard let url = components?.url else {
            throw MarketstackError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MarketstackError.invalidResponse
        }
        
        print("📡 Marketstack batch response: HTTP \(httpResponse.statusCode)")
        
        // Check for errors
        if httpResponse.statusCode == 401 {
            throw MarketstackError.invalidAPIKey
        } else if httpResponse.statusCode == 429 {
            throw MarketstackError.rateLimitExceeded
        } else if httpResponse.statusCode == 403 {
            throw MarketstackError.planLimitReached
        } else if httpResponse.statusCode != 200 {
            // Try to parse error message from response
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Marketstack batch error response: \(errorString)")
            }
            throw MarketstackError.invalidResponse
        }
        
        // Parse response
        let decoder = JSONDecoder()
        
        do {
            let apiResponse = try decoder.decode(MarketstackAPIResponse.self, from: data)
            
            if apiResponse.data.isEmpty {
                print("⚠️ No data returned for any tickers in batch")
                print("   Requested: \(tickers.joined(separator: ", "))")
            } else {
                let returnedSymbols = apiResponse.data.map { $0.symbol }
                print("✅ Got data for: \(returnedSymbols.joined(separator: ", "))")
            }
            
            return apiResponse.data
        } catch {
            if let decodingError = error as? DecodingError {
                print("❌ Failed to decode batch response: \(decodingError)")
            }
            throw MarketstackError.invalidResponse
        }
    }
    
    // MARK: - Usage Tracking
    
    private func trackAPICall() {
        apiCallCount += 1
        callHistory.append(Date())
        
        // Clean up old history (keep last 30 days)
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        callHistory.removeAll { $0 < thirtyDaysAgo }
        
        // Log usage
        let thisMonth = callsThisMonth()
        print("📊 API Calls: \(apiCallCount) total, \(thisMonth) this month")
        
        // Warn if approaching limit
        if thisMonth >= 80 {
            print("⚠️ WARNING: Used \(thisMonth)/100 API calls this month!")
        }
    }
    
    private func callsThisMonth() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        return callHistory.filter { $0 >= startOfMonth }.count
    }
    
    /// Get API usage statistics
    func getUsageStats() -> (total: Int, thisMonth: Int, limit: Int) {
        return (apiCallCount, callsThisMonth(), 100)
    }
    
    /// Clear cache (useful for testing or forcing refresh)
    func clearCache() {
        quoteCache.removeAll()
        print("🗑️ Cache cleared")
    }
    
    /// Get cache statistics
    func getCacheStats() -> (cached: Int, cacheHitRate: Double) {
        let cachedCount = quoteCache.count
        let hitRate = apiCallCount > 0 ? Double(cachedCount) / Double(apiCallCount + cachedCount) : 0.0
        return (cachedCount, hitRate)
    }
}

// MARK: - API Response Models

private struct MarketstackAPIResponse: Codable {
    let data: [MarketstackQuote]
    let pagination: MarketstackPagination?
}

private struct MarketstackPagination: Codable {
    let limit: Int
    let offset: Int
    let count: Int
    let total: Int
}

// Note: MarketstackQuote is already defined in MarketstackTestService.swift
// We reuse that model since it matches the API structure
