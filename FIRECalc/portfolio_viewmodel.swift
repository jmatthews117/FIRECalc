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
    
    init(portfolio: Portfolio? = nil) {
        if let savedPortfolio = try? persistence.loadPortfolio() {
            self.portfolio = savedPortfolio
        } else if let provided = portfolio {
            self.portfolio = provided
        } else {
            self.portfolio = Portfolio(name: "My Portfolio")
        }
        
        // PHASE 2: Enable REAL Marketstack (set to true for test mode)
        AlternativePriceService.useMarketstackTest = false
        print("📡 LIVE MODE - Using real Marketstack API with 15-min cache")
        
        // Automatically refresh prices on launch if we have stale data
        Task {
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
        
        await refreshPrices()
    }
    
    // MARK: - Asset Management
    
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
        guard SubscriptionManager.shared.isProSubscriber else {
            show(error: "Stock price updates require FIRECalc Pro. Upgrade to access live portfolio tracking.")
            return
        }
        
        // PERFORMANCE FIX: Cancel any pending refresh and debounce rapid calls
        refreshTask?.cancel()
        
        // Don't allow overlapping refreshes
        guard !isUpdatingPrices else {
            return
        }
        
        // Create new refresh task
        refreshTask = Task { @MainActor in
            await performRefresh()
        }
        
        await refreshTask?.value
    }
    
    private func performRefresh() async {
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
        
        // EFFICIENCY: Batch requests in groups of 5 for parallel execution
        let batchSize = 5
        let assetsToUpdate = portfolio.assetsWithTickers.filter { $0.ticker != nil }
        let batches = stride(from: 0, to: assetsToUpdate.count, by: batchSize).map {
            Array(assetsToUpdate[$0..<min($0 + batchSize, assetsToUpdate.count)])
        }
        
        for (batchIndex, batch) in batches.enumerated() {
            
            // Process batch in parallel - UNIFIED: Use AlternativePriceService for ALL assets
            await withTaskGroup(of: (Asset, Double?, Double?, Error?).self) { group in
                for asset in batch {
                    guard asset.ticker != nil else { continue }
                    
                    group.addTask {
                        do {
                            // Use AlternativePriceService which handles crypto correctly with -USD suffix
                            // and now also fetches daily change percentage
                            let (price, changePercent) = try await AlternativePriceService.shared.fetchPriceAndChange(for: asset)
                            return (asset, price, changePercent, nil)
                        } catch {
                            return (asset, nil, nil, error)
                        }
                    }
                }
                
                // Collect results from parallel tasks
                for await (asset, price, changePercent, error) in group {
                    if let price = price {
                        var updatedAsset = asset
                        updatedAsset = updatedAsset.updatedWithLivePrice(price, change: changePercent)
                        portfolio.updateAsset(updatedAsset)
                        successCount += 1
                    } else {
                        failCount += 1
                        if let ticker = asset.ticker {
                            failedTickers.append(ticker)
                        }
                    }
                }
            }
            
            // Small delay only between batches
            if batchIndex < batches.count - 1 {
                do {
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                } catch {
                    // Sleep was cancelled, continue anyway
                }
            }
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
