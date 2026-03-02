//
//  TimeBasedIncomeExample.swift
//  FIRECalc
//
//  Example: How to use time-based income in Monte Carlo simulations
//

import Foundation

// MARK: - Example 1: Simple Early Retirement with Delayed Social Security

/// Scenario: Retire at 60, Social Security starts at 67
func exampleEarlyRetirementWithSocialSecurity(
    portfolio: Portfolio,
    historicalData: HistoricalData
) async throws -> SimulationResult {
    
    // Define Social Security starting at age 67
    let socialSecurity = ScheduledIncome(
        name: "Social Security",
        annualAmount: 30_000,
        startAge: 67,
        inflationAdjusted: true  // COLA-adjusted
    )
    
    let params = SimulationParameters(
        numberOfRuns: 10_000,
        timeHorizonYears: 30,  // Age 60 to 90
        inflationRate: 0.025,
        useHistoricalBootstrap: true,
        initialPortfolioValue: portfolio.totalValue,
        retirementAge: 60,  // Critical: sets the baseline age
        withdrawalConfig: WithdrawalConfiguration(
            strategy: .fixedPercentage,
            withdrawalRate: 0.04
        ),
        incomeSchedule: [socialSecurity]
    )
    
    let engine = MonteCarloEngine()
    return try await engine.runSimulation(
        portfolio: portfolio,
        parameters: params,
        historicalData: historicalData
    )
}

// MARK: - Example 2: Multiple Income Sources at Different Ages

/// Scenario: Retire at 55, pension at 62, Social Security at 70 (delayed)
func exampleBridgeStrategyWithMultipleIncome(
    portfolio: Portfolio,
    historicalData: HistoricalData
) async throws -> SimulationResult {
    
    let pension = ScheduledIncome(
        name: "Company Pension",
        annualAmount: 24_000,
        startAge: 62,
        inflationAdjusted: false  // Fixed nominal (not COLA-adjusted)
    )
    
    let socialSecurity = ScheduledIncome(
        name: "Social Security (Delayed)",
        annualAmount: 40_000,  // Higher due to delayed claiming
        startAge: 70,
        inflationAdjusted: true
    )
    
    let params = SimulationParameters(
        numberOfRuns: 10_000,
        timeHorizonYears: 35,  // Age 55 to 90
        inflationRate: 0.03,
        useHistoricalBootstrap: true,
        initialPortfolioValue: portfolio.totalValue,
        retirementAge: 55,
        withdrawalConfig: WithdrawalConfiguration(
            strategy: .guardrails,
            withdrawalRate: 0.04,
            upperGuardrail: 0.05,
            lowerGuardrail: 0.03,
            guardrailAdjustmentMagnitude: 0.10
        ),
        incomeSchedule: [pension, socialSecurity]
    )
    
    let engine = MonteCarloEngine()
    return try await engine.runSimulation(
        portfolio: portfolio,
        parameters: params,
        historicalData: historicalData
    )
}

// MARK: - Example 3: Converting from DefinedBenefitManager

/// Show how to automatically convert existing DefinedBenefitPlans to income schedule
@MainActor
func exampleConvertFromBenefitPlans(
    portfolio: Portfolio,
    benefitManager: DefinedBenefitManager,
    retirementAge: Int,
    historicalData: HistoricalData
) async throws -> SimulationResult {
    
    // Automatically create time-aware income schedule from defined benefit plans
    let incomeSchedule = benefitManager.createIncomeSchedule()
    
    let params = SimulationParameters(
        numberOfRuns: 10_000,
        timeHorizonYears: 30,
        inflationRate: 0.025,
        useHistoricalBootstrap: true,
        initialPortfolioValue: portfolio.totalValue,
        retirementAge: retirementAge,
        withdrawalConfig: WithdrawalConfiguration(
            strategy: .fixedPercentage,
            withdrawalRate: 0.04
        ),
        incomeSchedule: incomeSchedule  // Handles all time-based logic automatically
    )
    
    let engine = MonteCarloEngine()
    return try await engine.runSimulation(
        portfolio: portfolio,
        parameters: params,
        historicalData: historicalData
    )
}

// MARK: - Example 4: Time-Limited Income (Annuity)

/// Scenario: Fixed annuity pays from age 65 to 80, then stops
func exampleTimeLimitedIncome(
    portfolio: Portfolio,
    historicalData: HistoricalData
) async throws -> SimulationResult {
    
    let fixedAnnuity = ScheduledIncome(
        name: "15-Year Fixed Annuity",
        annualAmount: 50_000,
        startAge: 65,
        endAge: 80,  // Stops at age 80
        inflationAdjusted: false  // Fixed nominal payout
    )
    
    let socialSecurity = ScheduledIncome(
        name: "Social Security",
        annualAmount: 35_000,
        startAge: 67,
        inflationAdjusted: true
    )
    
    let params = SimulationParameters(
        numberOfRuns: 10_000,
        timeHorizonYears: 30,  // Age 60 to 90
        inflationRate: 0.025,
        useHistoricalBootstrap: true,
        initialPortfolioValue: portfolio.totalValue,
        retirementAge: 60,
        withdrawalConfig: WithdrawalConfiguration(
            strategy: .dynamicPercentage,
            withdrawalRate: 0.045,
            floorPercentage: 0.03,  // Minimum 3% of initial portfolio
            ceilingPercentage: 0.06  // Maximum 6% of initial portfolio
        ),
        incomeSchedule: [fixedAnnuity, socialSecurity]
    )
    
    let engine = MonteCarloEngine()
    return try await engine.runSimulation(
        portfolio: portfolio,
        parameters: params,
        historicalData: historicalData
    )
}

