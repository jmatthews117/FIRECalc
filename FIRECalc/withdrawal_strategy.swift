//
//  WithdrawalStrategy.swift
//  FIRECalc
//
//  Defines different retirement withdrawal strategies
//

import Foundation

enum WithdrawalStrategy: String, Codable, CaseIterable, Identifiable {
    case fixedPercentage = "4% Rule (Fixed Percentage)"
    case dynamicPercentage = "Dynamic Percentage"
    case guardrails = "Guardrails (Guyton-Klinger)"
    case rmd = "Required Minimum Distribution"
    case fixedDollar = "Fixed Dollar Amount"
    case custom = "Custom Strategy"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .fixedPercentage:
            return "Withdraw a fixed percentage of the initial portfolio each year, adjusted for inflation."
        case .dynamicPercentage:
            return "Withdraw a percentage of the current portfolio value each year."
        case .guardrails:
            return "Adjust withdrawals based on portfolio performance with upper and lower guardrails."
        case .rmd:
            return "Withdraw based on IRS Required Minimum Distribution tables."
        case .fixedDollar:
            return "Withdraw a fixed dollar amount each year, adjusted for inflation."
        case .custom:
            return "Define your own withdrawal parameters and rules."
        }
    }
    
    var defaultPercentage: Double {
        switch self {
        case .fixedPercentage: return 0.04  // 4%
        case .dynamicPercentage: return 0.04
        case .guardrails: return 0.05       // 5% with guardrails
        case .rmd: return 0.04              // Varies by age
        case .fixedDollar: return 0.04
        case .custom: return 0.04
        }
    }
    
    // Configuration parameters needed for this strategy
    var requiredParameters: [StrategyParameter] {
        switch self {
        case .fixedPercentage:
            return [.withdrawalRate, .adjustForInflation]
        case .dynamicPercentage:
            return [.withdrawalRate, .floorPercentage, .ceilingPercentage]
        case .guardrails:
            return [.withdrawalRate, .upperGuardrail, .lowerGuardrail, .guardrailAdjustmentMagnitude]
        case .rmd:
            return [.currentAge, .birthYear]
        case .fixedDollar:
            return [.annualAmount, .adjustForInflation]
        case .custom:
            return [.withdrawalRate, .customRules]
        }
    }
}

enum StrategyParameter: String {
    case withdrawalRate = "Withdrawal Rate"
    case adjustForInflation = "Adjust for Inflation"
    case floorPercentage = "Floor Percentage"
    case ceilingPercentage = "Ceiling Percentage"
    case upperGuardrail = "Upper Guardrail"
    case lowerGuardrail = "Lower Guardrail"
    case guardrailAdjustmentMagnitude = "Adjustment Magnitude"
    case currentAge = "Current Age"
    case birthYear = "Birth Year"
    case annualAmount = "Annual Amount"
    case customRules = "Custom Rules"
}

// Configuration for a specific withdrawal strategy
struct WithdrawalConfiguration: Codable {
    var strategy: WithdrawalStrategy
    var withdrawalRate: Double
    var annualAmount: Double?
    var adjustForInflation: Bool

    /// The simulation's inflation rate, forwarded here so that the
    /// Fixed Dollar strategy can model a *nominal* fixed payment correctly.
    /// Only used when `strategy == .fixedDollar && adjustForInflation == false`.
    var inflationRate: Double?

    // Fixed income that offsets withdrawals (pensions, Social Security)
    var fixedIncome: Double?
    
    // Guardrails parameters
    var upperGuardrail: Double?  // e.g., 0.20 (20% above baseline)
    var lowerGuardrail: Double?  // e.g., 0.15 (15% below baseline)
    var guardrailAdjustmentMagnitude: Double? // e.g., 0.10 for ±10%
    
    // Dynamic percentage limits
    var floorPercentage: Double? // Minimum withdrawal as % of portfolio
    var ceilingPercentage: Double? // Maximum withdrawal as % of portfolio
    
    // RMD parameters
    var currentAge: Int?
    var birthYear: Int?
    
    init(
        strategy: WithdrawalStrategy = .fixedPercentage,
        withdrawalRate: Double = 0.04,
        annualAmount: Double? = nil,
        adjustForInflation: Bool = true,
        inflationRate: Double? = nil,
        fixedIncome: Double? = nil,
        upperGuardrail: Double? = nil,
        lowerGuardrail: Double? = nil,
        guardrailAdjustmentMagnitude: Double? = nil,
        floorPercentage: Double? = nil,
        ceilingPercentage: Double? = nil,
        currentAge: Int? = nil,
        birthYear: Int? = nil
    ) {
        self.strategy = strategy
        self.withdrawalRate = withdrawalRate
        self.annualAmount = annualAmount
        self.adjustForInflation = adjustForInflation
        self.inflationRate = inflationRate
        self.fixedIncome = fixedIncome
        self.upperGuardrail = upperGuardrail
        self.lowerGuardrail = lowerGuardrail
        self.guardrailAdjustmentMagnitude = guardrailAdjustmentMagnitude
        self.floorPercentage = floorPercentage
        self.ceilingPercentage = ceilingPercentage
        self.currentAge = currentAge
        self.birthYear = birthYear
    }
}

