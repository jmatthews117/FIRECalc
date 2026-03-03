//
//  MarketstackConfig.swift
//  FIRECalc
//
//  Remote API key configuration for Marketstack
//  Fetches API key from remote source to allow rotation without app updates
//

import Foundation

actor MarketstackConfig {
    static let shared = MarketstackConfig()
    
    // MARK: - Configuration
    
    /// URL to your remote config file (host this on GitHub, your server, etc.)
    /// Example: https://raw.githubusercontent.com/yourusername/yourrepo/main/config/marketstack.json
    private let remoteConfigURL = "YOUR_REMOTE_CONFIG_URL_HERE"
    
    /// Fallback API key (hardcoded as backup, but rotated remotely)
    /// This is used if remote fetch fails
    private let fallbackAPIKey = "f1d8fa1b993a683099be615d3c37f058"
    
    /// Cache the fetched API key in memory
    private var cachedAPIKey: String?
    private var lastFetchTime: Date?
    
    /// Cache duration (1 hour - fetch new key every hour to stay updated)
    private let cacheDuration: TimeInterval = 3600
    
    private init() {
        print("🔐 MarketstackConfig initialized - will fetch remote API key")
    }
    
    // MARK: - API Key Retrieval
    
    /// Get the current API key (from cache, remote, or fallback)
    func getAPIKey() async -> String {
        // Check cache first
        if let cached = cachedAPIKey,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheDuration {
            print("🔐 Using cached API key")
            return cached
        }
        
        // Try to fetch from remote
        do {
            let remoteKey = try await fetchRemoteAPIKey()
            cachedAPIKey = remoteKey
            lastFetchTime = Date()
            print("🔐 ✅ Fetched API key from remote config")
            return remoteKey
        } catch {
            print("🔐 ⚠️ Failed to fetch remote API key: \(error.localizedDescription)")
            print("🔐 Using fallback API key")
            return fallbackAPIKey
        }
    }
    
    /// Force refresh the API key from remote (useful after rotation)
    func refreshAPIKey() async throws -> String {
        let remoteKey = try await fetchRemoteAPIKey()
        cachedAPIKey = remoteKey
        lastFetchTime = Date()
        print("🔐 ✅ Force refreshed API key from remote")
        return remoteKey
    }
    
    // MARK: - Remote Fetching
    
    private func fetchRemoteAPIKey() async throws -> String {
        guard let url = URL(string: remoteConfigURL) else {
            throw ConfigError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10 // 10 second timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ConfigError.fetchFailed
        }
        
        // Parse JSON response
        let decoder = JSONDecoder()
        let config = try decoder.decode(RemoteConfig.self, from: data)
        
        guard !config.marketstackAPIKey.isEmpty else {
            throw ConfigError.emptyKey
        }
        
        return config.marketstackAPIKey
    }
    
    /// Clear cached key (forces re-fetch on next request)
    func clearCache() {
        cachedAPIKey = nil
        lastFetchTime = nil
        print("🔐 API key cache cleared")
    }
}

// MARK: - Models

private struct RemoteConfig: Codable {
    let marketstackAPIKey: String
    let version: Int?  // Optional versioning
    let active: Bool?  // Optional kill switch
}

enum ConfigError: LocalizedError {
    case invalidURL
    case fetchFailed
    case emptyKey
    case deactivated
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid config URL"
        case .fetchFailed:
            return "Failed to fetch remote config"
        case .emptyKey:
            return "Remote config returned empty API key"
        case .deactivated:
            return "Service deactivated via remote config"
        }
    }
}
