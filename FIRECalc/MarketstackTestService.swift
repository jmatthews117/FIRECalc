//
//  MarketstackTestService.swift
//  FIRECalc
//
//  PHASE 1: Mock test service for Marketstack integration
//  Returns hardcoded test data to verify integration without making real API calls
//  TODO: Replace with real MarketstackService once testing is complete
//

import Foundation

// MARK: - Marketstack Quote Models

/// Marketstack quote response - matches their actual API structure
struct MarketstackQuote: Codable {
    let symbol: String
    let open: Double?
    let high: Double?
    let low: Double?
    let close: Double  // This is the "latest price"
    let volume: Int64?
    let date: String
    let exchange: String?
    
    // NEW: Backend-calculated fields for accurate daily change
    let previousClose: Double?
    let dailyChange: Double?
    let dailyChangePercent: Double?
    
    /// Convert to the shared YFStockQuote format for compatibility
    /// - Parameter previousClose: Optional previous day's close price for accurate daily change calculation
    func toStockQuote(previousClose: Double? = nil) -> YFStockQuote {
        let change: Double?
        let changePercent: Double?
        
        // PRIORITY 1: Use backend-calculated daily change (most accurate)
        if let backendChange = self.dailyChange, let backendChangePercent = self.dailyChangePercent {
            change = backendChange
            changePercent = backendChangePercent
        }
        // PRIORITY 2: Use provided previous close
        else if let prevClose = previousClose {
            change = close - prevClose
            changePercent = prevClose > 0 ? ((close - prevClose) / prevClose) : 0
        }
        // PRIORITY 3: Use stored previous close from struct
        else if let prevClose = self.previousClose {
            change = close - prevClose
            changePercent = prevClose > 0 ? ((close - prevClose) / prevClose) : 0
        }
        // FALLBACK: Use today's open (less accurate but better than nothing)
        else {
            change = open.map { close - $0 }
            changePercent = open.map { $0 > 0 ? ((close - $0) / $0) : 0 }
        }
        
        return YFStockQuote(
            symbol: symbol,
            latestPrice: close,
            change: change,
            changePercent: changePercent,
            volume: volume
        )
    }
}

/// Marketstack API response wrapper
private struct MarketstackResponse: Codable {
    let data: [MarketstackQuote]
    let pagination: MarketstackPagination?
}

private struct MarketstackPagination: Codable {
    let limit: Int
    let offset: Int
    let count: Int
    let total: Int
}

// MARK: - Test Service

