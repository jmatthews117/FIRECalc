//
//  SimulationParameters.swift
//  FIRECalc
//
//  Configuration for Monte Carlo simulations
//

import Foundation

struct SimulationParameters: Codable {
    // Simulation settings
    var numberOfRuns: Int
    var timeHorizonYears: Int
    var inflationRate: Double
    var useHistoricalBootstrap: Bool
    
    // Portfolio starting values
    var initialPortfolioValue: Double
    var monthlyContribution: Double  // Additional contributions during accumulation
    var yearsUntilRetirement: Int
    
    // Withdrawal configuration
    var withdrawalConfig: WithdrawalConfiguration
    
    // Advanced options
    var taxRate: Double?  // Optional tax considerations

    // Reproducibility and bootstrap options
    var rngSeed: UInt64?  // Optional RNG seed for reproducible runs
    var bootstrapBlockLength: Int?  // Optional block length for historical bootstrap (>= 2 enables block sampling)
    
    // Market assumptions (if not using bootstrap)
    var customReturns: [AssetClass: Double]?
    var customVolatility: [AssetClass: Double]?
    
    // Inflation handling strategy
    var inflationStrategy: InflationStrategy
    
    init(
        numberOfRuns: Int = 10000,
        timeHorizonYears: Int = 30,
        inflationRate: Double = 0.02,
        useHistoricalBootstrap: Bool = true,
        initialPortfolioValue: Double,
        monthlyContribution: Double = 0,
        yearsUntilRetirement: Int = 0,
        withdrawalConfig: WithdrawalConfiguration = WithdrawalConfiguration(),
        taxRate: Double? = nil,
        rngSeed: UInt64? = nil,
        bootstrapBlockLength: Int? = nil,
        customReturns: [AssetClass: Double]? = nil,
        customVolatility: [AssetClass: Double]? = nil,
        inflationStrategy: InflationStrategy = .historicalCorrelated
    ) {
        self.numberOfRuns = numberOfRuns
        self.timeHorizonYears = timeHorizonYears
        self.inflationRate = inflationRate
        self.useHistoricalBootstrap = useHistoricalBootstrap
        self.initialPortfolioValue = initialPortfolioValue
        self.monthlyContribution = monthlyContribution
        self.yearsUntilRetirement = yearsUntilRetirement
        self.withdrawalConfig = withdrawalConfig
        self.taxRate = taxRate
        self.rngSeed = rngSeed
        self.bootstrapBlockLength = bootstrapBlockLength
        self.customReturns = customReturns
        self.customVolatility = customVolatility
        self.inflationStrategy = inflationStrategy
    }
    
    // MARK: - Validation
    
    var isValid: Bool {
        numberOfRuns > 0 &&
        numberOfRuns <= 100000 &&
        timeHorizonYears > 0 &&
        timeHorizonYears <= 50 &&
        inflationRate >= -0.05 &&
        inflationRate <= 0.15 &&
        initialPortfolioValue > 0 &&
        monthlyContribution >= 0 &&
        yearsUntilRetirement >= 0
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if numberOfRuns <= 0 || numberOfRuns > 100000 {
            errors.append("Number of runs must be between 1 and 100,000")
        }
        if timeHorizonYears <= 0 || timeHorizonYears > 50 {
            errors.append("Time horizon must be between 1 and 50 years")
        }
        if inflationRate < -0.05 || inflationRate > 0.15 {
            errors.append("Inflation rate must be between -5% and 15%")
        }
        if initialPortfolioValue <= 0 {
            errors.append("Initial portfolio value must be positive")
        }
        if monthlyContribution < 0 {
            errors.append("Monthly contribution cannot be negative")
        }
        if yearsUntilRetirement < 0 {
            errors.append("Years until retirement cannot be negative")
        }
        
        return errors
    }
}

// MARK: - Presets

extension SimulationParameters {
    static let conservative = SimulationParameters(
        numberOfRuns: 10000,
        timeHorizonYears: 30,
        inflationRate: 0.03,
        useHistoricalBootstrap: true,
        initialPortfolioValue: 1000000,
        withdrawalConfig: WithdrawalConfiguration(
            strategy: .fixedPercentage,
            withdrawalRate: 0.035
        ),
        inflationStrategy: .historicalCorrelated
    )
    
    static let moderate = SimulationParameters(
        numberOfRuns: 10000,
        timeHorizonYears: 30,
        inflationRate: 0.025,
        useHistoricalBootstrap: true,
        initialPortfolioValue: 1000000,
        withdrawalConfig: WithdrawalConfiguration(
            strategy: .fixedPercentage,
            withdrawalRate: 0.04
        ),
        inflationStrategy: .historicalCorrelated
    )
    
    static let aggressive = SimulationParameters(
        numberOfRuns: 10000,
        timeHorizonYears: 30,
        inflationRate: 0.02,
        useHistoricalBootstrap: true,
        initialPortfolioValue: 1000000,
        withdrawalConfig: WithdrawalConfiguration(
            strategy: .dynamicPercentage,
            withdrawalRate: 0.05
        ),
        inflationStrategy: .historicalCorrelated
    )
}
