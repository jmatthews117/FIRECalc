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

    // Target portfolio value override
    /// When non-nil, the simulation uses this as the starting balance instead of
    /// `initialPortfolioValue`.  Useful for "what-if I reach $X before retiring" scenarios.
    var targetPortfolioValue: Double?

    // Retirement age tracking
    /// The age at which retirement begins (year 0 of the simulation).
    /// Used to determine when age-based income sources like Social Security start.
    var retirementAge: Int?

    // Custom asset allocation override
    /// Fractional weights keyed by asset class (must sum to ≈ 1.0).
    /// When non-nil, the engine uses these weights instead of the live portfolio allocation.
    var customAllocationWeights: [AssetClass: Double]?
    
    // Withdrawal configuration
    var withdrawalConfig: WithdrawalConfiguration
    
    // Time-based income sources (pensions, Social Security, etc.)
    /// Replaces the simple fixedIncome offset with a full schedule that tracks
    /// when each income source starts and whether it's inflation-adjusted.
    var incomeSchedule: [ScheduledIncome]?
    
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

    /// The effective starting balance: target override if set, otherwise current portfolio value.
    var effectiveInitialValue: Double {
        targetPortfolioValue ?? initialPortfolioValue
    }
    
    init(
        numberOfRuns: Int = 10000,
        timeHorizonYears: Int = 30,
        inflationRate: Double = 0.02,
        useHistoricalBootstrap: Bool = true,
        initialPortfolioValue: Double,
        targetPortfolioValue: Double? = nil,
        retirementAge: Int? = nil,
        customAllocationWeights: [AssetClass: Double]? = nil,
        withdrawalConfig: WithdrawalConfiguration = WithdrawalConfiguration(),
        taxRate: Double? = nil,
        rngSeed: UInt64? = nil,
        bootstrapBlockLength: Int? = nil,
        customReturns: [AssetClass: Double]? = nil,
        customVolatility: [AssetClass: Double]? = nil,
        inflationStrategy: InflationStrategy = .historicalCorrelated,
        incomeSchedule: [ScheduledIncome]? = nil
    ) {
        self.numberOfRuns = numberOfRuns
        self.timeHorizonYears = timeHorizonYears
        self.inflationRate = inflationRate
        self.useHistoricalBootstrap = useHistoricalBootstrap
        self.initialPortfolioValue = initialPortfolioValue
        self.targetPortfolioValue = targetPortfolioValue
        self.retirementAge = retirementAge
        self.customAllocationWeights = customAllocationWeights
        self.withdrawalConfig = withdrawalConfig
        self.incomeSchedule = incomeSchedule
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
        effectiveInitialValue > 0 &&
        customAllocationWeightsAreValid
    }

    /// Returns true when no custom weights are set, or when the provided weights
    /// sum to between 0.99 and 1.01 (tolerates floating-point rounding).
    var customAllocationWeightsAreValid: Bool {
        guard let weights = customAllocationWeights else { return true }
        let total = weights.values.reduce(0, +)
        return (0.99...1.01).contains(total)
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
        if effectiveInitialValue <= 0 {
            errors.append("Initial portfolio value must be positive")
        }
        if !customAllocationWeightsAreValid {
            errors.append("Custom allocation weights must sum to 100%")
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

// MARK: - Scheduled Income
/// Represents a time-based income source (pension, Social Security, annuity, etc.)
/// that starts at a specific age and may or may not be inflation-adjusted.
struct ScheduledIncome: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var annualAmount: Double
    var startAge: Int
    var endAge: Int?  // nil means continues until end of simulation
    var inflationAdjusted: Bool  // true = COLA (constant real value), false = fixed nominal
    
    init(
        id: UUID = UUID(),
        name: String,
        annualAmount: Double,
        startAge: Int,
        endAge: Int? = nil,
        inflationAdjusted: Bool
    ) {
        self.id = id
        self.name = name
        self.annualAmount = annualAmount
        self.startAge = startAge
        self.endAge = endAge
        self.inflationAdjusted = inflationAdjusted
    }
    
    /// Returns the real (inflation-adjusted) value of this income source at a given
    /// age, or 0 if the income hasn't started yet or has ended.
    func realIncome(at age: Int, inflationRate: Double, yearsIntoRetirement: Int) -> Double {
        // Check if income is active at this age
        guard age >= startAge else { return 0 }
        if let end = endAge, age > end { return 0 }
        
        if inflationAdjusted {
            // COLA-adjusted: real value stays constant
            return annualAmount
        } else {
            // Fixed nominal: real purchasing power erodes with inflation
            // Calculate years since THIS income source started (not since retirement)
            let yearsSinceIncomeStarted = age - startAge
            return annualAmount / pow(1 + inflationRate, Double(yearsSinceIncomeStarted))
        }
    }
}

// MARK: - Income Schedule Helpers

extension SimulationParameters {
    
    /// Calculate total real income from all scheduled sources at a specific year
    /// into retirement, given the current age.
    func totalScheduledIncome(year: Int) -> Double {
        guard let schedule = incomeSchedule, let retAge = retirementAge else { return 0 }
        
        let currentAge = retAge + year - 1  // year 1 = retirement age
        
        return schedule.reduce(0) { total, income in
            total + income.realIncome(at: currentAge, inflationRate: inflationRate, yearsIntoRetirement: year)
        }
    }
    
    /// Create an income schedule from DefinedBenefitPlans
    static func createIncomeSchedule(from plans: [DefinedBenefitPlan]) -> [ScheduledIncome] {
        return plans.map { plan in
            ScheduledIncome(
                id: plan.id,
                name: plan.name,
                annualAmount: plan.annualBenefit,
                startAge: plan.startAge,
                endAge: nil,  // Plans continue indefinitely
                inflationAdjusted: plan.inflationAdjusted
            )
        }
    }
}


