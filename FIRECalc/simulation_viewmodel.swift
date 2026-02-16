//
//  simulation_viewmodel.swift
//  FIRECalc
//
//  Controls Monte Carlo simulation state and parameter management.
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

    /// Persisted withdrawal configuration, shared between the Tools tab
    /// standalone view and the Simulation Setup sheet.
    @Published var withdrawalConfiguration: WithdrawalConfiguration {
        didSet {
            persistence.saveWithdrawalConfiguration(withdrawalConfiguration)
        }
    }
    
    // MODIFIED: Custom returns support
    @Published var useCustomReturns: Bool = false
    @Published var customReturns: [AssetClass: Double] = [:]
    @Published var customVolatility: [AssetClass: Double] = [:]
    
    private let persistence = PersistenceService.shared
    
    init() {
        let settings = PersistenceService.shared.loadSettings()
        let savedConfig = PersistenceService.shared.loadWithdrawalConfiguration() ?? WithdrawalConfiguration()
        self.withdrawalConfiguration = savedConfig
        self.parameters = SimulationParameters(
            numberOfRuns: AppConstants.Simulation.defaultRuns,
            timeHorizonYears: AppConstants.Simulation.defaultTimeHorizon,
            inflationRate: AppConstants.Simulation.defaultInflationRate,
            useHistoricalBootstrap: settings.useHistoricalBootstrap,
            initialPortfolioValue: 1_000_000,
            withdrawalConfig: savedConfig
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
        // Temporarily swap to a reduced run count, restore afterwards.
        let originalRuns = parameters.numberOfRuns
        parameters.numberOfRuns = AppConstants.Simulation.quickSimulationRuns
        parameters.useHistoricalBootstrap = !useCustomReturns
        if useCustomReturns {
            parameters.customReturns = customReturns
            parameters.customVolatility = customVolatility
        }
        
        await runSimulation(portfolio: portfolio)
        
        // Restore original run count (other fields were set correctly by runSimulation).
        parameters.numberOfRuns = originalRuns
    }
    
    // MARK: - Parameter Updates

    func updateWithdrawalRate(_ rate: Double) {
        var config = parameters.withdrawalConfig
        config.withdrawalRate = rate
        parameters.withdrawalConfig = config
    }
    
    func updateTimeHorizon(_ years: Int) {
        parameters.timeHorizonYears = years
    }
    
    func updateInflationRate(_ rate: Double) {
        parameters.inflationRate = rate
    }
    
    // MARK: - Computed Properties
    
    var hasResult: Bool {
        currentResult != nil
    }
    
    var successRateColor: Color {
        guard let result = currentResult else { return .gray }
        return AppConstants.Colors.successRateColor(for: result.successRate)
    }
    
    var successRateText: String {
        guard let result = currentResult else { return "Run Simulation" }
        return String(format: "%.0f%% Success Rate", result.successRate * 100)
    }
}
