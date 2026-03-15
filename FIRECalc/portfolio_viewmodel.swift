//
//  PortfolioViewModel.swift
//  FIRECalc
//
//  Manages portfolio state and operations.
//  Retirement-planning values (age, spend, withdrawal rate) are stored in
//  UserDefaults and read via @AppStorage in the views that need them, so they
//  are NOT duplicated as @Published properties here.
//

import Foundation
import SwiftUI

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var portfolio: Portfolio
    @Published var isUpdatingPrices: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var lastSuccessfulRefresh: Date?
    
    private let persistence = PersistenceService.shared
    /// Kept so that rapid successive operations cancel the previous auto-dismiss.
    private var clearMessageTask: Task<Void, Never>?
    /// Debounce saves to reduce I/O
    private var saveTask: Task<Void, Never>?
    /// PERFORMANCE FIX: Debounce price refresh requests
    private var refreshTask: Task<Void, Never>?
    private var lastRefreshTime: Date?
    
    // MARK: - Computed Property Caching
    
    private var cachedAllocation: [(AssetClass, Double)]?
    private var lastPortfolioHash: Int?
    
    // MARK: - UserDefaults Keys
    
    private let lastRefreshKey = "portfolio_last_successful_refresh"
    
    init(portfolio: Portfolio? = nil) {
        if let savedPortfolio = try? persistence.loadPortfolio() {
            self.portfolio = savedPortfolio
        } else if let provided = portfolio {
            self.portfolio = provided
        } else {
            self.portfolio = Portfolio(name: "My Portfolio")
        }
        
        // Load last successful refresh timestamp
        let timestamp = UserDefaults.standard.double(forKey: lastRefreshKey)
        if timestamp > 0 {
            self.lastSuccessfulRefresh = Date(timeIntervalSince1970: timestamp)
        }
        
        // PHASE 2: Enable REAL Marketstack (set to true for test mode)
        AlternativePriceService.useMarketstackTest = false
        print("📡 LIVE MODE - Using real Marketstack API with 15-min cache")
        
        // Automatically refresh prices on launch if we have stale data
        // SUBSCRIPTION FIX: Wait for subscription status to load first to avoid
        // showing "must upgrade" error to paid users on startup
        Task {
            // Give SubscriptionManager time to load subscription status
            // This prevents race condition where refresh happens before subscription check completes
            try? await Task.sleep(for: .seconds(0.5))
            await refreshPricesIfNeeded()
        }
    }
    
    /// Refresh prices only if data is stale (older than 1 hour)
    func refreshPricesIfNeeded() async {
        // PERFORMANCE FIX: Prevent multiple simultaneous refresh attempts
        if isUpdatingPrices {
            return
        }
        
        // PERFORMANCE FIX: Don't refresh if we just did it recently (within 5 minutes)
        if let lastRefresh = lastRefreshTime, Date().timeIntervalSince(lastRefresh) < 300 {
            return
        }
        
        let assetsNeedingUpdate = portfolio.assetsNeedingPriceUpdate
        let assetsWithoutPrices = portfolio.assetsWithTickers.filter { $0.currentPrice == nil }
        
        guard !assetsNeedingUpdate.isEmpty || !assetsWithoutPrices.isEmpty else {
            return
        }
        
        // SUBSCRIPTION FIX: For automatic refresh, check subscription status silently
        // Don't show error message since this is background refresh, not user-initiated
        let subscriptionManager = SubscriptionManager.shared
        
        // If subscription manager is still loading, wait briefly
        if subscriptionManager.isLoading {
            // Wait up to 1 second for subscription status to load
            for _ in 0..<10 {
                if !subscriptionManager.isLoading {
                    break
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        
        // Silently skip if not a pro subscriber (don't show error for automatic refresh)
        guard subscriptionManager.isProSubscriber else {
            return
        }
        
        await refreshPrices()
    }
    
    // MARK: - Asset Management
    
    /// Check if an asset with the given name already exists (case-insensitive)
    func assetExists(withName name: String) -> Bool {
        portfolio.assets.contains { $0.name.lowercased() == name.lowercased() }
    }
    
    /// Find an existing asset by name (case-insensitive)
    func existingAsset(withName name: String) -> Asset? {
        portfolio.assets.first { $0.name.lowercased() == name.lowercased() }
    }
    
    func addAsset(_ asset: Asset) {
        portfolio.addAsset(asset)
        invalidateCache()
        savePortfolio()
        show(success: "Asset added successfully")
    }
    
    func updateAsset(_ asset: Asset) {
        portfolio.updateAsset(asset)
        invalidateCache()
        savePortfolio()
        show(success: "Asset updated successfully")
    }
    
    func deleteAsset(_ asset: Asset) {
        portfolio.removeAsset(asset)
        invalidateCache()
        savePortfolio()
        show(success: "Asset deleted")
    }
    
    func deleteAssets(at offsets: IndexSet) {
        portfolio.removeAssets(at: offsets)
        invalidateCache()
        savePortfolio()
        show(success: "Assets deleted")
    }
    
    private func savePortfolio() {
        // Cancel any pending save and debounce
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            
            do {
                try persistence.savePortfolio(portfolio)
            } catch {
                show(error: "Failed to save: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Price Updates
    
    func refreshPrices() async {
        // SUBSCRIPTION CHECK: Free users cannot refresh prices
        // SUBSCRIPTION FIX: Skip check if subscription manager is still loading (isLoading)
        // to avoid false negatives during app startup
        let subscriptionManager = SubscriptionManager.shared
        
        // If subscription manager is loading, wait briefly for it to complete
        if subscriptionManager.isLoading {
            // Wait up to 1 second for subscription status to load
            for _ in 0..<10 {
                if !subscriptionManager.isLoading {
                    break
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        
        // Now check subscription status
        guard subscriptionManager.isProSubscriber else {
            show(error: "Stock price updates require FIRECalc Pro. Upgrade to access live portfolio tracking.")
            return
        }
        
        // PERFORMANCE FIX: Cancel any pending refresh and debounce rapid calls
        refreshTask?.cancel()
        
        // Don't allow overlapping refreshes
        guard !isUpdatingPrices else {
            return
        }
        
        // Create new refresh task - manual refresh does NOT bypass cooldown
        // The 12-hour cooldown applies to ALL refreshes to conserve API usage
        refreshTask = Task { @MainActor in
            await performRefresh(bypassCooldown: false)
        }
        
        await refreshTask?.value
    }
    
    private func performRefresh(bypassCooldown: Bool = false) async {
        // Start timing for performance metrics
        let startTime = Date()
        
        // Get ALL assets with tickers - no limit on number of assets
        let assetsToUpdate = portfolio.assetsWithTickers.filter { $0.ticker != nil }
        
        AppLogger.debug("════════════════════════════════════════")
        AppLogger.debug("🔄 REFRESH: Starting portfolio refresh")
        AppLogger.debug("🔄 REFRESH: Assets to update: \(assetsToUpdate.count)")
        AppLogger.debug("🔄 REFRESH: Bypass cooldown: \(bypassCooldown)")
        AppLogger.debug("🔄 REFRESH: Using BATCH API (1 call for all assets)")
        AppLogger.debug("════════════════════════════════════════")
        
        // PERFORMANCE FIX: Record when we started this refresh
        lastRefreshTime = Date()
        
        guard !portfolio.assetsWithTickers.isEmpty else {
            return
        }
        
        isUpdatingPrices = true
        errorMessage = nil
        
        var successCount = 0
        var failCount = 0
        var failedTickers: [String] = []
        
        // OPTIMIZATION: Use MarketstackService batch API to fetch ALL quotes in ONE request
        // This is much more efficient than individual requests
        do {
            // Extract all tickers
            let tickers = assetsToUpdate.compactMap { $0.ticker }
            AppLogger.debug("📡 BATCH API: Fetching \(tickers.count) tickers in single request")
            
            // Fetch all quotes in one batch (1 API call!)
            // Note: This will respect/bypass cooldown based on the bypassCooldown parameter
            let quotes = try await MarketstackService.shared.fetchBatchQuotes(tickers: tickers)
            
            AppLogger.debug("📡 BATCH API: Received \(quotes.count) quotes")
            
            // Update each asset with its quote
            for asset in assetsToUpdate {
                guard let ticker = asset.ticker else { continue }
                
                if let quote = quotes[ticker.uppercased()] {
                    var updatedAsset = asset
                    updatedAsset = updatedAsset.updatedWithLivePrice(quote.latestPrice, change: quote.changePercent)
                    portfolio.updateAsset(updatedAsset)
                    successCount += 1
                    AppLogger.debug("   ✅ [\(ticker)] Updated to $\(String(format: "%.2f", quote.latestPrice))")
                } else {
                    // Not in batch results - try individual fetch (for crypto/special assets)
                    do {
                        // REFRESH SESSION FIX: Fetch uses the refresh session flag, not bypass
                        // The session allows fallback to continue after batch completes
                        let (price, changePercent) = try await AlternativePriceService.shared.fetchPriceAndChange(for: asset, bypassCooldown: false)
                        var updatedAsset = asset
                        updatedAsset = updatedAsset.updatedWithLivePrice(price, change: changePercent)
                        portfolio.updateAsset(updatedAsset)
                        successCount += 1
                        AppLogger.debug("   ✅ [\(ticker)] Updated to $\(String(format: "%.2f", price)) (individual fetch)")
                    } catch {
                        failCount += 1
                        failedTickers.append(ticker)
                        AppLogger.debug("   ❌ [\(ticker)] Failed: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            // Batch API failed - fall back to individual requests with refresh session active
            AppLogger.warning("⚠️ Batch API failed: \(error.localizedDescription)")
            AppLogger.warning("⚠️ Falling back to individual requests (refresh session active)")
            
            // Process in smaller batches with refresh session active
            let batchSize = 5
            let batches = stride(from: 0, to: assetsToUpdate.count, by: batchSize).map {
                Array(assetsToUpdate[$0..<min($0 + batchSize, assetsToUpdate.count)])
            }
            
            for (batchIndex, batch) in batches.enumerated() {
                AppLogger.debug("📦 FALLBACK BATCH: [\(batchIndex + 1)/\(batches.count)] Processing \(batch.count) assets")
                
                // Process batch in parallel using refresh session (not bypass)
                await withTaskGroup(of: (Asset, Double?, Double?, Error?).self) { group in
                    for asset in batch {
                        guard asset.ticker != nil else { continue }
                        
                        group.addTask {
                            do {
                                // Use refresh session flag instead of bypass
                                let (price, changePercent) = try await AlternativePriceService.shared.fetchPriceAndChange(for: asset, bypassCooldown: false)
                                return (asset, price, changePercent, nil)
                            } catch {
                                return (asset, nil, nil, error)
                            }
                        }
                    }
                    
                    // Collect results
                    for await (asset, price, changePercent, error) in group {
                        if let price = price {
                            var updatedAsset = asset
                            updatedAsset = updatedAsset.updatedWithLivePrice(price, change: changePercent)
                            portfolio.updateAsset(updatedAsset)
                            successCount += 1
                            AppLogger.debug("   ✅ [\(asset.ticker ?? "unknown")] Updated to $\(String(format: "%.2f", price))")
                        } else {
                            failCount += 1
                            if let ticker = asset.ticker {
                                failedTickers.append(ticker)
                            }
                            AppLogger.debug("   ❌ [\(asset.ticker ?? "unknown")] Failed: \(error?.localizedDescription ?? "unknown")")
                        }
                    }
                }
                
                // Small delay between batches
                if batchIndex < batches.count - 1 {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
        }
        
        // REFRESH SESSION FIX: End the refresh session and set cooldown timer
        // This ensures cooldown starts AFTER all assets are processed
        await MarketstackService.shared.endRefreshSession()
        
        // Calculate duration
        let duration = Date().timeIntervalSince(startTime)
        
        // Log completion
        AppLogger.debug("════════════════════════════════════════")
        AppLogger.debug("🔄 REFRESH: Complete in \(String(format: "%.2f", duration))s")
        AppLogger.debug("🔄 REFRESH: Success: \(successCount)/\(assetsToUpdate.count)")
        AppLogger.debug("🔄 REFRESH: Failed: \(failCount)/\(assetsToUpdate.count)")
        if successCount > 0 && assetsToUpdate.count > 0 {
            AppLogger.debug("🔄 REFRESH: Success rate: \(String(format: "%.1f", Double(successCount) / Double(assetsToUpdate.count) * 100))%")
        }
        AppLogger.debug("════════════════════════════════════════")
        
        // Generate diagnostic info if there were failures
        if failCount > 0 {
            AppLogger.warning("⚠️ DIAGNOSTIC: \(failCount) assets failed to update")
            if !failedTickers.isEmpty {
                AppLogger.warning("⚠️ DIAGNOSTIC: Failed tickers: \(failedTickers.prefix(5).joined(separator: ", "))\(failedTickers.count > 5 ? " + \(failedTickers.count - 5) more" : "")")
            }
            if failCount > assetsToUpdate.count / 2 {
                AppLogger.warning("⚠️ DIAGNOSTIC: More than 50% failed - check network/API")
            }
        }
        
        // Update last successful refresh timestamp if we updated any prices
        if successCount > 0 {
            lastSuccessfulRefresh = Date()
            // Persist to UserDefaults
            UserDefaults.standard.set(lastSuccessfulRefresh?.timeIntervalSince1970 ?? 0, forKey: lastRefreshKey)
        }
        
        savePortfolio()
        invalidateCache()
        
        // Save performance snapshot after refresh
        savePerformanceSnapshot()
        
        // Print API usage
        if AlternativePriceService.useMarketstackTest {
            Task {
                let apiCalls = await MarketstackTestService.shared.getCallCount()
                print("📊 Mock API Calls This Session: \(apiCalls)")
            }
        } else {
            Task {
                let stats = await MarketstackService.shared.getUsageStats()
                print("📊 API Calls: \(stats.thisMonth)/\(stats.limit) this month")
            }
        }
        
        // Show appropriate message
        if successCount > 0 && failCount == 0 {
            show(success: "All prices updated successfully")
        } else if successCount > 0 {
            show(success: "\(successCount) of \(portfolio.assetsWithTickers.count) prices updated")
        } else {
            // All failed - provide helpful error
            if !failedTickers.isEmpty {
                show(error: "Unable to update: \(failedTickers.prefix(3).joined(separator: ", "))\(failedTickers.count > 3 ? " + \(failedTickers.count - 3) more" : "")")
            } else {
                show(error: "Unable to update prices. Check your internet connection.")
            }
        }
        
        isUpdatingPrices = false
    }
    
    // MARK: - Computed Properties
    
    var totalValue: Double {
        portfolio.totalValue
    }
    
    var allocationPercentages: [(AssetClass, Double)] {
        let currentHash = portfolio.assets.map { $0.id }.hashValue
        
        if let cached = cachedAllocation, lastPortfolioHash == currentHash {
            return cached
        }
        
        let result = portfolio.allocationPercentages
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
        
        cachedAllocation = result
        lastPortfolioHash = currentHash
        return result
    }
    
    var hasAssets: Bool {
        !portfolio.assets.isEmpty
    }
    
    var bondPercentage: Double {
        guard totalValue > 0 else { return 0 }
        let bondValue = portfolio.assets
            .filter { $0.assetClass == .bonds || $0.assetClass == .cash }
            .reduce(0) { $0 + $1.totalValue }
        return bondValue / totalValue
    }
    
    var stockPercentage: Double {
        guard totalValue > 0 else { return 0 }
        let stockValue = portfolio.assets
            .filter { $0.assetClass == .stocks }
            .reduce(0) { $0 + $1.totalValue }
        return stockValue / totalValue
    }
    
    /// Total daily gain/loss across all assets with price data
    /// Calculates based on priceChange if available, otherwise compares currentPrice to unitValue
    var dailyGain: Double? {
        // First try: use priceChange from API (most accurate for daily change)
        let assetsWithPriceChange = portfolio.assets.filter { 
            $0.currentPrice != nil && $0.priceChange != nil 
        }
        
        if !assetsWithPriceChange.isEmpty {
            // Calculate daily dollar change for each asset with priceChange data
            let totalDailyChange = assetsWithPriceChange.reduce(0.0) { sum, asset in
                guard let priceChange = asset.priceChange else { return sum }
                let currentValue = asset.totalValue
                // Calculate previous value: current / (1 + changePercent)
                let previousValue = currentValue / (1 + priceChange)
                let dollarChange = currentValue - previousValue
                return sum + dollarChange
            }
            return totalDailyChange
        }
        
        // Fallback: Compare currentPrice to unitValue (total gain since purchase)
        // This shows "all-time" gain when daily change data isn't available
        let assetsWithCurrentPrice = portfolio.assets.filter { 
            $0.currentPrice != nil && $0.ticker != nil
        }
        
        guard !assetsWithCurrentPrice.isEmpty else { return nil }
        
        let totalGain = assetsWithCurrentPrice.reduce(0.0) { sum, asset in
            guard let currentPrice = asset.currentPrice else { return sum }
            let currentValue = currentPrice * asset.quantity
            let originalValue = asset.unitValue * asset.quantity
            return sum + (currentValue - originalValue)
        }
        
        return totalGain
    }
    
    /// Daily gain as a percentage of total portfolio value
    var dailyGainPercentage: Double? {
        guard let gain = dailyGain, totalValue > 0 else { return nil }
        return gain / totalValue
    }
    
    /// Check if we're showing daily change (true) or all-time change (false)
    var isShowingDailyChange: Bool {
        let assetsWithPriceChange = portfolio.assets.filter { 
            $0.currentPrice != nil && $0.priceChange != nil 
        }
        return !assetsWithPriceChange.isEmpty
    }
    
    // MARK: - Private Helpers
    
    private func invalidateCache() {
        cachedAllocation = nil
        lastPortfolioHash = nil
    }
    
    func clearMessages() {
        successMessage = nil
        errorMessage = nil
    }
    
    private func show(success message: String) {
        successMessage = message
        scheduleClear()
    }
    
    private func show(error message: String) {
        errorMessage = message
        scheduleClear()
    }
    
    private func scheduleClear() {
        clearMessageTask?.cancel()
        clearMessageTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            successMessage = nil
            errorMessage = nil
        }
    }
    
    // MARK: - Performance Tracking
    
    /// Automatically saves a portfolio snapshot after a refresh
    /// Only saves the overall value (not detailed asset data) for chart logging
    private func savePerformanceSnapshot() {
        // Only save if portfolio has value
        guard totalValue > 0 else {
            return
        }
        
        // Check if we recently saved a snapshot (within last 15 minutes)
        if let existingSnapshots = try? persistence.loadSnapshots(),
           let lastSnapshot = existingSnapshots.last {
            let timeSinceLastSnapshot = Date().timeIntervalSince(lastSnapshot.date)
            
            // Skip if last snapshot was within 15 minutes
            if timeSinceLastSnapshot < 15 * 60 {
                return
            }
        }
        
        let snapshot = PerformanceSnapshot(
            portfolioId: portfolio.id,
            totalValue: totalValue,
            allocation: portfolio.assetAllocation,
            assets: portfolio.assets
        )
        
        do {
            try persistence.saveSnapshot(snapshot)
        } catch {
            // Don't show error to user - this is a background operation
        }
    }
}
