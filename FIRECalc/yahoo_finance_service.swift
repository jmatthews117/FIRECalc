//
//  YahooFinanceService.swift
//  FIRECalc
//
//  Yahoo Finance integration using public chart endpoint
//  NO API KEY REQUIRED!
//

import Foundation

// MARK: - Shared Models (used across services)

struct YFStockQuote: Codable {
    let symbol: String
    let latestPrice: Double
    let change: Double?
    let changePercent: Double?
    let volume: Int64?
}

struct YFCryptoQuote: Codable {
    let symbol: String
    let latestPrice: Double
    let lastUpdate: Date
}

// MARK: - Yahoo Finance Service

actor YahooFinanceService {
    static let shared = YahooFinanceService()
    
    // Yahoo Finance public chart endpoint (works without auth!)
    private let chartURL = "https://query1.finance.yahoo.com/v8/finance/chart"
    
    private init() {}
    
    // MARK: - Retry Logic
    
    /// Retry wrapper for transient network failures
    private func fetchWithRetry<T>(
        maxAttempts: Int = 3,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch is CancellationError {
                // Don't retry on cancellation - just re-throw immediately
                print("⚠️ Task was cancelled - not retrying")
                throw CancellationError()
            } catch {
                lastError = error
                print("⚠️ Attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt < maxAttempts {
                    let delay = UInt64(attempt * 500_000_000) // 0.5s, 1s, 1.5s
                    do {
                        try await Task.sleep(nanoseconds: delay)
                    } catch is CancellationError {
                        // If sleep is cancelled, stop retrying
                        print("⚠️ Sleep cancelled - stopping retries")
                        throw CancellationError()
                    }
                }
            }
        }
        
        throw lastError ?? YFError.networkError(NSError(domain: "Retry failed", code: -1))
    }
    
    // MARK: - Quote Fetching
    
    /// Fetch current price for a single ticker
    func fetchQuote(ticker: String) async throws -> YFStockQuote {
        try await fetchWithRetry {
            try await self.fetchQuoteInternal(ticker: ticker)
        }
    }
    
    private func fetchQuoteInternal(ticker: String) async throws -> YFStockQuote {
        let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        
        let urlString = "\(chartURL)/\(cleanTicker)"
        
        guard let url = URL(string: urlString) else {
            throw YFError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        print("📡 Fetching \(cleanTicker) from: \(urlString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw YFError.invalidResponse
        }
        
        print("📡 HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ HTTP Error: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString.prefix(200))")
            }
            throw YFError.httpError(httpResponse.statusCode)
        }
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📡 Yahoo Finance Response:")
            print(jsonString.prefix(500))
        }
        
        let decoder = JSONDecoder()
        do {
            let chartResponse = try decoder.decode(YahooChartResponse.self, from: data)
            
            guard let results = chartResponse.chart.result, let result = results.first else {
                print("❌ No results in response")
                throw YFError.tickerNotFound(cleanTicker)
            }
            
            guard let meta = result.meta else {
                print("❌ No meta in result")
                throw YFError.invalidResponse
            }
            
            let currentPrice = meta.regularMarketPrice ?? 0
            let previousClose = meta.chartPreviousClose ?? meta.regularMarketPrice ?? 0
            let change = currentPrice - previousClose
            let changePercent = previousClose > 0 ? (change / previousClose) : 0
            
            print("✅ Got quote for \(meta.symbol): $\(currentPrice)")
            
            return YFStockQuote(
                symbol: meta.symbol,
                latestPrice: currentPrice,
                change: change,
                changePercent: changePercent,
                volume: nil
            )
        } catch {
            print("❌ Decoding error: \(error)")
            throw YFError.invalidResponse
        }
    }
    
    /// Fetch crypto quote
    func fetchCryptoQuote(symbol: String) async throws -> YFCryptoQuote {
        print("      ╔══════════════════════════════════════════════")
        print("      ║ [YahooFinanceService.fetchCryptoQuote]")
        print("      ║ Input symbol: '\(symbol)'")
        
        let cleanSymbol = symbol.uppercased().trimmingCharacters(in: .whitespaces)
        print("      ║ Clean symbol: '\(cleanSymbol)'")
        
        // CRYPTO FIX: Always ensure -USD suffix for Yahoo Finance
        let yahooSymbol: String
        if cleanSymbol.hasSuffix("-USD") {
            yahooSymbol = cleanSymbol
            print("      ║ Already has -USD suffix")
        } else {
            yahooSymbol = "\(cleanSymbol)-USD"
            print("      ║ Adding -USD suffix")
        }
        
        print("      ║ Yahoo symbol: '\(yahooSymbol)'")
        print("      ║ Calling fetchQuote(ticker: '\(yahooSymbol)')...")
        
        let quote = try await fetchQuote(ticker: yahooSymbol)
        
        print("      ║ ✅ Got quote: $\(quote.latestPrice)")
        print("      ╚══════════════════════════════════════════════")
        
        return YFCryptoQuote(
            symbol: cleanSymbol.replacingOccurrences(of: "-USD", with: ""),
            latestPrice: quote.latestPrice,
            lastUpdate: Date()
        )
    }
    
    /// Fetch quotes for multiple tickers (optimized with concurrent fetching)
    func fetchBatchQuotes(tickers: [String]) async throws -> [String: YFStockQuote] {
        guard !tickers.isEmpty else { return [:] }
        
        // Process in batches of 5 to balance speed and API courtesy
        let batchSize = 5
        var quotes: [String: YFStockQuote] = [:]
        
        for batchStart in stride(from: 0, to: tickers.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, tickers.count)
            let batch = Array(tickers[batchStart..<batchEnd])
            
            // Fetch batch concurrently
            await withTaskGroup(of: (String, YFStockQuote?).self) { group in
                for ticker in batch {
                    group.addTask {
                        do {
                            let quote = try await self.fetchQuote(ticker: ticker)
                            return (ticker.uppercased(), quote)
                        } catch {
                            print("⚠️ Failed to fetch \(ticker): \(error.localizedDescription)")
                            return (ticker.uppercased(), nil)
                        }
                    }
                }
                
                for await (ticker, quote) in group {
                    if let quote = quote {
                        quotes[ticker] = quote
                    }
                }
            }
            
            // Small delay between batches to be respectful to Yahoo Finance
            if batchEnd < tickers.count {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s between batches
            }
        }
        
        return quotes
    }
    
    /// Update all assets in a portfolio (optimized with rate-limited concurrent fetching)
    func updatePortfolioPrices(portfolio: Portfolio) async throws -> Portfolio {
        var updatedPortfolio = portfolio
        let assetsWithTickers = portfolio.assetsWithTickers
        
        guard !assetsWithTickers.isEmpty else {
            return portfolio
        }
        
        print("🔄 Updating \(assetsWithTickers.count) assets...")
        
        // Track successful and failed updates
        var successfulUpdates = 0
        var failedUpdates = 0
        
        // UNIFIED APPROACH: Use AlternativePriceService for ALL assets
        // This ensures crypto gets -USD suffix consistently
        let batchSize = 3
        
        for batchStart in stride(from: 0, to: assetsWithTickers.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, assetsWithTickers.count)
            let batch = Array(assetsWithTickers[batchStart..<batchEnd])
            
            // Fetch this batch concurrently
            await withTaskGroup(of: (Asset, Double?, Double?).self) { group in
                for asset in batch {
                    group.addTask {
                        do {
                            // Use AlternativePriceService which handles crypto correctly
                            let price = try await AlternativePriceService.shared.fetchPrice(for: asset)
                            
                            // For change percentage, try to get it if available
                            var changePercent: Double? = nil
                            if asset.assetClass != .crypto {
                                // For stocks, try to get change percent
                                if let ticker = asset.ticker {
                                    if let quote = try? await self.fetchQuote(ticker: ticker) {
                                        changePercent = quote.changePercent
                                    }
                                }
                            }
                            
                            return (asset, price, changePercent)
                        } catch {
                            print("⚠️ Failed to update \(asset.ticker ?? asset.name): \(error.localizedDescription)")
                            return (asset, nil, nil)
                        }
                    }
                }
                
                for await (asset, price, change) in group {
                    if let price = price {
                        let updatedAsset = asset.updatedWithLivePrice(price, change: change)
                        updatedPortfolio.updateAsset(updatedAsset)
                        successfulUpdates += 1
                        print("   ✅ \(asset.ticker ?? asset.name): $\(price)")
                    } else {
                        failedUpdates += 1
                        print("   ❌ Failed to update \(asset.ticker ?? asset.name)")
                    }
                }
            }
            
            // Small delay between batches to avoid overwhelming Yahoo Finance
            if batchEnd < assetsWithTickers.count {
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3s between batches
            }
        }
        
        print("📊 Update complete: \(successfulUpdates) succeeded, \(failedUpdates) failed")
        
        return updatedPortfolio
    }
}

// MARK: - Private Response Models

private struct YahooChartResponse: Codable {
    let chart: YFChart
}

private struct YFChart: Codable {
    let result: [YFChartResult]?
    let error: YFChartError?
}

private struct YFChartResult: Codable {
    let meta: YFChartMeta?
    let timestamp: [Int]?
    let indicators: YFIndicators?
}

private struct YFChartMeta: Codable {
    let symbol: String
    let regularMarketPrice: Double?
    let chartPreviousClose: Double?
    let currency: String?
    let exchangeName: String?
}

private struct YFIndicators: Codable {
    let quote: [YFQuoteData]?
}

private struct YFQuoteData: Codable {
    let close: [Double?]?
    let open: [Double?]?
    let high: [Double?]?
    let low: [Double?]?
    let volume: [Int64?]?
}

private struct YFChartError: Codable {
    let code: String
    let description: String
}

// MARK: - Errors

enum YFError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case tickerNotFound(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP error: \(code). Service may be temporarily unavailable."
        case .tickerNotFound(let ticker):
            return "Ticker '\(ticker)' not found. Please verify the symbol is correct."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
