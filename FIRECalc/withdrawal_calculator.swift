//
//  WithdrawalCalculator.swift
//  FIRECalc
//
//  CORRECTED - Proper inflation adjustment for withdrawals
//

import Foundation

struct WithdrawalCalculator {
    
    func calculateWithdrawal(
        currentBalance: Double,
        year: Int,
        baselineWithdrawal: Double,
        initialBalance: Double,
        config: WithdrawalConfiguration,
        inflationRate: Double,
        cumulativeInflation: Double = 1.0
    ) -> Double {
        
        switch config.strategy {
        case .fixedPercentage:
            return fixedPercentageRule(
                baselineWithdrawal: baselineWithdrawal,
                initialBalance: initialBalance,
                year: year,
                config: config,
                cumulativeInflation: cumulativeInflation
            )
            
        case .dynamicPercentage:
            return dynamicPercentage(
                currentBalance: currentBalance,
                config: config
            )
            
        case .guardrails:
            return guardrailsStrategy(
                currentBalance: currentBalance,
                baselineWithdrawal: baselineWithdrawal,
                year: year,
                config: config,
                cumulativeInflation: cumulativeInflation
            )
            
        case .rmd:
            return requiredMinimumDistribution(
                currentBalance: currentBalance,
                year: year,
                config: config
            )
            
        case .fixedDollar:
            return fixedDollarAmount(
                year: year,
                config: config,
                cumulativeInflation: cumulativeInflation
            )
            
        case .custom:
            return fixedPercentageRule(
                baselineWithdrawal: baselineWithdrawal,
                initialBalance: initialBalance,
                year: year,
                config: config,
                cumulativeInflation: cumulativeInflation
            )
        }
    }
    
    // MARK: - Strategy Implementations
    
    /// 4% Rule: Withdraw fixed percentage of initial portfolio, adjusted for inflation
    /// CORRECTED: Now uses cumulative inflation instead of compounding parameter
    private func fixedPercentageRule(
        baselineWithdrawal: Double,
        initialBalance: Double,
        year: Int,
        config: WithdrawalConfiguration,
        cumulativeInflation: Double
    ) -> Double {
        
        if year == 1 {
            return initialBalance * config.withdrawalRate
        }
        
        if config.adjustForInflation {
            // Apply cumulative inflation to baseline
            return baselineWithdrawal * cumulativeInflation
        } else {
            return baselineWithdrawal
        }
    }
    
    /// Dynamic Percentage: Withdraw percentage of current portfolio value
    private func dynamicPercentage(
        currentBalance: Double,
        config: WithdrawalConfiguration
    ) -> Double {
        
        var withdrawal = currentBalance * config.withdrawalRate
        
        // Apply floor and ceiling if configured
        if let floor = config.floorPercentage {
            let minWithdrawal = currentBalance * floor
            withdrawal = max(withdrawal, minWithdrawal)
        }
        
        if let ceiling = config.ceilingPercentage {
            let maxWithdrawal = currentBalance * ceiling
            withdrawal = min(withdrawal, maxWithdrawal)
        }
        
        return withdrawal
    }
    
    /// Guardrails (Guyton-Klinger): Adjust withdrawals based on portfolio performance
    private func guardrailsStrategy(
        currentBalance: Double,
        baselineWithdrawal: Double,
        year: Int,
        config: WithdrawalConfiguration,
        cumulativeInflation: Double
    ) -> Double {
        
        // Start with inflation-adjusted baseline
        var withdrawal = baselineWithdrawal * cumulativeInflation
        
        // Calculate current withdrawal rate
        let currentRate = withdrawal / currentBalance
        let targetRate = config.withdrawalRate
        
        // Apply guardrails
        let upperBound = targetRate * (1 + (config.upperGuardrail ?? 0.20))
        let lowerBound = targetRate * (1 - (config.lowerGuardrail ?? 0.15))
        
        if currentRate > upperBound {
            // Portfolio performing poorly - reduce withdrawal by 10%
            withdrawal *= 0.90
        } else if currentRate < lowerBound {
            // Portfolio performing well - increase withdrawal by 10%
            withdrawal *= 1.10
        }
        
        return min(withdrawal, currentBalance) // Never withdraw more than available
    }
    
    /// Required Minimum Distribution: IRS-based withdrawal table
    private func requiredMinimumDistribution(
        currentBalance: Double,
        year: Int,
        config: WithdrawalConfiguration
    ) -> Double {
        
        guard let currentAge = config.currentAge else {
            // Fallback to simple percentage if age not provided
            return currentBalance * config.withdrawalRate
        }
        
        let age = currentAge + year - 1
        let distributionPeriod = rmdDistributionPeriod(for: age)
        
        return currentBalance / distributionPeriod
    }
    
    /// Fixed Dollar Amount: Withdraw fixed amount, optionally adjusted for inflation
    private func fixedDollarAmount(
        year: Int,
        config: WithdrawalConfiguration,
        cumulativeInflation: Double
    ) -> Double {
        
        guard let amount = config.annualAmount else {
            return 0
        }
        
        if config.adjustForInflation {
            return amount * cumulativeInflation
        } else {
            return amount
        }
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
    func projectWithdrawals(
        initialBalance: Double,
        years: Int,
        config: WithdrawalConfiguration,
        inflationRate: Double,
        assumedReturn: Double
    ) -> [Double] {
        
        var balance = initialBalance
        var withdrawals: [Double] = []
        var baselineWithdrawal: Double = 0
        var cumulativeInflation: Double = 1.0
        
        for year in 1...years {
            cumulativeInflation *= (1 + inflationRate)
            
            let withdrawal = calculateWithdrawal(
                currentBalance: balance,
                year: year,
                baselineWithdrawal: baselineWithdrawal,
                initialBalance: initialBalance,
                config: config,
                inflationRate: inflationRate,
                cumulativeInflation: cumulativeInflation
            )
            
            if year == 1 {
                baselineWithdrawal = withdrawal
            }
            
            withdrawals.append(withdrawal)
            
            // Update balance for next year
            balance = balance * (1 + assumedReturn) - withdrawal
            balance = max(0, balance) // Can't go negative
        }
        
        return withdrawals
    }
}
