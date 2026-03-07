//
//  DebugLogger.swift
//  FIRECalc
//
//  Centralized debugging system for portfolio refresh operations
//

import Foundation

/// Centralized debug logging system with categories and verbosity control
actor DebugLogger {
    static let shared = DebugLogger()
    
    /// Control which debug categories are logged
    enum Category: String {
        case refresh = "🔄 REFRESH"
        case api = "📡 API"
        case cache = "💾 CACHE"
        case pricing = "💰 PRICING"
        case subscription = "💳 SUBSCRIPTION"
        case cooldown = "⏳ COOLDOWN"
        case batch = "📦 BATCH"
        case error = "❌ ERROR"
        case success = "✅ SUCCESS"
        case warning = "⚠️ WARNING"
        case performance = "⚡ PERFORMANCE"
    }
    
    /// Verbosity level for logging
    enum Verbosity: Int, Comparable {
        case silent = 0      // No logs
        case errors = 1      // Only errors
        case important = 2   // Errors + warnings + major operations
        case detailed = 3    // All operations and state changes
        case verbose = 4     // Everything including detailed calculations
        
        static func < (lhs: Verbosity, rhs: Verbosity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Current verbosity level - change this to control logging
    private(set) var verbosityLevel: Verbosity = .detailed
    
    /// Enabled categories - only these will be logged
    private var enabledCategories: Set<Category> = [
        .refresh,
        .api,
        .cache,
        .cooldown,
        .batch,
        .error,
        .success,
        .warning,
        .performance
    ]
    
    // MARK: - Configuration
    
    func setVerbosity(_ level: Verbosity) {
        verbosityLevel = level
        print("🔧 Debug verbosity set to: \(level)")
    }
    
    func enableCategory(_ category: Category) {
        enabledCategories.insert(category)
    }
    
    func disableCategory(_ category: Category) {
        enabledCategories.remove(category)
    }
    
    func enableAllCategories() {
        enabledCategories = Set(Category.allCases)
    }
    
    func disableAllCategories() {
        enabledCategories.removeAll()
        verbosityLevel = .silent
    }
    
    // MARK: - Logging Methods
    
    func log(_ category: Category, _ message: String, verbosity: Verbosity = .detailed) {
        guard verbosity <= verbosityLevel else { return }
        guard enabledCategories.contains(category) else { return }
        
        let timestamp = formatTimestamp(Date())
        print("[\(timestamp)] \(category.rawValue) \(message)")
    }
    
    func logError(_ message: String, error: Error? = nil) {
        log(.error, message, verbosity: .errors)
        if let error = error {
            log(.error, "  └─ \(error.localizedDescription)", verbosity: .errors)
        }
    }
    
    func logSuccess(_ message: String) {
        log(.success, message, verbosity: .important)
    }
    
    func logWarning(_ message: String) {
        log(.warning, message, verbosity: .important)
    }
    
    // MARK: - Specialized Logging for Refresh Operations
    
    func logRefreshStart(assetCount: Int, bypassCooldown: Bool) {
        log(.refresh, "════════════════════════════════════════", verbosity: .important)
        log(.refresh, "Starting portfolio refresh", verbosity: .important)
        log(.refresh, "Assets to update: \(assetCount)", verbosity: .important)
        log(.refresh, "Bypass cooldown: \(bypassCooldown)", verbosity: .important)
        log(.refresh, "════════════════════════════════════════", verbosity: .important)
    }
    
    func logRefreshComplete(successCount: Int, failCount: Int, totalCount: Int, duration: TimeInterval) {
        log(.refresh, "════════════════════════════════════════", verbosity: .important)
        log(.refresh, "Refresh complete in \(String(format: "%.2f", duration))s", verbosity: .important)
        log(.refresh, "Success: \(successCount)/\(totalCount)", verbosity: .important)
        log(.refresh, "Failed: \(failCount)/\(totalCount)", verbosity: .important)
        if failCount > 0 {
            log(.refresh, "Success rate: \(String(format: "%.1f", Double(successCount) / Double(totalCount) * 100))%", verbosity: .important)
        }
        log(.refresh, "════════════════════════════════════════", verbosity: .important)
    }
    
    func logBatchStart(batchIndex: Int, totalBatches: Int, assetsInBatch: Int) {
        log(.batch, "────────────────────────────────────────", verbosity: .detailed)
        log(.batch, "Batch \(batchIndex)/\(totalBatches) - Processing \(assetsInBatch) assets", verbosity: .detailed)
    }
    
    func logBatchComplete(batchIndex: Int, totalBatches: Int, successCount: Int, failCount: Int) {
        log(.batch, "Batch \(batchIndex)/\(totalBatches) complete - ✅ \(successCount) | ❌ \(failCount)", verbosity: .detailed)
        log(.batch, "────────────────────────────────────────", verbosity: .detailed)
    }
    
    func logAssetUpdate(ticker: String, price: Double, success: Bool, error: Error? = nil) {
        if success {
            log(.success, "[\(ticker)] Updated to $\(formatPrice(price))", verbosity: .detailed)
        } else {
            log(.error, "[\(ticker)] Failed to update", verbosity: .important)
            if let error = error {
                log(.error, "  └─ \(error.localizedDescription)", verbosity: .detailed)
            }
        }
    }
    
    func logAPICall(ticker: String, bypassCooldown: Bool) {
        log(.api, "Fetching price for '\(ticker)' (bypass: \(bypassCooldown))", verbosity: .verbose)
    }
    
    func logAPICallComplete(ticker: String, price: Double?, cached: Bool) {
        if let price = price {
            let source = cached ? "from cache" : "from API"
            log(.api, "[\(ticker)] Got $\(formatPrice(price)) \(source)", verbosity: .verbose)
        } else {
            log(.api, "[\(ticker)] No price available", verbosity: .detailed)
        }
    }
    
    func logCooldownStatus(canRefresh: Bool, nextRefreshDate: Date?, remainingTime: TimeInterval?) {
        if canRefresh {
            log(.cooldown, "Refresh available now", verbosity: .important)
        } else if let remaining = remainingTime {
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            log(.cooldown, "Next refresh in \(hours)h \(minutes)m", verbosity: .important)
            if let nextDate = nextRefreshDate {
                log(.cooldown, "Next refresh at: \(formatTimestamp(nextDate))", verbosity: .detailed)
            }
        }
    }
    
    func logCacheStats(cachedCount: Int, hitRate: Double) {
        log(.cache, "Cache stats: \(cachedCount) entries, \(String(format: "%.1f", hitRate * 100))% hit rate", verbosity: .detailed)
    }
    
    func logSubscriptionStatus(isPro: Bool) {
        if isPro {
            log(.subscription, "Pro subscriber - full access", verbosity: .detailed)
        } else {
            log(.subscription, "Free tier - stock updates disabled", verbosity: .important)
        }
    }
    
    func logPerformanceMetric(operation: String, duration: TimeInterval) {
        log(.performance, "[\(operation)] completed in \(String(format: "%.3f", duration))s", verbosity: .verbose)
    }
    
    // MARK: - Diagnostic Reports
    
    func generateRefreshDiagnostic(
        assetCount: Int,
        successCount: Int,
        failCount: Int,
        failedTickers: [String],
        duration: TimeInterval,
        bypassCooldown: Bool,
        cooldownRemaining: TimeInterval?
    ) {
        print("\n" + String(repeating: "=", count: 60))
        print("📊 REFRESH DIAGNOSTIC REPORT")
        print(String(repeating: "=", count: 60))
        print("")
        print("CONFIGURATION:")
        print("  • Total assets: \(assetCount)")
        print("  • Bypass cooldown: \(bypassCooldown)")
        print("  • Verbosity: \(verbosityLevel)")
        print("")
        print("RESULTS:")
        print("  • Duration: \(String(format: "%.2f", duration))s")
        print("  • Success: \(successCount)/\(assetCount) (\(String(format: "%.1f", Double(successCount) / Double(assetCount) * 100))%)")
        print("  • Failed: \(failCount)/\(assetCount)")
        print("")
        if !failedTickers.isEmpty {
            print("FAILED TICKERS:")
            for ticker in failedTickers.prefix(10) {
                print("  • \(ticker)")
            }
            if failedTickers.count > 10 {
                print("  ... and \(failedTickers.count - 10) more")
            }
            print("")
        }
        if let remaining = cooldownRemaining {
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            print("COOLDOWN STATUS:")
            print("  • Next refresh in: \(hours)h \(minutes)m")
            print("")
        }
        print("RECOMMENDATIONS:")
        if failCount > assetCount / 2 {
            print("  ⚠️  More than 50% of assets failed to update")
            print("  → Check network connectivity")
            print("  → Verify ticker symbols are correct")
            print("  → Check API usage limits")
        } else if failCount > 0 {
            print("  ℹ️  Some assets failed to update")
            print("  → Review failed tickers above")
            print("  → Verify ticker symbols on Yahoo Finance")
        } else {
            print("  ✅ All assets updated successfully!")
        }
        print("")
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    // MARK: - Helper Methods
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func formatPrice(_ price: Double) -> String {
        String(format: "%.2f", price)
    }
}

// MARK: - Category CaseIterable

extension DebugLogger.Category: CaseIterable {}

// MARK: - Convenience Logging Functions (for use in other files)

/// Log a refresh operation message
func logRefresh(_ message: String, verbosity: DebugLogger.Verbosity = .detailed) {
    Task {
        await DebugLogger.shared.log(.refresh, message, verbosity: verbosity)
    }
}

/// Log an API operation message
func logAPI(_ message: String, verbosity: DebugLogger.Verbosity = .detailed) {
    Task {
        await DebugLogger.shared.log(.api, message, verbosity: verbosity)
    }
}

/// Log a cache operation message
func logCache(_ message: String, verbosity: DebugLogger.Verbosity = .detailed) {
    Task {
        await DebugLogger.shared.log(.cache, message, verbosity: verbosity)
    }
}

/// Log an error message
func logError(_ message: String, error: Error? = nil) {
    Task {
        await DebugLogger.shared.logError(message, error: error)
    }
}

/// Log a success message
func logSuccess(_ message: String) {
    Task {
        await DebugLogger.shared.logSuccess(message)
    }
}

/// Log a warning message
func logWarning(_ message: String) {
    Task {
        await DebugLogger.shared.logWarning(message)
    }
}
