//
//  AlternativePriceService.swift
//  FIRECalc
//
//  Fetch prices for assets not covered by IEX (gold, silver, etc.)
//

import Foundation

actor AlternativePriceService {
    static let shared = AlternativePriceService()
    
    /// Toggle to use Marketstack Test Service instead of real Marketstack (for Phase 1 testing)
    /// Set to true to use mock data, false to use real Marketstack API
    nonisolated(unsafe) static var useMarketstackTest: Bool = false
    
    private init() {}
    
    // MARK: - Price Dictionary (Fallback when no API key)
    
    private let fallbackPrices: [String: Double] = [
        // Major Stocks & ETFs
        "SPY": 485.50, "VTI": 338.19, "QQQ": 415.30, "DIA": 385.20,
        "AAPL": 185.50, "MSFT": 380.20, "AMZN": 155.80, "GOOGL": 140.50,
        "TSLA": 245.30, "NVDA": 495.20, "META": 425.60, "BRK.B": 385.40,
        "UBER": 68.50, "LYFT": 15.20, "NFLX": 485.60, "DIS": 95.30,
        
        // Bonds
        "TLT": 95.40, "LQD": 108.50, "HYG": 76.80, "TIP": 103.20,
        "BND": 72.30, "AGG": 98.50, "VCIT": 79.20, "VCSH": 76.40,
        
        // REITs
        "VNQ": 85.60, "VNQI": 52.30, "O": 58.40, "SPG": 145.20,
        "EQIX": 785.30, "PSA": 295.60, "AMT": 195.40, "PLD": 125.80,
        
        // Precious Metals
        "GLD": 185.70, "SLV": 21.40, "PPLT": 85.20, "PALL": 95.30,
        "IAU": 38.50, "GLTR": 85.60,
        
        // Crypto (approximate USD values)
        "BTC": 42500.00, "ETH": 2250.00, "LTC": 75.00, "BCH": 250.00,
        "ADA": 0.50, "DOT": 7.50, "LINK": 15.00, "XRP": 0.55
    ]
    
    // MARK: - Main Price Fetcher
    
    /// Fetch price for any asset - tries Yahoo Finance API first, falls back to static prices
    /// - Parameter bypassCooldown: If true, bypasses 12-hour cooldown (for adding new assets)
    func fetchPrice(for asset: Asset, bypassCooldown: Bool = false) async throws -> Double {
        let (price, _) = try await fetchPriceAndChange(for: asset, bypassCooldown: bypassCooldown)
        return price
    }
    
    /// Fetch both price and daily change percentage for any asset
    /// - Parameter bypassCooldown: If true, bypasses 12-hour cooldown (for adding new assets)
    func fetchPriceAndChange(for asset: Asset, bypassCooldown: Bool = false) async throws -> (price: Double, changePercent: Double?) {
        guard let ticker = asset.ticker else {
            throw PriceServiceError.noIdentifier
        }
        
        let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        
        print("🔍 AlternativePriceService fetching price for: \(cleanTicker) (bypass: \(bypassCooldown))")
        
        // Try Yahoo Finance first (no API key needed!)
        do {
            let result = try await fetchFromYahooWithChange(for: asset, ticker: cleanTicker, bypassCooldown: bypassCooldown)
            print("✅ Got price from Marketstack/Yahoo: \(cleanTicker) = $\(result.price)")
            return result
        } catch {
            print("⚠️ Marketstack/Yahoo failed for \(cleanTicker): \(error.localizedDescription)")
            print("   Falling back to hardcoded price...")
            
            // Use fallback prices (no change data available)
            let fallbackPrice = try fetchFromFallback(ticker: cleanTicker)
            print("📦 Using fallback price: \(cleanTicker) = $\(fallbackPrice)")
            return (fallbackPrice, nil)
        }
    }
    
    private func fetchFromYahoo(for asset: Asset, ticker: String, bypassCooldown: Bool = false) async throws -> Double {
        let (price, _) = try await fetchFromYahooWithChange(for: asset, ticker: ticker, bypassCooldown: bypassCooldown)
        return price
    }
    
    private func fetchFromYahooWithChange(for asset: Asset, ticker: String, bypassCooldown: Bool = false) async throws -> (price: Double, changePercent: Double?) {
        // PHASE 1/2: Use Marketstack Test Service if enabled
        if AlternativePriceService.useMarketstackTest {
            let testService = MarketstackTestService.shared
            
            switch asset.assetClass {
            case .crypto:
                let quote = try await testService.fetchCryptoQuote(symbol: ticker)
                return (quote.latestPrice, nil)
                
            case .stocks, .bonds, .reits, .preciousMetals:
                let quote = try await testService.fetchQuote(ticker: ticker)
                return (quote.latestPrice, quote.changePercent)
                
            default:
                throw PriceServiceError.noPricingAvailable
            }
        }
        
        // PRODUCTION: Use Real Marketstack (Phase 2)
        let marketstackService = MarketstackService.shared
        
        switch asset.assetClass {
        case .crypto:
            // Note: Marketstack free tier may not support crypto
            do {
                let quote = try await marketstackService.fetchCryptoQuote(symbol: ticker, bypassCooldown: bypassCooldown)
                return (quote.latestPrice, nil)
            } catch {
                // Crypto not supported on free tier - throw error
                throw PriceServiceError.noPricingAvailable
            }
            
        case .stocks, .bonds, .reits, .preciousMetals:
            let quote = try await marketstackService.fetchQuote(ticker: ticker, bypassCooldown: bypassCooldown)
            return (quote.latestPrice, quote.changePercent)
            
        default:
            throw PriceServiceError.noPricingAvailable
        }
    }
    
    private func fetchFromFallback(ticker: String) throws -> Double {
        guard let price = fallbackPrices[ticker] else {
            throw PriceServiceError.tickerNotFound(ticker)
        }
        return price
    }
}

