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
            } catch {
                lastError = error
                print("⚠️ Attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt < maxAttempts {
                    let delay = UInt64(attempt * 500_000_000) // 0.5s, 1s, 1.5s
                    try await Task.sleep(nanoseconds: delay)
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
        let cleanSymbol = symbol.uppercased().trimmingCharacters(in: .whitespaces)
        let yahooSymbol = cleanSymbol.contains("-") ? cleanSymbol : "\(cleanSymbol)-USD"
        
        let quote = try await fetchQuote(ticker: yahooSymbol)
        
        return YFCryptoQuote(
            symbol: cleanSymbol,
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
        
        // Group assets by type (stock vs crypto)
        let stockAssets = assetsWithTickers.filter { $0.assetClass != .crypto }
        let cryptoAssets = assetsWithTickers.filter { $0.assetClass == .crypto }
        
        // Process stocks in batches of 3 to be respectful to Yahoo Finance
        let batchSize = 3
        
        for batchStart in stride(from: 0, to: stockAssets.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, stockAssets.count)
            let batch = Array(stockAssets[batchStart..<batchEnd])
            
            // Fetch this batch concurrently
            await withTaskGroup(of: (Asset, Double?, Double?).self) { group in
                for asset in batch {
                    guard let ticker = asset.ticker else { continue }
                    
                    group.addTask {
                        do {
                            let quote = try await self.fetchQuote(ticker: ticker)
                            return (asset, quote.latestPrice, quote.changePercent)
                        } catch {
                            print("⚠️ Failed to update \(ticker): \(error.localizedDescription)")
                            return (asset, nil, nil)
                        }
                    }
                }
                
                for await (asset, price, change) in group {
                    if let price = price {
                        let updatedAsset = asset.updatedWithLivePrice(price, change: change)
                        updatedPortfolio.updateAsset(updatedAsset)
                    }
                }
            }
            
            // Small delay between batches to avoid overwhelming Yahoo Finance
            if batchEnd < stockAssets.count {
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3s between batches
            }
        }
        
        // Process crypto in batches too
        for batchStart in stride(from: 0, to: cryptoAssets.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, cryptoAssets.count)
            let batch = Array(cryptoAssets[batchStart..<batchEnd])
            
            await withTaskGroup(of: (Asset, Double?).self) { group in
                for asset in batch {
                    guard let ticker = asset.ticker else { continue }
                    
                    group.addTask {
                        do {
                            let quote = try await self.fetchCryptoQuote(symbol: ticker)
                            return (asset, quote.latestPrice)
                        } catch {
                            print("⚠️ Failed to update \(ticker): \(error.localizedDescription)")
                            return (asset, nil)
                        }
                    }
                }
                
                for await (asset, price) in group {
                    if let price = price {
                        let updatedAsset = asset.updatedWithLivePrice(price, change: nil)
                        updatedPortfolio.updateAsset(updatedAsset)
                    }
                }
            }
            
            // Delay between crypto batches
            if batchEnd < cryptoAssets.count {
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3s between batches
            }
        }
        
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
            return "Invalid response from Yahoo Finance"
        case .httpError(let code):
            return "HTTP error: \(code). Yahoo Finance may be temporarily unavailable."
        case .tickerNotFound(let ticker):
            return "Ticker '\(ticker)' not found on Yahoo Finance. Please verify the symbol is correct."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
