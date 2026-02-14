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
    case fixedDollar = "Fixed Dollar Amount"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .fixedPercentage:
            return "Withdraw a fixed percentage of the initial portfolio each year, adjusted for inflation."
        case .dynamicPercentage:
            return "Withdraw a percentage of the current portfolio value each year."
        case .guardrails:
            return "Adjust withdrawals based on portfolio performance with upper and lower guardrails."
        case .fixedDollar:
            return "Withdraw a fixed dollar amount each year, adjusted for inflation."
        }
    }
    
    var defaultPercentage: Double {
        switch self {
        case .fixedPercentage: return 0.04  // 4%
        case .dynamicPercentage: return 0.04
        case .guardrails: return 0.05       // 5% with guardrails
        case .fixedDollar: return 0.04
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
        case .fixedDollar:
            return [.annualAmount, .adjustForInflation]
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
    case annualAmount = "Annual Amount"
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

    // Fixed income that offsets withdrawals (pensions, Social Security).
    //
    // Split into two buckets so the engine can apply the correct real-term
    // treatment to each without needing access to the full plan list:
    //
    //   fixedIncomeReal    — COLA-adjusted plans (e.g. Social Security).
    //                        Real value is constant; subtract the same amount
    //                        every year.
    //
    //   fixedIncomeNominal — Fixed-nominal plans (e.g. most pensions).
    //                        Real value erodes with inflation; the engine
    //                        divides by (1 + inflationRate)^(year-1) each year.
    //
    // Both default to nil (no income) so existing configs deserialise cleanly.
    var fixedIncomeReal: Double?
    var fixedIncomeNominal: Double?

    /// Convenience: total face-value income across both buckets (used for UI display).
    var totalFixedIncome: Double {
        (fixedIncomeReal ?? 0) + (fixedIncomeNominal ?? 0)
    }

    // Back-compat alias so any remaining call sites that read fixedIncome still compile.
    var fixedIncome: Double? {
        get { totalFixedIncome > 0 ? totalFixedIncome : nil }
        set {
            // Legacy setter: treat the whole amount as real (COLA). Callers that
            // know the split should set fixedIncomeReal/fixedIncomeNominal directly.
            fixedIncomeReal = newValue
            fixedIncomeNominal = nil
        }
    }
    
    // Guardrails parameters
    var upperGuardrail: Double?  // e.g., 0.20 (20% above baseline)
    var lowerGuardrail: Double?  // e.g., 0.15 (15% below baseline)
    var guardrailAdjustmentMagnitude: Double? // e.g., 0.10 for ±10%
    
    // Dynamic percentage limits
    var floorPercentage: Double? // Minimum withdrawal as % of portfolio
    var ceilingPercentage: Double? // Maximum withdrawal as % of portfolio
    
    init(
        strategy: WithdrawalStrategy = .fixedPercentage,
        withdrawalRate: Double = 0.04,
        annualAmount: Double? = nil,
        adjustForInflation: Bool = true,
        inflationRate: Double? = nil,
        fixedIncomeReal: Double? = nil,
        fixedIncomeNominal: Double? = nil,
        upperGuardrail: Double? = nil,
        lowerGuardrail: Double? = nil,
        guardrailAdjustmentMagnitude: Double? = nil,
        floorPercentage: Double? = nil,
        ceilingPercentage: Double? = nil
    ) {
        self.strategy = strategy
        self.withdrawalRate = withdrawalRate
        self.annualAmount = annualAmount
        self.adjustForInflation = adjustForInflation
        self.inflationRate = inflationRate
        self.fixedIncomeReal = fixedIncomeReal
        self.fixedIncomeNominal = fixedIncomeNominal
        self.upperGuardrail = upperGuardrail
        self.lowerGuardrail = lowerGuardrail
        self.guardrailAdjustmentMagnitude = guardrailAdjustmentMagnitude
        self.floorPercentage = floorPercentage
        self.ceilingPercentage = ceilingPercentage
    }
}

