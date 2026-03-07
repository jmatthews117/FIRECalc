//
//  AlternativePriceService.swift
//  FIRECalc
//
//  Fetch prices for assets from Marketstack API
//

import Foundation

actor AlternativePriceService {
    static let shared = AlternativePriceService()
    
    /// Toggle to use Marketstack Test Service instead of real Marketstack (for Phase 1 testing)
    /// Set to true to use mock data, false to use real Marketstack API
    nonisolated(unsafe) static var useMarketstackTest: Bool = false
    
    private init() {}
    
    // MARK: - Main Price Fetcher
    
    /// Fetch price for any asset from API or cache only
    /// - Parameter bypassCooldown: If true, bypasses 12-hour cooldown (for adding new assets)
    /// - Throws: If price cannot be fetched (no hardcoded fallbacks)
    func fetchPrice(for asset: Asset, bypassCooldown: Bool = false) async throws -> Double {
        let (price, _) = try await fetchPriceAndChange(for: asset, bypassCooldown: bypassCooldown)
        return price
    }
    
    /// Fetch both price and daily change percentage for any asset
    /// - Parameter bypassCooldown: If true, bypasses 12-hour cooldown (for adding new assets)
    /// - Throws: If price cannot be fetched (no hardcoded fallbacks)
    func fetchPriceAndChange(for asset: Asset, bypassCooldown: Bool = false) async throws -> (price: Double, changePercent: Double?) {
        guard let ticker = asset.ticker else {
            throw PriceServiceError.noIdentifier
        }
        
        let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        
        AppLogger.debug("🔍 AlternativePriceService fetching price for: \(cleanTicker) (bypass: \(bypassCooldown))")
        
        // Fetch from API or cache - NO hardcoded fallbacks
        let result = try await fetchFromYahooWithChange(for: asset, ticker: cleanTicker, bypassCooldown: bypassCooldown)
        AppLogger.debug("✅ Got price from API/cache: \(cleanTicker) = $\(result.price)")
        return result
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
            return "Unable to fetch price for '\(ticker)'. Check ticker symbol or try again later."
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
