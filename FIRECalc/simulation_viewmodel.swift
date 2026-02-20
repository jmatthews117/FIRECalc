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
    
    /// The most recent simulation result with FULL data including all simulation runs.
    /// This is kept in memory to support detailed visualizations (spaghetti charts, etc.)
    @Published var currentResult: SimulationResult?
    
    /// Historical simulation results loaded from disk. These are stored WITHOUT
    /// the heavy `allSimulationRuns` data to conserve memory. Each result with
    /// full run data can be 5-10 MB; stripping that reduces storage to <100 KB.
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
        
        // Apply custom returns if enabled.
        var simulationParams = parameters
        // Use targetPortfolioValue as the effective starting balance when set;
        // otherwise fall back to the live portfolio value.
        simulationParams.initialPortfolioValue = simulationParams.targetPortfolioValue ?? portfolio.totalValue

        if useCustomReturns {
            simulationParams.customReturns = customReturns
            simulationParams.customVolatility = customVolatility
            simulationParams.useHistoricalBootstrap = false
        }

        // If custom allocation weights are provided, build a synthetic portfolio
        // that uses those weights while preserving per-class return assumptions.
        let effectivePortfolio: Portfolio
        if let weights = simulationParams.customAllocationWeights,
           simulationParams.customAllocationWeightsAreValid {
            effectivePortfolio = portfolio.applyingAllocationWeights(weights)
        } else {
            effectivePortfolio = portfolio
        }
        
        do {
            let engine = MonteCarloEngine()
            let historicalData = try HistoricalDataService.shared.loadHistoricalData()
            
            let result = try await engine.runSimulation(
                portfolio: effectivePortfolio,
                parameters: simulationParams,
                historicalData: historicalData
            )
            
            currentResult = result
            progress = 1.0
            
            // Strip out heavy simulation run data before persisting to disk
            try? persistence.saveSimulationResult(result.withoutSimulationRuns())
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
