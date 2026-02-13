//
//  WithdrawalCalculator.swift
//  FIRECalc
//
//  CORRECTED - Works in REAL (inflation-adjusted) terms
//  All amounts are in today's purchasing power
//  No inflation adjustments needed since returns are already real
//

import Foundation

struct WithdrawalCalculator {
    
    /// Calculate withdrawal amount in REAL dollars (today's purchasing power)
    /// Since the Monte Carlo engine works in real terms, we don't need inflation adjustments
    func calculateWithdrawal(
        currentBalance: Double,
        year: Int,
        baselineWithdrawal: Double,
        initialBalance: Double,
        config: WithdrawalConfiguration
    ) -> Double {
        
        var withdrawal: Double
        switch config.strategy {
        case .fixedPercentage:
            withdrawal = fixedPercentageRule(
                baselineWithdrawal: baselineWithdrawal,
                initialBalance: initialBalance,
                year: year,
                config: config
            )
        case .dynamicPercentage:
            withdrawal = dynamicPercentage(
                currentBalance: currentBalance,
                initialBalance: initialBalance,
                config: config
            )
        case .guardrails:
            withdrawal = guardrailsStrategy(
                currentBalance: currentBalance,
                baselineWithdrawal: baselineWithdrawal,
                year: year,
                config: config
            )
        case .rmd:
            withdrawal = requiredMinimumDistribution(
                currentBalance: currentBalance,
                year: year,
                config: config
            )
        case .fixedDollar:
            withdrawal = fixedDollarAmount(
                config: config,
                year: year
            )
        case .custom:
            withdrawal = fixedPercentageRule(
                baselineWithdrawal: baselineWithdrawal,
                initialBalance: initialBalance,
                year: year,
                config: config
            )
        }
        
        // Subtract fixed income (pensions, Social Security) from required withdrawal in REAL dollars
        if let income = config.fixedIncome, income > 0 {
            withdrawal = max(0, withdrawal - income)
        }
        
        return withdrawal
    }
    
    // MARK: - Strategy Implementations
    
    /// 4% Rule: Withdraw fixed percentage of initial portfolio
    /// In real terms, this means the withdrawal stays constant in purchasing power
    private func fixedPercentageRule(
        baselineWithdrawal: Double,
        initialBalance: Double,
        year: Int,
        config: WithdrawalConfiguration
    ) -> Double {
        
        if year == 1 {
            // First year: calculate based on initial balance
            return initialBalance * config.withdrawalRate
        }
        
        // Subsequent years: use the same baseline (already in real dollars)
        // No inflation adjustment needed since we're working in real terms
        return baselineWithdrawal
    }
    
    /// Dynamic Percentage: Withdraw percentage of current portfolio value,
    /// with an optional floor and ceiling expressed as a percentage of the
    /// INITIAL portfolio value (not the current balance).
    ///
    /// Using the initial portfolio value for the dollar floor/ceiling means the
    /// limits represent a real spending level in today's purchasing power — e.g.
    /// "I need at least $40k/year no matter what the market does".  If the limits
    /// were applied as a percentage of the *current* balance they would shrink
    /// with the portfolio and provide no meaningful spending protection.
    private func dynamicPercentage(
        currentBalance: Double,
        initialBalance: Double,
        config: WithdrawalConfiguration
    ) -> Double {

        var withdrawal = currentBalance * config.withdrawalRate

        // Floor and ceiling are percentages applied to the INITIAL balance so
        // they represent fixed real dollar thresholds.
        if let floor = config.floorPercentage {
            let minWithdrawal = initialBalance * floor
            withdrawal = max(withdrawal, minWithdrawal)
        }

        if let ceiling = config.ceilingPercentage {
            let maxWithdrawal = initialBalance * ceiling
            withdrawal = min(withdrawal, maxWithdrawal)
        }

        // Never withdraw more than the remaining balance.
        return min(withdrawal, currentBalance)
    }
    
    /// Guardrails (Guyton-Klinger): Adjust withdrawals based on portfolio performance.
    ///
    /// How it works in the original Guyton-Klinger paper:
    ///   - Each year, compute the *current* withdrawal rate = this year's dollar
    ///     withdrawal / current portfolio value.
    ///   - If the current rate has risen ABOVE the upper guardrail rate (portfolio
    ///     shrank / spending got too high) → cut the dollar withdrawal by 10%.
    ///   - If the current rate has fallen BELOW the lower guardrail rate (portfolio
    ///     grew / spending is very low) → raise the dollar withdrawal by 10%.
    ///   - Otherwise, carry the same dollar withdrawal forward (real-terms constant).
    ///
    /// `upperGuardrail` and `lowerGuardrail` are stored as **absolute withdrawal
    /// rate thresholds** (e.g. 0.06 = 6%, 0.04 = 4%).  In year 1 we set the
    /// baseline from the initial portfolio; guardrail comparisons start in year 2.
    private func guardrailsStrategy(
        currentBalance: Double,
        baselineWithdrawal: Double,
        year: Int,
        config: WithdrawalConfiguration
    ) -> Double {

        // Year 1: establish the baseline dollar withdrawal straight from the
        // initial rate — no guardrail check yet.
        if year == 1 {
            return currentBalance * config.withdrawalRate
        }

        // Carry forward the previous year's dollar amount, then check guardrails.
        var withdrawal = baselineWithdrawal

        // Current withdrawal rate = what we'd withdraw as a % of today's portfolio.
        let currentRate = withdrawal / currentBalance

        // Absolute guardrail thresholds (default: initial rate ±25 / 20%).
        let upperBound = config.upperGuardrail ?? (config.withdrawalRate * 1.25)
        let lowerBound = config.lowerGuardrail ?? (config.withdrawalRate * 0.80)
        
        let magnitude = config.guardrailAdjustmentMagnitude ?? 0.10
        if currentRate > upperBound {
            // Portfolio has shrunk — current rate is dangerously high. Cut by configured magnitude.
            withdrawal *= (1.0 - magnitude)
        } else if currentRate < lowerBound {
            // Portfolio has grown — current rate is very low. Raise by configured magnitude.
            withdrawal *= (1.0 + magnitude)
        }

        return min(withdrawal, currentBalance)
    }
    