actor MarketstackTestService {
    static let shared = MarketstackTestService()
    
    // MARK: - Configuration
    
    /// Placeholder for Marketstack API key (not used in test mode)
    private let apiKey: String? = nil  // TODO: Set this when switching to real service
    
    /// Base URL for Marketstack API (free tier uses http, paid uses https)
    private let baseURL = "http://api.marketstack.com/v1"  // Free tier
    // private let baseURL = "https://api.marketstack.com/v1"  // Paid tier
    
    /// Track mock API calls to simulate usage monitoring
    private(set) var mockAPICallCount: Int = 0
    
    /// Simulate network delay (in milliseconds)
    private let simulatedDelay: UInt64 = 300_000_000  // 300ms
    
    private init() {}
    
    // MARK: - Mock Data
    
    /// Hardcoded test data for common tickers
    /// This is nonisolated so it can be called from task groups
    nonisolated private func getMockQuote(for ticker: String) -> MarketstackQuote {
        let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        
        // Simulate realistic stock prices
        switch cleanTicker {
        case "AAPL":
            return MarketstackQuote(
                symbol: "AAPL",
                open: 178.50,
                high: 182.30,
                low: 177.80,
                close: 181.25,
                volume: 52_450_000,
                date: Self.todayISO(),
                exchange: "NASDAQ",
                previousClose: 178.50,
                dailyChange: 2.75,
                dailyChangePercent: 0.0154
            )
        case "MSFT":
            return MarketstackQuote(
                symbol: "MSFT",
                open: 415.20,
                high: 420.50,
                low: 414.00,
                close: 418.75,
                volume: 28_340_000,
                date: Self.todayISO(),
                exchange: "NASDAQ",
                previousClose: 415.20,
                dailyChange: 3.55,
                dailyChangePercent: 0.0086
            )
        case "GOOGL", "GOOG":
            return MarketstackQuote(
                symbol: cleanTicker,
                open: 142.30,
                high: 145.10,
                low: 141.80,
                close: 144.25,
                volume: 21_230_000,
                date: Self.todayISO(),
                exchange: "NASDAQ",
                previousClose: 142.00,
                dailyChange: 2.25,
                dailyChangePercent: 0.0158
            )
        case "TSLA":
            return MarketstackQuote(
                symbol: "TSLA",
                open: 245.60,
                high: 252.30,
                low: 243.50,
                close: 250.10,
                volume: 95_670_000,
                date: Self.todayISO(),
                exchange: "NASDAQ",
                previousClose: 245.60,
                dailyChange: 4.50,
                dailyChangePercent: 0.0183
            )
        case "SPY":
            return MarketstackQuote(
                symbol: "SPY",
                open: 505.20,
                high: 508.50,
                low: 504.80,
                close: 507.35,
                volume: 42_100_000,
                date: Self.todayISO(),
                exchange: "NYSE",
                previousClose: 505.20,
                dailyChange: 2.15,
                dailyChangePercent: 0.0043
            )
        case "VTI":
            return MarketstackQuote(
                symbol: "VTI",
                open: 245.80,
                high: 247.20,
                low: 245.30,
                close: 246.85,
                volume: 3_250_000,
                date: Self.todayISO(),
                exchange: "NYSE",
                previousClose: 245.80,
                dailyChange: 1.05,
                dailyChangePercent: 0.0043
            )
        default:
            // Generic fallback for unknown tickers
            let basePrice = Double.random(in: 50...300)
            let variation = basePrice * 0.02  // ±2% daily range
            let prevClose = basePrice
            let currentClose = basePrice + Double.random(in: -variation...variation)
            return MarketstackQuote(
                symbol: cleanTicker,
                open: basePrice,
                high: basePrice + variation,
                low: basePrice - variation,
                close: currentClose,
                volume: Int64.random(in: 1_000_000...50_000_000),
                date: Self.todayISO(),
                exchange: "UNKNOWN",
                previousClose: prevClose,
                dailyChange: currentClose - prevClose,
                dailyChangePercent: (currentClose - prevClose) / prevClose
            )
        }
    }
    
    /// Mock crypto prices (Marketstack supports limited crypto on paid plans)
    /// This is nonisolated so it can be called from task groups
    nonisolated private func getMockCryptoQuote(for symbol: String) -> MarketstackQuote {
        let cleanSymbol = symbol.uppercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "-USD", with: "")
        
        switch cleanSymbol {
        case "BTC", "BTCUSD":
            return MarketstackQuote(
                symbol: "BTC",
                open: 67800.0,
                high: 69200.0,
                low: 67200.0,
                close: 68500.0,
                volume: 25_000_000_000,
                date: Self.todayISO(),
                exchange: "CRYPTO",
                previousClose: 67800.0,
                dailyChange: 700.0,
                dailyChangePercent: 0.0103
            )
        case "ETH", "ETHUSD":
            return MarketstackQuote(
                symbol: "ETH",
                open: 3420.0,
                high: 3510.0,
                low: 3380.0,
                close: 3475.0,
                volume: 12_000_000_000,
                date: Self.todayISO(),
                exchange: "CRYPTO",
                previousClose: 3420.0,
                dailyChange: 55.0,
                dailyChangePercent: 0.0161
            )
        default:
            let basePrice = Double.random(in: 1...1000)
            let variation = basePrice * 0.05
            let prevClose = basePrice
            let currentClose = basePrice + Double.random(in: -variation...variation)
            return MarketstackQuote(
                symbol: cleanSymbol,
                open: basePrice,
                high: basePrice + variation,
                low: basePrice - variation,
                close: currentClose,
                volume: Int64.random(in: 1_000_000...100_000_000),
                date: Self.todayISO(),
                exchange: "CRYPTO",
                previousClose: prevClose,
                dailyChange: currentClose - prevClose,
                dailyChangePercent: (currentClose - prevClose) / prevClose
            )
        }
    }
    
    // MARK: - Public API (mirrors YahooFinanceService)
    
    /// Fetch current price for a single ticker
    func fetchQuote(ticker: String) async throws -> YFStockQuote {
        mockAPICallCount += 1
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: simulatedDelay)
        
        let mockQuote = getMockQuote(for: ticker)
        return mockQuote.toStockQuote()
    }
    
    /// Fetch crypto quote
    func fetchCryptoQuote(symbol: String) async throws -> YFCryptoQuote {
        mockAPICallCount += 1
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: simulatedDelay)
        
        let mockQuote = getMockCryptoQuote(for: symbol)
        
        let cleanSymbol = symbol.uppercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "-USD", with: "")
        
        return YFCryptoQuote(
            symbol: cleanSymbol,
            latestPrice: mockQuote.close,
            lastUpdate: Date()
        )
    }
    
    /// Fetch quotes for multiple tickers in batch
    func fetchBatchQuotes(tickers: [String]) async throws -> [String: YFStockQuote] {
        guard !tickers.isEmpty else { return [:] }
        
        mockAPICallCount += 1  // In real Marketstack, batch calls count as 1 API call
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: simulatedDelay)
        
        var quotes: [String: YFStockQuote] = [:]
        
        for ticker in tickers {
            let mockQuote = getMockQuote(for: ticker)
            quotes[ticker.uppercased()] = mockQuote.toStockQuote()
        }
        
        return quotes
    }
    
    /// Update all assets in a portfolio
    func updatePortfolioPrices(portfolio: Portfolio) async throws -> Portfolio {
        var updatedPortfolio = portfolio
        let assetsWithTickers = portfolio.assetsWithTickers
        
        guard !assetsWithTickers.isEmpty else {
            return portfolio
        }
        
        var successfulUpdates = 0
        var failedUpdates = 0
        
        // Process in batches to simulate real API behavior
        let batchSize = 5
        
        for batchStart in stride(from: 0, to: assetsWithTickers.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, assetsWithTickers.count)
            let batch = Array(assetsWithTickers[batchStart..<batchEnd])
            
            // Simulate batch fetching
            await withTaskGroup(of: (Asset, Double?, Double?).self) { group in
                for asset in batch {
                    group.addTask {
                        do {
                            let quote: MarketstackQuote
                            
                            if asset.assetClass == .crypto {
                                quote = self.getMockCryptoQuote(for: asset.ticker ?? "")
                            } else {
                                quote = self.getMockQuote(for: asset.ticker ?? "")
                            }
                            
                            let changePercent = quote.open.map { 
                                $0 > 0 ? ((quote.close - $0) / $0) : 0 
                            }
                            
                            return (asset, quote.close, changePercent)
                        } catch {
                            return (asset, nil, nil)
                        }
                    }
                }
                
                for await (asset, price, change) in group {
                    if let price = price {
                        let updatedAsset = asset.updatedWithLivePrice(price, change: change)
                        updatedPortfolio.updateAsset(updatedAsset)
                        successfulUpdates += 1
                    } else {
                        failedUpdates += 1
                    }
                }
            }
            
            // Count this batch as one API call
            mockAPICallCount += 1
            
            // Small delay between batches
            if batchEnd < assetsWithTickers.count {
                try await Task.sleep(nanoseconds: simulatedDelay / 2)
            }
        }
        
        return updatedPortfolio
    }
    
    // MARK: - Monitoring
    
    /// Reset the mock API call counter (useful for testing)
    func resetCallCounter() {
        mockAPICallCount = 0
    }
    
    /// Get current mock API call count
    func getCallCount() -> Int {
        return mockAPICallCount
    }
    
    // MARK: - Helpers
    
    nonisolated private static func todayISO() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: Date())
    }
}

