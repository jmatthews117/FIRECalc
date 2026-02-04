//
//  PortfolioViewModel.swift
//  FIRECalc
//
//  Manages portfolio state and operations with retirement tracking
//

import Foundation
import SwiftUI

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var portfolio: Portfolio
    @Published var isUpdatingPrices: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Retirement planning
    @Published var targetRetirementDate: Date?
    @Published var expectedAnnualSpend: Double = 40000
    @Published var withdrawalPercentage: Double = 0.04
    @Published var annualFixedIncome: Double = 0
    
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
        
        // Load retirement settings
        loadRetirementSettings()
        
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
    
    // MARK: - Retirement Planning
    
    var targetRetirementValue: Double {
        expectedAnnualSpend / withdrawalPercentage
    }
    
    func setRetirementDate(_ date: Date) {
        targetRetirementDate = date
        saveRetirementSettings()
    }
    
    func setAnnualFixedIncome(_ income: Double) {
        annualFixedIncome = income
        saveRetirementSettings()
    }
    
    var retirementProgress: Double {
        let target = targetRetirementValue
        guard target > 0 else { return 0 }
        return totalValue / target
    }
    
    var yearsToRetirement: Int? {
        guard let targetDate = targetRetirementDate else { return nil }
        return Calendar.current.dateComponents([.year], from: Date(), to: targetDate).year
    }
    
    private func loadRetirementSettings() {
        if let dateTimestamp = UserDefaults.standard.object(forKey: "retirement_date") as? TimeInterval {
            targetRetirementDate = Date(timeIntervalSince1970: dateTimestamp)
        }
        
        let savedSpend = UserDefaults.standard.double(forKey: "expected_annual_spend")
        if savedSpend > 0 {
            expectedAnnualSpend = savedSpend
        }
        
        let savedWithdrawalPct = UserDefaults.standard.double(forKey: "withdrawal_percentage")
        if savedWithdrawalPct > 0 {
            withdrawalPercentage = savedWithdrawalPct
        } else {
            withdrawalPercentage = 0.04
        }
        
        annualFixedIncome = UserDefaults.standard.double(forKey: "fixed_income")
    }
    
    private func saveRetirementSettings() {
        if let date = targetRetirementDate {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "retirement_date")
        }
        UserDefaults.standard.set(annualFixedIncome, forKey: "fixed_income")
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
    
    // MARK: - Helpers
    
    private func clearMessagesAfterDelay() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            successMessage = nil
            errorMessage = nil
        }
    }
}
