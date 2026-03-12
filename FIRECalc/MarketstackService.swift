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
    
    /// Backend proxy handles API calls - no API key needed in app!
    /// MarketstackConfig.shared manages communication with our secure backend
    
    /// Cache duration in seconds (15 minutes for individual quote display)
    private let cacheDuration: TimeInterval = 900
    
    /// Global refresh cooldown (12 hours - prevents any API calls within this window)
    /// Set to 12 hours = 43,200 seconds for production
    /// Can be reduced to 120 (2 min) or 300 (5 min) for testing
    private let globalRefreshCooldown: TimeInterval = 43_200  // 12 hours (43,200 seconds)
    
    /// API usage tracking
    private(set) var apiCallCount: Int = 0
    private var callHistory: [Date] = []
    
    /// Track if we're currently in a refresh session (to allow fallback fetches)
    private var isInRefreshSession: Bool = false
    
    // MARK: - Persistence Keys
    
    private let lastRefreshKey = "marketstack_last_global_refresh"
    private let quoteCacheKey = "marketstack_quote_cache"
    
    // MARK: - Persistent Properties
    
    /// Last time ANY API call was made (persisted across app launches)
    private var lastRefreshTime: Date? {
        get {
            let timestamp = UserDefaults.standard.double(forKey: lastRefreshKey)
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: lastRefreshKey)
                print("💾 Saved last refresh time: \(date)")
            } else {
                UserDefaults.standard.removeObject(forKey: lastRefreshKey)
            }
        }
    }
    
    /// Quote cache with timestamps (persisted across app launches)
    private var quoteCache: [String: CachedQuote] {
        get {
            loadCacheFromDisk()
        }
        set {
            saveCacheToDisk(newValue)
        }
    }
    
    private init() {
        print("📡 MarketstackService initialized (LIVE MODE)")
        print("⚠️ API: 1 call per symbol (100 calls/month free tier)")
        print("⚠️ Cooldown: 12 hours between portfolio refreshes")
        
        // Log current cooldown status
        if let nextRefresh = getNextRefreshDate() {
            let remaining = nextRefresh.timeIntervalSince(Date())
            if remaining > 0 {
                print("⏳ Next refresh available in \(formatDuration(remaining))")
            } else {
                print("✅ Refresh available now")
            }
        } else {
            print("✅ Refresh available now")
        }
    }
    
    // MARK: - Cache Model
    
    struct CachedQuote: Codable {
        let quote: MarketstackQuote
        let timestamp: Date
        
        func isExpired(cacheDuration: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) > cacheDuration
        }
    }
    
    // MARK: - Cooldown Management
    
    /// Check if we can make an API call (respects 12-hour cooldown)
    /// - Parameter allowBypass: If true, allows bypassing cooldown for critical operations
    private func canMakeAPICall(allowBypass: Bool = false) async -> Bool {
        // SUBSCRIPTION CHECK: Free users cannot access stock quotes at all
        let isPro = await MainActor.run { SubscriptionManager.shared.isProSubscriber }
        
        if !isPro {
            print("🚫 Free tier - stock quotes disabled")
            return false
        }
        
        // Pro users: Allow bypass for single asset lookups (like adding new assets)
        if allowBypass {
            print("✅ Pro user - Cooldown bypass allowed for single asset lookup")
            return true
        }
        
        // REFRESH SESSION FIX: If we're in an active refresh session, allow API calls
        // This ensures fallback logic can complete if the batch API fails
        if isInRefreshSession {
            print("✅ Pro user - In active refresh session - allowing API call")
            return true
        }
        
        guard let lastRefresh = lastRefreshTime else {
            print("✅ Pro user - No previous refresh - allowing API call")
            return true
        }
        
        let elapsed = Date().timeIntervalSince(lastRefresh)
        // BUG FIX: Use a small epsilon to handle floating point precision issues
        // Allow refresh if within 5 seconds of cooldown expiring to prevent "0m remaining" still blocking
        // This handles cases where formatDuration() shows "0m" but there are still a few seconds left
        let canRefresh = elapsed >= (globalRefreshCooldown - 5.0)
        
        if canRefresh {
            print("✅ Pro user - Cooldown expired (\(formatDuration(elapsed)) elapsed) - allowing API call")
        } else {
            let remaining = globalRefreshCooldown - elapsed
            print("⏳ Pro user - Cooldown active - \(formatDuration(remaining)) remaining until next refresh")
        }
        
        return canRefresh
    }
    
    /// Record that an API call was made (updates last refresh time)
    private func recordAPICall() {
        lastRefreshTime = Date()
        print("📝 Recorded API call at \(Date())")
    }
    
    /// End refresh session and record cooldown timestamp
    /// This should be called after ALL assets (including fallback) are processed
    func endRefreshSession() {
        guard isInRefreshSession else {
            print("⚠️ endRefreshSession called but no session was active")
            return
        }
        
        isInRefreshSession = false
        recordAPICall()
        print("🔄 Ended refresh session - cooldown timer set")
    }
    
    // MARK: - Public API
    
    /// Fetch current price for a single ticker (for adding new assets)
    /// This bypasses the 12-hour cooldown since it's a user-initiated single lookup
    /// - Parameter ticker: Stock ticker symbol
    /// - Parameter bypassCooldown: If true, ignores cooldown for single asset lookups
    func fetchQuote(ticker: String, bypassCooldown: Bool = false) async throws -> YFStockQuote {
        let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        
        print("🔍 fetchQuote called for: '\(ticker)' → cleaned: '\(cleanTicker)' (bypass: \(bypassCooldown))")
        
        // Validate ticker format
        if cleanTicker.isEmpty {
            throw MarketstackError.invalidTicker(ticker)
        }
        
        // TICKER MAPPING: Check if this is a mutual fund or crypto that should be mapped
        let mappingResult = await TickerMappingService.shared.checkTicker(cleanTicker)
        
        switch mappingResult {
        case .unsupportedMutualFund(let original, let mapping):
            print("🚫 Mutual fund intercepted: \(original) → suggest \(mapping.etfAlternative)")
            throw MarketstackError.unsupportedMutualFund(original: original, mapping: mapping)
            
        case .unsupportedCrypto(let original, let mapping):
            print("🚫 Crypto intercepted: \(original) → suggest \(mapping.etfAlternative)")
            throw MarketstackError.unsupportedCrypto(original: original, mapping: mapping)
            
        case .supported(let ticker):
            // Continue with normal flow
            print("✅ Ticker \(ticker) is supported - proceeding with price fetch")
            
        case .unknown(let ticker):
            // Not in our mappings - assume it's supported and let the API decide
            print("❓ Ticker \(ticker) not in mappings - attempting fetch")
        }
        
        // Check cache first - ALWAYS return if we have it and within 12-hour window
        if let cached = quoteCache[cleanTicker] {
            let age = Date().timeIntervalSince(cached.timestamp)
            
            // Within 12-hour cooldown? Always return cache (even if "stale" by 15-min standard)
            // UNLESS bypass is enabled and cache is older than 5 minutes
            let cacheIsFresh = bypassCooldown ? (age < 300) : (age < globalRefreshCooldown)
            
            if cacheIsFresh {
                print("💾 Returning cached data for \(cleanTicker) (age: \(formatDuration(age)))")
                return cached.quote.toStockQuote()
            }
            
            print("⏰ Cache expired for \(cleanTicker) (age: \(formatDuration(age)))")
        } else {
            print("❌ Cache MISS for \(cleanTicker) (not in cache)")
        }
        
        // Check if we can make API call (12-hour cooldown check + subscription check)
        guard await canMakeAPICall(allowBypass: bypassCooldown) else {
            // Return stale cache if available, or throw error
            if let cached = quoteCache[cleanTicker] {
                let age = Date().timeIntervalSince(cached.timestamp)
                print("⚠️ Returning stale cache for \(cleanTicker) (age: \(formatDuration(age)))")
                return cached.quote.toStockQuote()
            }
            throw MarketstackError.refreshCooldownActive(remainingTime: timeUntilNextRefresh())
        }
        
        // Make API call
        print("📡 API call for \(cleanTicker) in fetchQuote")
        
        do {
            let quote = try await fetchQuoteFromAPI(ticker: cleanTicker)
            
            // Update cache
            var updatedCache = quoteCache
            updatedCache[cleanTicker] = CachedQuote(quote: quote, timestamp: Date())
            quoteCache = updatedCache
            
            // Record API call and track usage
            // Only update global timestamp if this is NOT a bypass (i.e., it's a portfolio refresh)
            if !bypassCooldown {
                recordAPICall()
            } else {
                print("📝 Single asset lookup - not updating global refresh timestamp")
            }
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
    /// - Parameter bypassCooldown: If true, allows fetching during cooldown (for adding new assets)
    func fetchCryptoQuote(symbol: String, bypassCooldown: Bool = false) async throws -> YFCryptoQuote {
        let cleanSymbol = symbol.uppercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "-USD", with: "")
        
        // TICKER MAPPING: Check if this crypto should be mapped to an ETF
        let mappingResult = await TickerMappingService.shared.checkTicker(cleanSymbol)
        
        switch mappingResult {
        case .unsupportedCrypto(let original, let mapping):
            print("🚫 Crypto intercepted: \(original) → suggest \(mapping.etfAlternative)")
            throw MarketstackError.unsupportedCrypto(original: original, mapping: mapping)
            
        case .unsupportedMutualFund(let original, let mapping):
            // Shouldn't happen for crypto, but handle it anyway
            print("🚫 Mutual fund intercepted in crypto lookup: \(original) → suggest \(mapping.etfAlternative)")
            throw MarketstackError.unsupportedMutualFund(original: original, mapping: mapping)
            
        case .supported, .unknown:
            // Continue with normal flow
            break
        }
        
        // Marketstack has limited crypto support - try as regular ticker
        // Note: Free tier may not support crypto at all
        let quote = try await fetchQuote(ticker: cleanSymbol, bypassCooldown: bypassCooldown)
        
        return YFCryptoQuote(
            symbol: cleanSymbol,
            latestPrice: quote.latestPrice,
            lastUpdate: Date()
        )
    }
    
    /// Fetch quotes for multiple tickers (makes individual API calls for each)
    /// NOTE: Marketstack API charges 1 call per symbol, even with batch endpoints
    /// Handles failures gracefully - returns what it can fetch
    /// Respects 12-hour global cooldown
    func fetchBatchQuotes(tickers: [String]) async throws -> [String: YFStockQuote] {
        guard !tickers.isEmpty else { return [:] }
        
        let cleanTickers = tickers.map { $0.uppercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !cleanTickers.isEmpty else { return [:] }
        
        print("🔍 Checking cache for \(cleanTickers.count) tickers...")
        
        // Load cache once (performance fix)
        let cache = quoteCache
        
        // Check which tickers are cached
        var results: [String: YFStockQuote] = [:]
        var tickersToFetch: [String] = []
        
        for ticker in cleanTickers {
            if let cached = cache[ticker] {
                let age = Date().timeIntervalSince(cached.timestamp)
                
                // Within 12-hour cooldown? Always use cache
                if age < globalRefreshCooldown {
                    print("💾 Cache HIT for \(ticker) (age: \(formatDuration(age)))")
                    results[ticker] = cached.quote.toStockQuote()
                } else {
                    print("⏰ Cache EXPIRED for \(ticker) (age: \(formatDuration(age)))")
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
        
        // Check if we can make API call (12-hour cooldown check + subscription check)
        guard await canMakeAPICall() else {
            print("⏳ Cooldown active - returning cached data only (\(results.count)/\(cleanTickers.count) tickers)")
            
            // Return any stale cache we have for the missing tickers
            for ticker in tickersToFetch {
                if let cached = cache[ticker] {
                    let age = Date().timeIntervalSince(cached.timestamp)
                    print("⚠️ Returning stale cache for \(ticker) (age: \(formatDuration(age)))")
                    results[ticker] = cached.quote.toStockQuote()
                }
            }
            
            print("⚠️ Returning partial results (\(results.count)/\(cleanTickers.count)) - cooldown prevents fetching \(tickersToFetch.count) missing tickers")
            return results
        }
        
        // REFRESH SESSION: Start refresh session BEFORE making API calls
        // This allows all fetches to complete before cooldown starts
        isInRefreshSession = true
        print("🔄 Started refresh session")
        
        // Fetch each ticker individually (Marketstack charges per symbol anyway)
        print("📡 🔴 Making \(tickersToFetch.count) individual API calls for: \(tickersToFetch.prefix(5).joined(separator: ", "))\(tickersToFetch.count > 5 ? "..." : "")")
        
        var updatedCache = cache
        var successCount = 0
        var failCount = 0
        
        // OPTION: Choose between concurrent (fast) or sequential (reliable for cold starts)
        let useConcurrent = false  // Set to true for speed, false for reliability
        
        if useConcurrent {
            // Fetch all tickers concurrently (faster but can overwhelm cold backend)
            await withTaskGroup(of: (String, MarketstackQuote?).self) { group in
                for ticker in tickersToFetch {
                    group.addTask {
                        do {
                            let quote = try await self.fetchQuoteFromAPI(ticker: ticker)
                            return (ticker, quote)
                        } catch {
                            print("⚠️ Failed to fetch \(ticker): \(error.localizedDescription)")
                            return (ticker, nil)
                        }
                    }
                }
                
                // Collect results
                for await (ticker, quote) in group {
                    if let quote = quote {
                        print("💾 Caching \(quote.symbol) at \(Date())")
                        updatedCache[quote.symbol] = CachedQuote(quote: quote, timestamp: Date())
                        results[quote.symbol] = quote.toStockQuote()
                        successCount += 1
                        
                        // Track each API call for statistics
                        trackAPICall()
                    } else {
                        failCount += 1
                        
                        // Still return stale cache if available
                        if let cached = cache[ticker] {
                            let age = Date().timeIntervalSince(cached.timestamp)
                            print("⚠️ Using stale cache for failed \(ticker) (age: \(formatDuration(age)))")
                            results[ticker] = cached.quote.toStockQuote()
                        }
                    }
                }
            }
        } else {
            // Fetch tickers sequentially (slower but more reliable for cold backend)
            print("⚙️ Using sequential fetching (more reliable for cold starts)")
            
            for (index, ticker) in tickersToFetch.enumerated() {
                do {
                    print("📥 [\(index + 1)/\(tickersToFetch.count)] Fetching \(ticker)...")
                    let quote = try await fetchQuoteFromAPI(ticker: ticker)
                    
                    print("💾 Caching \(quote.symbol) at \(Date())")
                    updatedCache[quote.symbol] = CachedQuote(quote: quote, timestamp: Date())
                    results[quote.symbol] = quote.toStockQuote()
                    successCount += 1
                    
                    // Track each API call for statistics
                    trackAPICall()
                } catch {
                    print("⚠️ Failed to fetch \(ticker): \(error.localizedDescription)")
                    failCount += 1
                    
                    // Still return stale cache if available
                    if let cached = cache[ticker] {
                        let age = Date().timeIntervalSince(cached.timestamp)
                        print("⚠️ Using stale cache for failed \(ticker) (age: \(formatDuration(age)))")
                        results[ticker] = cached.quote.toStockQuote()
                    }
                }
            }
        }
        
        // Save updated cache
        quoteCache = updatedCache
        
        print("✅ Fetched \(successCount)/\(tickersToFetch.count) quotes successfully (\(failCount) failed)")
        
        // REFRESH SESSION: Keep session active - ViewModel will end it after fallback logic
        return results
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
        // Call our backend proxy instead of Marketstack directly
        print("🌐 [API] Fetching \(ticker)...")
        
        do {
            let quote = try await MarketstackConfig.shared.fetchQuote(symbol: ticker)
            print("✅ [API] Received quote for \(ticker): $\(quote.close)")
            return quote
        } catch let error as ConfigError {
            print("❌ [API] Backend error for \(ticker): \(error.localizedDescription)")
            throw MarketstackError.networkError(error)
        } catch {
            print("❌ [API] Unknown error for \(ticker): \(error.localizedDescription)")
            throw MarketstackError.networkError(error)
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
    
    /// Get time until next refresh is allowed
    func timeUntilNextRefresh() -> TimeInterval {
        guard let lastRefresh = lastRefreshTime else { return 0 }
        let elapsed = Date().timeIntervalSince(lastRefresh)
        return max(0, globalRefreshCooldown - elapsed)
    }
    
    /// Get the date when next refresh will be allowed
    func getNextRefreshDate() -> Date? {
        guard let lastRefresh = lastRefreshTime else { return nil }
        return lastRefresh.addingTimeInterval(globalRefreshCooldown)
    }
    
    /// Get refresh status for UI display
    func getRefreshStatus() -> RefreshStatus {
        if let nextRefresh = getNextRefreshDate() {
            let remaining = nextRefresh.timeIntervalSince(Date())
            // BUG FIX: Use same 5-second epsilon as canMakeAPICall to prevent "0m remaining" showing as active
            if remaining > 5.0 {
                return .cooldownActive(nextRefreshDate: nextRefresh, remainingTime: remaining)
            }
        }
        return .available
    }
    
    /// Clear cache (useful for testing or forcing refresh)
    func clearCache() {
        var emptyCache: [String: CachedQuote] = [:]
        quoteCache = emptyCache
        print("🗑️ Cache cleared")
    }
    
    /// Clear cooldown timer (useful for testing)
    /// WARNING: Only use for development/testing!
    func clearCooldown() {
        lastRefreshTime = nil
        print("🗑️ Cooldown cleared - refresh now available")
    }
    
    /// Get cache statistics
    func getCacheStats() -> (cached: Int, cacheHitRate: Double) {
        let cache = quoteCache
        let cachedCount = cache.count
        let hitRate = apiCallCount > 0 ? Double(cachedCount) / Double(apiCallCount + cachedCount) : 0.0
        return (cachedCount, hitRate)
    }
    
    // MARK: - Cache Persistence
    
    private func loadCacheFromDisk() -> [String: CachedQuote] {
        guard let data = UserDefaults.standard.data(forKey: quoteCacheKey) else {
            print("💾 No cached quotes found on disk")
            return [:]
        }
        
        do {
            let cache = try JSONDecoder().decode([String: CachedQuote].self, from: data)
            print("💾 Loaded \(cache.count) cached quotes from disk")
            
            // Log ages of cached items
            let now = Date()
            for (ticker, cached) in cache.prefix(3) {
                let age = now.timeIntervalSince(cached.timestamp)
                print("   - \(ticker): \(formatDuration(age)) old")
            }
            
            return cache
        } catch {
            print("⚠️ Failed to load cache from disk: \(error)")
            return [:]
        }
    }
    
    private func saveCacheToDisk(_ cache: [String: CachedQuote]) {
        do {
            let data = try JSONEncoder().encode(cache)
            UserDefaults.standard.set(data, forKey: quoteCacheKey)
            print("💾 Saved \(cache.count) quotes to disk")
        } catch {
            print("⚠️ Failed to save cache to disk: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Format a time duration in a human-readable way
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Refresh Status

enum RefreshStatus {
    case available
    case cooldownActive(nextRefreshDate: Date, remainingTime: TimeInterval)
    
    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }
    
    var displayText: String {
        switch self {
        case .available:
            return "Refresh available now"
        case .cooldownActive(let nextDate, let remaining):
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            
            if hours > 0 {
                return "Next refresh in \(hours)h \(minutes)m"
            } else {
                return "Next refresh in \(minutes)m"
            }
        }
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
