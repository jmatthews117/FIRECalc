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
    
    // MARK: - Computed Property Caching
    
    private var cachedAllocation: [(AssetClass, Double)]?
    private var lastPortfolioHash: Int?
    
    init(portfolio: Portfolio? = nil) {
        if let savedPortfolio = try? persistence.loadPortfolio() {
            self.portfolio = savedPortfolio
            print("📂 Loaded saved portfolio with \(savedPortfolio.assets.count) assets")
        } else if let provided = portfolio {
            self.portfolio = provided
        } else {
            self.portfolio = Portfolio(name: "My Portfolio")
        }
        
        print("📊 Using Yahoo Finance (no API key required)")
        
        // Automatically refresh prices on launch if we have stale data
        Task {
            await refreshPricesIfNeeded()
        }
    }
    
    /// Refresh prices only if data is stale (older than 1 hour)
    func refreshPricesIfNeeded() async {
        let assetsNeedingUpdate = portfolio.assetsNeedingPriceUpdate
        
        // Also refresh if we have tickers but no price data at all
        let assetsWithoutPrices = portfolio.assetsWithTickers.filter { $0.currentPrice == nil }
        
        guard !assetsNeedingUpdate.isEmpty || !assetsWithoutPrices.isEmpty else {
            print("✅ All prices are fresh")
            return
        }
        
        print("🔄 Auto-refreshing \(max(assetsNeedingUpdate.count, assetsWithoutPrices.count)) stale/missing prices on launch...")
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
        print("\n" + String(repeating: "=", count: 60))
        print("🔄 REFRESH PRICES STARTED")
        print(String(repeating: "=", count: 60))
        print("📅 Time: \(Date())")
        print("📊 Total assets in portfolio: \(portfolio.assets.count)")
        print("🎯 Assets with tickers: \(portfolio.assetsWithTickers.count)")
        
        // Debug: List all assets
        print("\n📋 All Assets:")
        for (index, asset) in portfolio.assets.enumerated() {
            print("   \(index + 1). \(asset.name)")
            print("      - Asset Class: \(asset.assetClass.rawValue)")
            print("      - Ticker: \(asset.ticker ?? "NONE")")
            print("      - Current Price: \(asset.currentPrice?.description ?? "nil")")
            print("      - Last Updated: \(asset.lastUpdated?.description ?? "nil")")
            print("      - Quantity: \(asset.quantity)")
        }
        
        guard !portfolio.assetsWithTickers.isEmpty else {
            print("\n⚠️ NO ASSETS WITH TICKERS - EXITING")
            print(String(repeating: "=", count: 60) + "\n")
            return
        }
        
        // Debug: Print tickers we're trying to update
        let tickers = portfolio.assetsWithTickers.compactMap { $0.ticker }
        print("\n🎯 Tickers to update: \(tickers.joined(separator: ", "))")
        
        isUpdatingPrices = true
        errorMessage = nil
        
        var successCount = 0
        var failCount = 0
        var failedTickers: [String] = []
        
        print("\n" + String(repeating: "-", count: 60))
        print("🚀 BEGINNING API CALLS")
        print(String(repeating: "-", count: 60))
        
        // Use the same simple approach as when adding assets - fetch price for each ticker directly
        for (index, asset) in portfolio.assetsWithTickers.enumerated() {
            guard let ticker = asset.ticker else {
                print("\n⚠️ Asset #\(index + 1) has no ticker, skipping...")
                continue
            }
            
            print("\n📡 [\(index + 1)/\(portfolio.assetsWithTickers.count)] Processing: \(ticker)")
            print("   Asset Name: \(asset.name)")
            print("   Asset ID: \(asset.id)")
            print("   Current Price: \(asset.currentPrice?.description ?? "nil")")
            print("   Last Updated: \(asset.lastUpdated?.description ?? "nil")")
            
            do {
                print("   ⏳ Calling YahooFinanceService.shared.fetchQuote(ticker: \"\(ticker)\")...")
                
                // Use Yahoo Finance service directly - same as when adding assets
                let quote = try await YahooFinanceService.shared.fetchQuote(ticker: ticker)
                let newPrice = quote.latestPrice
                
                print("   ✅ SUCCESS! Got quote:")
                print("      - Symbol: \(quote.symbol)")
                print("      - Price: $\(newPrice)")
                print("      - Change: \(quote.change?.description ?? "nil")")
                print("      - Change %: \(quote.changePercent?.description ?? "nil")")
                
                // Update the asset with the new price
                print("   📝 Updating asset in portfolio...")
                var updatedAsset = asset
                let oldPrice = updatedAsset.currentPrice
                let oldUpdated = updatedAsset.lastUpdated
                
                updatedAsset = updatedAsset.updatedWithLivePrice(newPrice, change: quote.changePercent)
                
                print("      - Old price: \(oldPrice?.description ?? "nil")")
                print("      - New price: \(updatedAsset.currentPrice?.description ?? "nil")")
                print("      - Old lastUpdated: \(oldUpdated?.description ?? "nil")")
                print("      - New lastUpdated: \(updatedAsset.lastUpdated?.description ?? "nil")")
                
                portfolio.updateAsset(updatedAsset)
                print("   ✅ Asset updated in portfolio successfully")
                
                successCount += 1
                
                // Small delay between requests to be respectful to Yahoo Finance
                print("   ⏸️  Waiting 0.3 seconds before next request...")
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                
            } catch {
                print("   ❌ FAILED!")
                print("      Error Type: \(type(of: error))")
                print("      Error: \(error)")
                print("      Localized: \(error.localizedDescription)")
                failedTickers.append(ticker)
                failCount += 1
            }
        }
        
        print("\n" + String(repeating: "-", count: 60))
        print("💾 SAVING PORTFOLIO")
        print(String(repeating: "-", count: 60))
        savePortfolio()
        invalidateCache()
        print("✅ Portfolio saved")
        
        print("\n" + String(repeating: "=", count: 60))
        print("📊 FINAL RESULTS")
        print(String(repeating: "=", count: 60))
        print("✅ Successful updates: \(successCount)")
        print("❌ Failed updates: \(failCount)")
        if !failedTickers.isEmpty {
            print("❌ Failed tickers: \(failedTickers.joined(separator: ", "))")
        }
        
        // Show appropriate message
        if successCount > 0 && failCount == 0 {
            print("🎉 All prices updated successfully!")
            show(success: "All prices updated successfully")
        } else if successCount > 0 {
            print("⚠️ Partial success: \(successCount) of \(portfolio.assetsWithTickers.count)")
            show(success: "\(successCount) of \(portfolio.assetsWithTickers.count) prices updated")
        } else {
            print("💔 All updates failed!")
            // All failed - provide helpful error
            if !failedTickers.isEmpty {
                show(error: "Unable to update: \(failedTickers.prefix(3).joined(separator: ", "))\(failedTickers.count > 3 ? " + \(failedTickers.count - 3) more" : "")")
            } else {
                show(error: "Unable to update prices. Check your internet connection.")
            }
        }
        
        print(String(repeating: "=", count: 60) + "\n")
        
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
    var dailyGain: Double? {
        let assetsWithPriceChange = portfolio.assets.filter { 
            $0.currentPrice != nil && $0.priceChange != nil 
        }
        
        guard !assetsWithPriceChange.isEmpty else { return nil }
        
        // Calculate dollar change for each asset
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
    
    /// Daily gain as a percentage of total portfolio value
    var dailyGainPercentage: Double? {
        guard let gain = dailyGain, totalValue > 0 else { return nil }
        return gain / totalValue
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
}
