//
//  MarketstackConfig.swift
//  FIRECalc
//
//  Backend proxy configuration for Marketstack API
//  App communicates with your backend, which securely stores the API key
//

import Foundation

actor MarketstackConfig {
    static let shared = MarketstackConfig()
    
    // MARK: - Configuration
    
    /// Your backend proxy URL (deployed on Render, Heroku, Cloudflare, etc.)
    /// Example: https://firecalc-proxy.onrender.com
    /// TODO: Update this with your actual backend URL after deployment
    private let backendURL = "https://firecalc-backend.onrender.com"
    
    /// No API key needed in the app! It's stored securely on your backend.
    
    private init() {
        print("🔐 MarketstackConfig initialized - using secure backend proxy")
    }
    
    // MARK: - API Methods
    
    /// Fetch a single stock quote from backend
    func fetchQuote(symbol: String) async throws -> MarketstackQuote {
        let urlString = "\(backendURL)/api/quote/\(symbol)"
        guard let url = URL(string: urlString) else {
            throw ConfigError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.httpMethod = "GET"
        request.setValue("FIRECalc_2026_SecretKey_8j3k2h1k9", forHTTPHeaderField: "x-api-key") // ← ADD THIS LINE
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConfigError.fetchFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            // Try to parse error message from backend
            if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                throw ConfigError.backendError(errorResponse.error)
            }
            throw ConfigError.fetchFailed
        }
        
        // Decode the response (uses existing MarketstackAPIResponse from MarketstackService)
        let apiResponse = try JSONDecoder().decode(BackendAPIResponse.self, from: data)
        
        guard let quote = apiResponse.data.first else {
            throw ConfigError.noDataAvailable
        }
        
        return quote
    }
    
    /// Fetch multiple stock quotes (batch request) from backend
    func fetchQuotes(symbols: [String]) async throws -> [MarketstackQuote] {
        let symbolsString = symbols.joined(separator: ",")
        let urlString = "\(backendURL)/api/quotes?symbols=\(symbolsString)"
        
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            throw ConfigError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.httpMethod = "GET"
        request.setValue("FIRECalc_2026_SecretKey_8j3k2h1k9", forHTTPHeaderField: "x-api-key") // ← ADD THIS LINE
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConfigError.fetchFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                throw ConfigError.backendError(errorResponse.error)
            }
            throw ConfigError.fetchFailed
        }
        
        // Decode the response
        let apiResponse = try JSONDecoder().decode(BackendAPIResponse.self, from: data)
        return apiResponse.data
    }
}

// MARK: - Backend Response Models

/// Response structure from our backend (matches Marketstack API format)
private struct BackendAPIResponse: Codable {
    let data: [MarketstackQuote]
    let pagination: BackendPagination?
}

private struct BackendPagination: Codable {
    let limit: Int
    let offset: Int
    let count: Int
    let total: Int
}

/// Error response from backend
private struct BackendErrorResponse: Codable {
    let error: String
}

enum ConfigError: LocalizedError {
    case invalidURL
    case fetchFailed
    case backendError(String)
    case noDataAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL"
        case .fetchFailed:
            return "Failed to fetch from backend"
        case .backendError(let message):
            return "Backend error: \(message)"
        case .noDataAvailable:
            return "No data available from backend"
        }
    }
}
