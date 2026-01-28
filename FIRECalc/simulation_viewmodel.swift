//
//  SimulationViewModel.swift
//  FIRECalc
//
//  Manages Monte Carlo simulations
//

import Foundation
import SwiftUI

@MainActor
class SimulationViewModel: ObservableObject {
    @Published var parameters: SimulationParameters
    @Published var currentResult: SimulationResult?
    @Published var isSimulating: Bool = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    
    private let persistence = PersistenceService.shared
    
    init() {
        // Initialize with default parameters
        self.parameters = SimulationParameters(
            numberOfRuns: AppConstants.Simulation.defaultRuns,
            timeHorizonYears: AppConstants.Simulation.defaultTimeHorizon,
            inflationRate: AppConstants.Simulation.defaultInflationRate,
            useHistoricalBootstrap: true,
            initialPortfolioValue: 1_000_000
        )
        
        // Load last simulation result if available
        if let history = try? persistence.loadSimulationHistory(),
           let lastResult = history.last {
            self.currentResult = lastResult
        }
    }
    
    // MARK: - Simulation Control
    
    func runSimulation(portfolio: Portfolio) async {
        guard !portfolio.assets.isEmpty else {
            errorMessage = "Portfolio must contain at least one asset"
            return
        }
        
        isSimulating = true
        progress = 0
        errorMessage = nil
        
        // Update initial portfolio value from portfolio
        parameters = SimulationParameters(
            numberOfRuns: parameters.numberOfRuns,
            timeHorizonYears: parameters.timeHorizonYears,
            inflationRate: parameters.inflationRate,
            useHistoricalBootstrap: parameters.useHistoricalBootstrap,
            initialPortfolioValue: portfolio.totalValue,
            monthlyContribution: parameters.monthlyContribution,
            yearsUntilRetirement: parameters.yearsUntilRetirement,
            withdrawalConfig: parameters.withdrawalConfig,
            taxRate: parameters.taxRate,
            socialSecurityIncome: parameters.socialSecurityIncome,
            pensionIncome: parameters.pensionIncome,
            otherIncome: parameters.otherIncome,
            customReturns: parameters.customReturns,
            customVolatility: parameters.customVolatility
        )
        
        do {
            let engine = MonteCarloEngine()
            let historicalData = try HistoricalDataService.shared.loadHistoricalData()
            
            let result = try await engine.runSimulation(
                portfolio: portfolio,
                parameters: parameters,
                historicalData: historicalData
            )
            
            currentResult = result
            progress = 1.0
            
            // Save result to history
            try? persistence.saveSimulationResult(result)
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSimulating = false
    }
    
    func runQuickSimulation(portfolio: Portfolio) async {
        // Temporarily reduce runs for quick preview
        let originalRuns = parameters.numberOfRuns
        parameters = SimulationParameters(
            numberOfRuns: AppConstants.Simulation.quickSimulationRuns,
            timeHorizonYears: parameters.timeHorizonYears,
            inflationRate: parameters.inflationRate,
            useHistoricalBootstrap: parameters.useHistoricalBootstrap,
            initialPortfolioValue: portfolio.totalValue,
            monthlyContribution: parameters.monthlyContribution,
            yearsUntilRetirement: parameters.yearsUntilRetirement,
            withdrawalConfig: parameters.withdrawalConfig
        )
        
        await runSimulation(portfolio: portfolio)
        
        // Restore original runs
        parameters = SimulationParameters(
            numberOfRuns: originalRuns,
            timeHorizonYears: parameters.timeHorizonYears,
            inflationRate: parameters.inflationRate,
            useHistoricalBootstrap: parameters.useHistoricalBootstrap,
            initialPortfolioValue: portfolio.totalValue,
            monthlyContribution: parameters.monthlyContribution,
            yearsUntilRetirement: parameters.yearsUntilRetirement,
            withdrawalConfig: parameters.withdrawalConfig
        )
    }
    
    // MARK: - Parameter Updates
    
    func updateWithdrawalRate(_ rate: Double) {
        var config = parameters.withdrawalConfig
        config.withdrawalRate = rate
        parameters = SimulationParameters(
            numberOfRuns: parameters.numberOfRuns,
            timeHorizonYears: parameters.timeHorizonYears,
            inflationRate: parameters.inflationRate,
            useHistoricalBootstrap: parameters.useHistoricalBootstrap,
            initialPortfolioValue: parameters.initialPortfolioValue,
            monthlyContribution: parameters.monthlyContribution,
            yearsUntilRetirement: parameters.yearsUntilRetirement,
            withdrawalConfig: config
        )
    }
    
    func updateTimeHorizon(_ years: Int) {
        parameters = SimulationParameters(
            numberOfRuns: parameters.numberOfRuns,
            timeHorizonYears: years,
            inflationRate: parameters.inflationRate,
            useHistoricalBootstrap: parameters.useHistoricalBootstrap,
            initialPortfolioValue: parameters.initialPortfolioValue,
            monthlyContribution: parameters.monthlyContribution,
            yearsUntilRetirement: parameters.yearsUntilRetirement,
            withdrawalConfig: parameters.withdrawalConfig
        )
    }
    
    func updateInflationRate(_ rate: Double) {
        parameters = SimulationParameters(
            numberOfRuns: parameters.numberOfRuns,
            timeHorizonYears: parameters.timeHorizonYears,
            inflationRate: rate,
            useHistoricalBootstrap: parameters.useHistoricalBootstrap,
            initialPortfolioValue: parameters.initialPortfolioValue,
            monthlyContribution: parameters.monthlyContribution,
            yearsUntilRetirement: parameters.yearsUntilRetirement,
            withdrawalConfig: parameters.withdrawalConfig
        )
    }
    
    // MARK: - Computed Properties
    
    var hasResult: Bool {
        currentResult != nil
    }
    
    var successRateColor: Color {
        guard let result = currentResult else { return .gray }
        
        if result.successRate >= 0.9 {
            return AppConstants.Colors.success
        } else if result.successRate >= 0.75 {
            return AppConstants.Colors.warning
        } else {
            return AppConstants.Colors.danger
        }
    }
    
    var successRateText: String {
        guard let result = currentResult else { return "Run Simulation" }
        return String(format: "%.0f%% Success Rate", result.successRate * 100)
    }
}
