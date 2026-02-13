//
//  simulation_viewmodel.swift
//  FIRECalc
//
//  MODIFIED - Added custom returns support
//

import Foundation
import SwiftUI

@MainActor
class SimulationViewModel: ObservableObject {
    @Published var parameters: SimulationParameters
    @Published var currentResult: SimulationResult?
    @Published var simulationHistory: [SimulationResult] = []
    @Published var isSimulating: Bool = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    
    // MODIFIED: Custom returns support
    @Published var useCustomReturns: Bool = false
    @Published var customReturns: [AssetClass: Double] = [:]
    @Published var customVolatility: [AssetClass: Double] = [:]
    
    private let persistence = PersistenceService.shared
    
    init() {
        self.parameters = SimulationParameters(
            numberOfRuns: AppConstants.Simulation.defaultRuns,
            timeHorizonYears: AppConstants.Simulation.defaultTimeHorizon,
            inflationRate: AppConstants.Simulation.defaultInflationRate,
            useHistoricalBootstrap: true,
            initialPortfolioValue: 1_000_000
        )
        
        if let history = try? persistence.loadSimulationHistory() {
            self.simulationHistory = history.reversed() // newest first
            self.currentResult = history.last
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
        
        // MODIFIED: Apply custom returns if enabled
        var simulationParams = parameters
        simulationParams.initialPortfolioValue = portfolio.totalValue
        
        if useCustomReturns {
            simulationParams.customReturns = customReturns
            simulationParams.customVolatility = customVolatility
            simulationParams.useHistoricalBootstrap = false
        }
        
        do {
            let engine = MonteCarloEngine()
            let historicalData = try HistoricalDataService.shared.loadHistoricalData()
            
            let result = try await engine.runSimulation(
                portfolio: portfolio,
                parameters: simulationParams,
                historicalData: historicalData
            )
            
            currentResult = result
            progress = 1.0
            
            try? persistence.saveSimulationResult(result)
            if let history = try? persistence.loadSimulationHistory() {
                simulationHistory = history.reversed()
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSimulating = false
    }
    
    func runQuickSimulation(portfolio: Portfolio) async {
        let originalRuns = parameters.numberOfRuns
        parameters = SimulationParameters(
            numberOfRuns: AppConstants.Simulation.quickSimulationRuns,
            timeHorizonYears: parameters.timeHorizonYears,
            inflationRate: parameters.inflationRate,
            useHistoricalBootstrap: !useCustomReturns,
            initialPortfolioValue: portfolio.totalValue,
            monthlyContribution: parameters.monthlyContribution,
            yearsUntilRetirement: parameters.yearsUntilRetirement,
            withdrawalConfig: parameters.withdrawalConfig,
            customReturns: useCustomReturns ? customReturns : nil,
            customVolatility: useCustomReturns ? customVolatility : nil
        )
        
        await runSimulation(portfolio: portfolio)
        
        parameters = SimulationParameters(
            numberOfRuns: originalRuns,
            timeHorizonYears: parameters.timeHorizonYears,
            inflationRate: parameters.inflationRate,
            useHistoricalBootstrap: !useCustomReturns,
            initialPortfolioValue: portfolio.totalValue,
            monthlyContribution: parameters.monthlyContribution,
            yearsUntilRetirement: parameters.yearsUntilRetirement,
            withdrawalConfig: parameters.withdrawalConfig,
            customReturns: useCustomReturns ? customReturns : nil,
            customVolatility: useCustomReturns ? customVolatility : nil
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
            useHistoricalBootstrap: !useCustomReturns,
            initialPortfolioValue: parameters.initialPortfolioValue,
            monthlyContribution: parameters.monthlyContribution,
            yearsUntilRetirement: parameters.yearsUntilRetirement,
            withdrawalConfig: config,
            customReturns: useCustomReturns ? customReturns : nil,
            customVolatility: useCustomReturns ? customVolatility : nil
        )
    }
    
    func updateTimeHorizon(_ years: Int) {
        parameters = SimulationParameters(
            numberOfRuns: parameters.numberOfRuns,
            timeHorizonYears: years,
            inflationRate: parameters.inflationRate,
            useHistoricalBootstrap: !useCustomReturns,
            initialPortfolioValue: parameters.initialPortfolioValue,
            monthlyContribution: parameters.monthlyContribution,
            yearsUntilRetirement: parameters.yearsUntilRetirement,
            withdrawalConfig: parameters.withdrawalConfig,
            customReturns: useCustomReturns ? customReturns : nil,
            customVolatility: useCustomReturns ? customVolatility : nil
        )
    }
    
    func updateInflationRate(_ rate: Double) {
        parameters = SimulationParameters(
            numberOfRuns: parameters.numberOfRuns,
            timeHorizonYears: parameters.timeHorizonYears,
            inflationRate: rate,
            useHistoricalBootstrap: !useCustomReturns,
            initialPortfolioValue: parameters.initialPortfolioValue,
            monthlyContribution: parameters.monthlyContribution,
            yearsUntilRetirement: parameters.yearsUntilRetirement,
            withdrawalConfig: parameters.withdrawalConfig,
            customReturns: useCustomReturns ? customReturns : nil,
            customVolatility: useCustomReturns ? customVolatility : nil
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
