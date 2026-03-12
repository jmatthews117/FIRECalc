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
        print("🔐 Backend URL: \(backendURL)")
        print("🔐 Ready to make API calls")
    }
    
    // MARK: - API Methods
    
    /// Fetch a single stock quote from backend (with 2 days of data for accurate daily change)
    func fetchQuote(symbol: String) async throws -> MarketstackQuote {
        let urlString = "\(backendURL)/api/quote/\(symbol)"
        
        print("🌐 [CONFIG] Fetching single quote for: \(symbol)")
        
        guard let url = URL(string: urlString) else {
            print("❌ [CONFIG] Invalid URL: \(urlString)")
            throw ConfigError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 90 // Increased for Render free tier cold-starts
        request.httpMethod = "GET"
        request.setValue("FIRECalc_2026_SecretKey_8j3k2h1k9", forHTTPHeaderField: "x-api-key")
        
        print("🌐 [CONFIG] Sending request (timeout: 90s)...")
        let startTime = Date()
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsed = Date().timeIntervalSince(startTime)
            print("🌐 [CONFIG] Response received in \(String(format: "%.2f", elapsed))s")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [CONFIG] Response is not HTTP")
                throw ConfigError.fetchFailed
            }
            
            print("🌐 [CONFIG] HTTP Status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                // Try to parse error message from backend
                if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                    print("❌ [CONFIG] Backend error: \(errorResponse.error)")
                    throw ConfigError.backendError(errorResponse.error)
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ [CONFIG] Raw response: \(responseString.prefix(200))")
                }
                
                throw ConfigError.fetchFailed
            }
            
            // Decode the response (backend now returns 2 days of data with limit=2)
            let apiResponse = try JSONDecoder().decode(BackendAPIResponse.self, from: data)
            
            // Backend processes the data and returns only today's quote (first element)
            // but with previousClose, dailyChange, and dailyChangePercent calculated
            guard let quote = apiResponse.data.first else {
                print("❌ [CONFIG] No quote data in response")
                throw ConfigError.noDataAvailable
            }
            
            // Log the daily change if available
            if let previousClose = quote.previousClose {
                let change = quote.close - previousClose
                let changePercent = (change / previousClose) * 100
                print("✅ [CONFIG] Successfully fetched quote for \(symbol): $\(quote.close) (\(change >= 0 ? "+" : "")\(String(format: "%.2f", changePercent))%)")
            } else {
                print("✅ [CONFIG] Successfully fetched quote for \(symbol): $\(quote.close)")
            }
            
            return quote
            
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            print("❌ [CONFIG] Request failed after \(String(format: "%.2f", elapsed))s")
            print("❌ [CONFIG] Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch multiple stock quotes (batch request) from backend
    func fetchQuotes(symbols: [String]) async throws -> [MarketstackQuote] {
        let symbolsString = symbols.joined(separator: ",")
        let urlString = "\(backendURL)/api/quotes?symbols=\(symbolsString)"
        
        print("🌐 [CONFIG] Building request URL...")
        print("🌐 [CONFIG] Backend: \(backendURL)")
        print("🌐 [CONFIG] Symbols: \(symbols.prefix(5).joined(separator: ", "))\(symbols.count > 5 ? "... (\(symbols.count) total)" : "")")
        
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            print("❌ [CONFIG] Failed to build URL from: \(urlString)")
            throw ConfigError.invalidURL
        }
        
        print("🌐 [CONFIG] Request URL: \(url.absoluteString.prefix(100))...")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 120 // Increased for Render free tier cold-starts (28 symbols can take time)
        request.httpMethod = "GET"
        request.setValue("FIRECalc_2026_SecretKey_8j3k2h1k9", forHTTPHeaderField: "x-api-key")
        
        print("🌐 [CONFIG] Sending request (timeout: 120s)...")
        let startTime = Date()
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsed = Date().timeIntervalSince(startTime)
            print("🌐 [CONFIG] Response received in \(String(format: "%.2f", elapsed))s")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [CONFIG] Response is not HTTP")
                throw ConfigError.fetchFailed
            }
            
            print("🌐 [CONFIG] HTTP Status: \(httpResponse.statusCode)")
            print("🌐 [CONFIG] Data size: \(data.count) bytes")
            
            guard httpResponse.statusCode == 200 else {
                // Try to parse error message from backend
                if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                    print("❌ [CONFIG] Backend error: \(errorResponse.error)")
                    throw ConfigError.backendError(errorResponse.error)
                }
                
                // Try to print raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ [CONFIG] Raw response: \(responseString.prefix(200))")
                }
                
                throw ConfigError.fetchFailed
            }
            
            // Decode the response
            print("🌐 [CONFIG] Decoding JSON...")
            let apiResponse = try JSONDecoder().decode(BackendAPIResponse.self, from: data)
            print("✅ [CONFIG] Successfully decoded \(apiResponse.data.count) quotes")
            
            return apiResponse.data
            
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            print("❌ [CONFIG] Request failed after \(String(format: "%.2f", elapsed))s")
            print("❌ [CONFIG] Error: \(error.localizedDescription)")
            
            if let urlError = error as? URLError {
                print("❌ [CONFIG] URLError code: \(urlError.code.rawValue)")
                print("❌ [CONFIG] URLError description: \(urlError.localizedDescription)")
            }
            
            throw error
        }
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