// MARK: - Example 5: Visualizing Income Timeline

/// Helper to show when different income sources activate over retirement
struct IncomeTimeline {
    let retirementAge: Int
    let incomeSchedule: [ScheduledIncome]
    let years: Int
    
    /// Generate a year-by-year breakdown showing which income sources are active
    func generateTimeline(inflationRate: Double = 0.025) -> [YearlyIncome] {
        var timeline: [YearlyIncome] = []
        
        for year in 1...years {
            let age = retirementAge + year - 1
            var activeIncome: [IncomeSource] = []
            var totalIncome: Double = 0
            
            for income in incomeSchedule {
                let realAmount = income.realIncome(
                    at: age,
                    inflationRate: inflationRate,
                    yearsIntoRetirement: year
                )
                
                if realAmount > 0 {
                    activeIncome.append(
                        IncomeSource(
                            name: income.name,
                            amount: realAmount,
                            isReal: income.inflationAdjusted
                        )
                    )
                    totalIncome += realAmount
                }
            }
            
            timeline.append(
                YearlyIncome(
                    year: year,
                    age: age,
                    sources: activeIncome,
                    totalIncome: totalIncome
                )
            )
        }
        
        return timeline
    }
    
    struct YearlyIncome {
        let year: Int
        let age: Int
        let sources: [IncomeSource]
        let totalIncome: Double
        
        var description: String {
            let sourcesList = sources.map { "\($0.name): $\(Int($0.amount))" }.joined(separator: ", ")
            return "Year \(year) (Age \(age)): \(sourcesList) | Total: $\(Int(totalIncome))"
        }
    }
    
    struct IncomeSource {
        let name: String
        let amount: Double
        let isReal: Bool  // true = COLA, false = nominal
    }
}

// MARK: - Example 6: Comparing Different Social Security Claiming Strategies

/// Compare retiring at 62 with SS at 62 vs. 67 vs. 70
func exampleCompareClaimingStrategies(
    portfolio: Portfolio,
    historicalData: HistoricalData
) async throws -> [String: SimulationResult] {
    
    let retirementAge = 62
    let engine = MonteCarloEngine()
    
    // Strategy 1: Claim immediately at 62 (reduced benefit)
    let ss62 = ScheduledIncome(
        name: "Social Security (Age 62)",
        annualAmount: 21_000,  // ~30% reduction for early claiming
        startAge: 62,
        inflationAdjusted: true
    )
    
    let params62 = SimulationParameters(
        numberOfRuns: 10_000,
        timeHorizonYears: 30,
        inflationRate: 0.025,
        useHistoricalBootstrap: true,
        initialPortfolioValue: portfolio.totalValue,
        retirementAge: retirementAge,
        withdrawalConfig: WithdrawalConfiguration(strategy: .fixedPercentage, withdrawalRate: 0.04),
        incomeSchedule: [ss62]
    )
    
    // Strategy 2: Claim at FRA 67 (full benefit)
    let ss67 = ScheduledIncome(
        name: "Social Security (Age 67)",
        annualAmount: 30_000,  // Full benefit
        startAge: 67,
        inflationAdjusted: true
    )
    
    let params67 = SimulationParameters(
        numberOfRuns: 10_000,
        timeHorizonYears: 30,
        inflationRate: 0.025,
        useHistoricalBootstrap: true,
        initialPortfolioValue: portfolio.totalValue,
        retirementAge: retirementAge,
        withdrawalConfig: WithdrawalConfiguration(strategy: .fixedPercentage, withdrawalRate: 0.04),
        incomeSchedule: [ss67]
    )
    
    // Strategy 3: Delay to 70 (maximum benefit)
    let ss70 = ScheduledIncome(
        name: "Social Security (Age 70)",
        annualAmount: 37_200,  // ~24% increase for delayed claiming
        startAge: 70,
        inflationAdjusted: true
    )
    
    let params70 = SimulationParameters(
        numberOfRuns: 10_000,
        timeHorizonYears: 30,
        inflationRate: 0.025,
        useHistoricalBootstrap: true,
        initialPortfolioValue: portfolio.totalValue,
        retirementAge: retirementAge,
        withdrawalConfig: WithdrawalConfiguration(strategy: .fixedPercentage, withdrawalRate: 0.04),
        incomeSchedule: [ss70]
    )
    
    // Run all three strategies
    let result62 = try await engine.runSimulation(portfolio: portfolio, parameters: params62, historicalData: historicalData)
    let result67 = try await engine.runSimulation(portfolio: portfolio, parameters: params67, historicalData: historicalData)
    let result70 = try await engine.runSimulation(portfolio: portfolio, parameters: params70, historicalData: historicalData)
    
    return [
        "Claim at 62": result62,
        "Claim at 67": result67,
        "Claim at 70": result70
    ]
}

