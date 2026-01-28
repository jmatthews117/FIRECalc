//
//  PortfolioViewModel.swift
//  FIRECalc
//
//  Manages portfolio state and operations
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
    
    init(portfolio: Portfolio? = nil) {
        // Try to load saved portfolio, or use provided one, or create new
        if let savedPortfolio = try? persistence.loadPortfolio() {
            self.portfolio = savedPortfolio
            print("📂 Loaded saved portfolio with \(savedPortfolio.assets.count) assets")
        } else if let provided = portfolio {
            self.portfolio = provided
        } else {
            self.portfolio = Portfolio(name: "My Portfolio")
        }
        
        // No API key needed for Yahoo Finance!
        print("📊 Using Yahoo Finance (no API key required)")
    }
    
    // MARK: - Asset Management
    
    func addAsset(_ asset: Asset) {
        portfolio.addAsset(asset)
        savePortfolio()
        successMessage = "Asset added successfully"
        clearMessagesAfterDelay()
    }
    
    func updateAsset(_ asset: Asset) {
        portfolio.updateAsset(asset)
        savePortfolio()
        successMessage = "Asset updated successfully"
        clearMessagesAfterDelay()
    }
    
    func deleteAsset(_ asset: Asset) {
        portfolio.removeAsset(asset)
        savePortfolio()
        successMessage = "Asset deleted"
        clearMessagesAfterDelay()
    }
    
    func deleteAssets(at offsets: IndexSet) {
        portfolio.removeAssets(at: offsets)
        savePortfolio()
        successMessage = "Assets deleted"
        clearMessagesAfterDelay()
    }
    
    private func savePortfolio() {
        do {
            try persistence.savePortfolio(portfolio)
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            clearMessagesAfterDelay()
        }
    }
    
    // MARK: - Price Updates
    
    func refreshPrices() async {
        print("🔄 Starting price refresh...")
        print("   Assets with tickers: \(portfolio.assetsWithTickers.count)")
        
        guard !portfolio.assetsWithTickers.isEmpty else {
            print("⚠️ No assets with tickers to update")
            errorMessage = "No assets with ticker symbols to update"
            clearMessagesAfterDelay()
            return
        }
        
        isUpdatingPrices = true
        errorMessage = nil
        
        do {
            print("📊 Fetching prices from Yahoo Finance...")
            let service = YahooFinanceService.shared
            portfolio = try await service.updatePortfolioPrices(portfolio: portfolio)
            savePortfolio()
            print("✅ Prices updated successfully!")
            successMessage = "Prices updated successfully"
        } catch {
            print("❌ Price refresh failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        
        isUpdatingPrices = false
        clearMessagesAfterDelay()
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
    
    // MARK: - Helpers
    
    private func clearMessagesAfterDelay() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            successMessage = nil
            errorMessage = nil
        }
    }
}
