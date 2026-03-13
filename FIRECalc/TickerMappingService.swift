//
//  TickerMappingService.swift
//  FIRECalc
//
//  Handles mapping of mutual funds and crypto to ETF alternatives
//  Prevents unnecessary API calls for unsupported asset types
//

import Foundation

// MARK: - Mapping Models

struct TickerMapping: Codable {
    let name: String
    let etfAlternative: String
    let etfName: String
    let reason: String
}

struct TickerMappings: Codable {
    let mutualFunds: [String: TickerMapping]
    let crypto: [String: TickerMapping]
}

// MARK: - Mapping Result

enum TickerMappingResult {
    case supported(ticker: String)
    case unsupportedMutualFund(original: String, mapping: TickerMapping)
    case unsupportedCrypto(original: String, mapping: TickerMapping)
    case unknown(ticker: String)
    
    var shouldFetchPrice: Bool {
        if case .supported = self {
            return true
        }
        return false
    }
    
    var displayTicker: String {
        switch self {
        case .supported(let ticker):
            return ticker
        case .unsupportedMutualFund(let original, _):
            return original
        case .unsupportedCrypto(let original, _):
            return original
        case .unknown(let ticker):
            return ticker
        }
    }
}

// MARK: - Service

actor TickerMappingService {
    static let shared = TickerMappingService()
    
    private var mappings: TickerMappings?
    
    private init() {
        Task {
            await loadMappings()
        }
    }
    
    // MARK: - Loading
    
    private func loadMappings() {
        guard let url = Bundle.main.url(forResource: "TickerMappings (2)", withExtension: "json") else {
            print("⚠️ TickerMappings (2).json not found in bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            mappings = try decoder.decode(TickerMappings.self, from: data)
            
            let mfCount = mappings?.mutualFunds.count ?? 0
            let cryptoCount = mappings?.crypto.count ?? 0
            print("✅ Loaded ticker mappings: \(mfCount) mutual funds, \(cryptoCount) crypto")
        } catch {
            print("❌ Failed to load TickerMappings.json: \(error)")
        }
    }
    
    // MARK: - Public API
    
    /// Check if a ticker is supported or needs to be mapped to an ETF alternative
    func checkTicker(_ ticker: String) -> TickerMappingResult {
        let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        
        guard let mappings = mappings else {
            // Mappings not loaded yet - assume supported
            return .supported(ticker: cleanTicker)
        }
        
        // Check mutual funds
        if let mapping = mappings.mutualFunds[cleanTicker] {
            print("🔄 Mutual fund detected: \(cleanTicker) → suggest \(mapping.etfAlternative)")
            return .unsupportedMutualFund(original: cleanTicker, mapping: mapping)
        }
        
        // Check crypto
        if let mapping = mappings.crypto[cleanTicker] {
            print("🔄 Crypto detected: \(cleanTicker) → suggest \(mapping.etfAlternative)")
            return .unsupportedCrypto(original: cleanTicker, mapping: mapping)
        }
        
        // Not in our mappings - assume it's a supported stock/ETF
        return .supported(ticker: cleanTicker)
    }
    
    /// Get a user-friendly message explaining why a ticker is not supported
    func getUnsupportedMessage(for result: TickerMappingResult) -> String? {
        switch result {
        case .unsupportedMutualFund(let original, let mapping):
            return """
            \(original) is a mutual fund and cannot be tracked via live prices.
            
            Consider using \(mapping.etfAlternative) (\(mapping.etfName)) instead.
            
            Why? \(mapping.reason)
            """
            
        case .unsupportedCrypto(let original, let mapping):
            return """
            \(original) is a cryptocurrency and cannot be tracked via stock market APIs.
            
            Consider using \(mapping.etfAlternative) (\(mapping.etfName)) instead.
            
            Why? \(mapping.reason)
            """
            
        case .supported, .unknown:
            return nil
        }
    }
    
    /// Get the suggested ETF alternative for a ticker (if any)
    func getSuggestedAlternative(for ticker: String) -> (etf: String, name: String)? {
        let result = checkTicker(ticker)
        
        switch result {
        case .unsupportedMutualFund(_, let mapping):
            return (mapping.etfAlternative, mapping.etfName)
        case .unsupportedCrypto(_, let mapping):
            return (mapping.etfAlternative, mapping.etfName)
        case .supported, .unknown:
            return nil
        }
    }
}