// MARK: - Example 7: Real-World Complex Scenario

/// Complete scenario: Early retirement with multiple income phases
func exampleComplexRealWorld(
    portfolio: Portfolio,
    historicalData: HistoricalData
) async throws -> SimulationResult {
    
    // Phase 1 (Age 58-62): Portfolio withdrawals only
    // Phase 2 (Age 62-67): Add pension
    // Phase 3 (Age 67-75): Add Social Security
    // Phase 4 (Age 75+): Add rental income from downsizing
    
    let pension = ScheduledIncome(
        name: "Company Pension",
        annualAmount: 28_000,
        startAge: 62,
        inflationAdjusted: false
    )
    
    let socialSecurity = ScheduledIncome(
        name: "Social Security",
        annualAmount: 32_000,
        startAge: 67,
        inflationAdjusted: true
    )
    
    let rentalIncome = ScheduledIncome(
        name: "Rental Income (Downsized Home)",
        annualAmount: 18_000,
        startAge: 75,  // Plan to downsize at 75
        inflationAdjusted: false  // Fixed lease terms
    )
    
    let params = SimulationParameters(
        numberOfRuns: 10_000,
        timeHorizonYears: 32,  // Age 58 to 90
        inflationRate: 0.03,
        useHistoricalBootstrap: true,
        initialPortfolioValue: portfolio.totalValue,
        retirementAge: 58,
        withdrawalConfig: WithdrawalConfiguration(
            strategy: .guardrails,
            withdrawalRate: 0.045,
            upperGuardrail: 0.055,
            lowerGuardrail: 0.035,
            guardrailAdjustmentMagnitude: 0.10
        ),
        incomeSchedule: [pension, socialSecurity, rentalIncome]
    )
    
    let engine = MonteCarloEngine()
    let result = try await engine.runSimulation(
        portfolio: portfolio,
        parameters: params,
        historicalData: historicalData
    )
    
    // Print timeline for verification
    let timeline = IncomeTimeline(
        retirementAge: 58,
        incomeSchedule: params.incomeSchedule ?? [],
        years: 32
    )
    
    print("\n=== Income Timeline ===")
    for yearlyIncome in timeline.generateTimeline(inflationRate: 0.03).prefix(15) {
        print(yearlyIncome.description)
    }
    print("...")
    
    return result
}

// MARK: - Usage in a View Model

@MainActor
class ExampleSimulationViewModel: ObservableObject {
    @Published var portfolio: Portfolio
    @Published var benefitManager: DefinedBenefitManager
    @Published var retirementAge: Int = 65
    
    init(portfolio: Portfolio, benefitManager: DefinedBenefitManager) {
        self.portfolio = portfolio
        self.benefitManager = benefitManager
    }
    
    /// Run simulation with time-aware income handling
    func runSimulationWithTimeBasedIncome() async throws -> SimulationResult {
        let incomeSchedule = benefitManager.createIncomeSchedule()
        
        // Validate retirement age vs income start ages
        let earliestIncomeAge = incomeSchedule.map { $0.startAge }.min() ?? retirementAge
        if retirementAge > earliestIncomeAge {
            print("⚠️ Warning: Retirement age (\(retirementAge)) is after first income starts (\(earliestIncomeAge))")
        }
        
        let params = SimulationParameters(
            numberOfRuns: 10_000,
            timeHorizonYears: 30,
            inflationRate: 0.025,
            useHistoricalBootstrap: true,
            initialPortfolioValue: portfolio.totalValue,
            retirementAge: retirementAge,
            withdrawalConfig: WithdrawalConfiguration(
                strategy: .fixedPercentage,
                withdrawalRate: 0.04
            ),
            incomeSchedule: incomeSchedule
        )
        
        let engine = MonteCarloEngine()
        let historicalData = try HistoricalDataService.shared.loadHistoricalData()
        
        return try await engine.runSimulation(
            portfolio: portfolio,
            parameters: params,
            historicalData: historicalData
        )
    }
    
    /// Preview income timeline before running simulation
    func previewIncomeTimeline() -> [String] {
        let incomeSchedule = benefitManager.createIncomeSchedule()
        let timeline = IncomeTimeline(
            retirementAge: retirementAge,
            incomeSchedule: incomeSchedule,
            years: 30
        )
        
        return timeline.generateTimeline().map { $0.description }
    }
}