    /// Required Minimum Distribution: IRS-based withdrawal table
    private func requiredMinimumDistribution(
        currentBalance: Double,
        year: Int,
        config: WithdrawalConfiguration
    ) -> Double {

        // currentAge is required for RMD. If it is missing the user most likely
        // set up RMD without providing their age; fall back to the configured
        // withdrawal rate so the simulation is still meaningful rather than
        // silently returning an arbitrary number.
        guard let currentAge = config.currentAge else {
            return currentBalance * config.withdrawalRate
        }

        let age = currentAge + year - 1
        let distributionPeriod = rmdDistributionPeriod(for: age)

        return currentBalance / distributionPeriod
    }
    
    /// Fixed Dollar Amount: Withdraw a fixed amount each year.
    ///
    /// The engine works in REAL (inflation-adjusted) terms, so:
    /// - `adjustForInflation = true`  → return the amount as-is; the real-return
    ///   arithmetic already keeps purchasing power constant.
    /// - `adjustForInflation = false` → the user wants a *nominal* fixed payment
    ///   (e.g. a mortgage).  We store the inflation rate inside the config so we
    ///   can erode the real value by dividing by (1 + inflationRate)^(year-1).
    ///   If no inflation rate is stored we treat it as inflation-adjusted for safety.
    private func fixedDollarAmount(
        config: WithdrawalConfiguration,
        year: Int
    ) -> Double {
        guard let amount = config.annualAmount, amount > 0 else {
            return 0
        }

        guard !config.adjustForInflation, let inflation = config.inflationRate, inflation > 0 else {
            // Inflation-adjusted (or no rate available): constant real purchasing power.
            return amount
        }

        // Nominal fixed: erode real value over time so the actual portfolio draw
        // shrinks in real terms, just as a fixed nominal payment does.
        let realAmount = amount / pow(1 + inflation, Double(year - 1))
        return realAmount
    }
    
    // MARK: - RMD Life Expectancy Table
    
    /// IRS Uniform Lifetime Table for RMD calculations
    private func rmdDistributionPeriod(for age: Int) -> Double {
        switch age {
        case ...71: return 27.4
        case 72: return 27.4
        case 73: return 26.5
        case 74: return 25.5
        case 75: return 24.6
        case 76: return 23.7
        case 77: return 22.9
        case 78: return 22.0
        case 79: return 21.1
        case 80: return 20.2
        case 81: return 19.4
        case 82: return 18.5
        case 83: return 17.7
        case 84: return 16.8
        case 85: return 16.0
        case 86: return 15.2
        case 87: return 14.4
        case 88: return 13.7
        case 89: return 12.9
        case 90: return 12.2
        case 91: return 11.5
        case 92: return 10.8
        case 93: return 10.1
        case 94: return 9.5
        case 95: return 8.9
        case 96: return 8.4
        case 97: return 7.8
        case 98: return 7.3
        case 99: return 6.8
        case 100: return 6.4
        case 101: return 6.0
        case 102: return 5.6
        case 103: return 5.2
        case 104: return 4.9
        case 105: return 4.6
        case 106: return 4.3
        case 107: return 4.1
        case 108: return 3.9
        case 109: return 3.7
        case 110: return 3.5
        case 111: return 3.4
        case 112: return 3.3
        case 113: return 3.1
        case 114: return 3.0
        case 115...: return 2.9
        default: return 27.4
        }
    }
}

// MARK: - Withdrawal Projection

extension WithdrawalCalculator {
    
    /// Calculate projected withdrawals for the entire retirement period
    /// Returns amounts in REAL dollars (constant purchasing power)
    func projectWithdrawals(
        initialBalance: Double,
        years: Int,
        config: WithdrawalConfiguration,
        assumedRealReturn: Double  // This should be a REAL return (e.g., 0.05 for 5% real)
    ) -> [Double] {
        
        var balance = initialBalance
        var withdrawals: [Double] = []
        var baselineWithdrawal: Double = 0
        
        for year in 1...years {
            let withdrawal = calculateWithdrawal(
                currentBalance: balance,
                year: year,
                baselineWithdrawal: baselineWithdrawal,
                initialBalance: initialBalance,
                config: config
            )
            
            if year == 1 {
                baselineWithdrawal = withdrawal
            }
            
            withdrawals.append(withdrawal)
            
            // Update balance for next year using REAL return
            balance = balance * (1 + assumedRealReturn) - withdrawal
            balance = max(0, balance) // Can't go negative
        }
        
        return withdrawals
    }
}