// MARK: - Models

struct MetalPrice {
    let metal: String
    let price: Double
    let currency: String
    let unit: String
    let lastUpdate: Date
    let changePercent: Double?
}

struct BondPrice {
    let ticker: String
    let price: Double
    let yield: Double?
    let lastUpdate: Date
    let changePercent: Double?
}

struct REITPrice {
    let ticker: String
    let price: Double
    let lastUpdate: Date
    let changePercent: Double?
}

// MARK: - Errors

enum PriceServiceError: LocalizedError {
    case noIdentifier
    case unsupportedMetal(String)
    case noPricingAvailable
    case invalidResponse
    case tickerNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .noIdentifier:
            return "No ticker symbol or identifier provided for this asset"
        case .unsupportedMetal(let metal):
            return "Pricing not available for \(metal). Try using an ETF ticker like GLD for gold."
        case .noPricingAvailable:
            return "Live pricing not available for this asset type"
        case .invalidResponse:
            return "Invalid response from pricing service"
        case .tickerNotFound(let ticker):
            return "Ticker '\(ticker)' not found. Using fallback prices - add IEX API key in Settings for live data."
        }
    }
}

// MARK: - Common Ticker Reference

struct CommonTickers {
    // Precious Metal ETFs
    static let gold = "GLD"           // SPDR Gold Shares
    static let silver = "SLV"         // iShares Silver Trust
    static let platinum = "PPLT"      // Aberdeen Platinum ETF
    static let palladium = "PALL"     // Aberdeen Palladium ETF
    
    // Bond ETFs
    static let treasuryBonds = "TLT"  // 20+ Year Treasury Bond ETF
    static let corpBonds = "LQD"      // Investment Grade Corporate Bond ETF
    static let highYield = "HYG"      // High Yield Corporate Bond ETF
    static let tips = "TIP"           // Treasury Inflation-Protected Securities
    
    // REIT ETFs
    static let reitIndex = "VNQ"      // Vanguard Real Estate ETF
    static let globalReit = "VNQI"    // Vanguard Global Real Estate ETF
    
    // Crypto
    static let bitcoin = "BTC"
    static let ethereum = "ETH"
    static let bitcoinCash = "BCH"
    static let litecoin = "LTC"
    
    // Stock Index ETFs
    static let sp500 = "SPY"          // S&P 500 ETF
    static let nasdaq = "QQQ"         // Nasdaq 100 ETF
    static let dowJones = "DIA"       // Dow Jones Industrial Average ETF
    static let totalMarket = "VTI"    // Total Stock Market ETF
}