// MARK: - Marketstack Errors

enum MarketstackError: LocalizedError {
    case invalidAPIKey
    case rateLimitExceeded
    case invalidTicker(String)
    case networkError(Error)
    case invalidResponse
    case planLimitReached  // Free tier limitations
    case refreshCooldownActive(remainingTime: TimeInterval)
    case unsupportedMutualFund(original: String, mapping: TickerMapping)
    case unsupportedCrypto(original: String, mapping: TickerMapping)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid Marketstack API key"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait before making more requests."
        case .invalidTicker(let ticker):
            return "Ticker '\(ticker)' not found on Marketstack"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Marketstack API"
        case .planLimitReached:
            return "API request limit reached for your plan. Consider upgrading or waiting until the next billing cycle."
        case .refreshCooldownActive(let remaining):
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            if hours > 0 {
                return "Refresh cooldown active. Next refresh available in \(hours)h \(minutes)m."
            } else {
                return "Refresh cooldown active. Next refresh available in \(minutes)m."
            }
        case .unsupportedMutualFund(let original, let mapping):
            return "\(original) is a mutual fund and cannot be tracked with live prices. Consider using \(mapping.etfAlternative) (\(mapping.etfName)) instead. \(mapping.reason)"
        case .unsupportedCrypto(let original, let mapping):
            return "\(original) is a cryptocurrency and cannot be tracked via stock market APIs. Consider using \(mapping.etfAlternative) (\(mapping.etfName)) instead. \(mapping.reason)"
        }
    }
}
