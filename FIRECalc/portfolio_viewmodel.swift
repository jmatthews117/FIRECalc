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
        savePortfolio()
        show(success: "Asset added successfully")
    }
    
    func updateAsset(_ asset: Asset) {
        portfolio.updateAsset(asset)
        savePortfolio()
        show(success: "Asset updated successfully")
    }
    
    func deleteAsset(_ asset: Asset) {
        portfolio.removeAsset(asset)
        savePortfolio()
        show(success: "Asset deleted")
    }
    
    func deleteAssets(at offsets: IndexSet) {
        portfolio.removeAssets(at: offsets)
        savePortfolio()
        show(success: "Assets deleted")
    }
    
    private func savePortfolio() {
        do {
            try persistence.savePortfolio(portfolio)
        } catch {
            show(error: "Failed to save: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Price Updates
    
    func refreshPrices() async {
        print("🔄 Starting price refresh...")
        print("   Assets with tickers: \(portfolio.assetsWithTickers.count)")
        
        guard !portfolio.assetsWithTickers.isEmpty else {
            print("⚠️ No assets with tickers to update")
            return
        }
        
        isUpdatingPrices = true
        errorMessage = nil
        
        do {
            print("📊 Fetching prices from Yahoo Finance...")
            portfolio = try await YahooFinanceService.shared.updatePortfolioPrices(portfolio: portfolio)
            savePortfolio()
            print("✅ Prices updated successfully!")
            show(success: "Prices updated successfully")
        } catch {
            print("❌ Price refresh failed: \(error.localizedDescription)")
            show(error: error.localizedDescription)
        }
        
        isUpdatingPrices = false
    }
    
    // MARK: - Computed Properties
    
    var totalValue: Double {
        portfolio.totalValue
    }
    
    var allocationPercentages: [(AssetClass, Double)] {
        portfolio.allocationPercentages
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
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
