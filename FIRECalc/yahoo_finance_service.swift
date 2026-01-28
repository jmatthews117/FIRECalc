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
    
    // MARK: - Quote Fetching
    
    /// Fetch current price for a single ticker
    func fetchQuote(ticker: String) async throws -> YFStockQuote {
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
    
    /// Fetch quotes for multiple tickers
    func fetchBatchQuotes(tickers: [String]) async throws -> [String: YFStockQuote] {
        guard !tickers.isEmpty else { return [:] }
        
        var quotes: [String: YFStockQuote] = [:]
        
        for ticker in tickers {
            do {
                let quote = try await fetchQuote(ticker: ticker)
                quotes[ticker.uppercased()] = quote
                try await Task.sleep(nanoseconds: 200_000_000)
            } catch {
                print("⚠️ Failed to fetch \(ticker): \(error.localizedDescription)")
                continue
            }
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
        
        print("🔄 Updating \(assetsWithTickers.count) assets...")
        
        for asset in assetsWithTickers {
            guard let ticker = asset.ticker else { continue }
            
            do {
                if asset.assetClass == .crypto {
                    let quote = try await fetchCryptoQuote(symbol: ticker)
                    let updatedAsset = asset.updatedWithLivePrice(quote.latestPrice, change: nil)
                    updatedPortfolio.updateAsset(updatedAsset)
                } else {
                    let quote = try await fetchQuote(ticker: ticker)
                    let updatedAsset = asset.updatedWithLivePrice(
                        quote.latestPrice,
                        change: quote.changePercent
                    )
                    updatedPortfolio.updateAsset(updatedAsset)
                }
                
                try await Task.sleep(nanoseconds: 200_000_000)
            } catch {
                print("⚠️ Failed to update \(ticker): \(error.localizedDescription)")
                continue
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
