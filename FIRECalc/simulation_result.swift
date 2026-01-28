//
//  SimulationResult.swift
//  FIRECalc
//
//  Output from Monte Carlo simulation runs
//

import Foundation

struct SimulationResult: Codable, Identifiable {
    let id: UUID
    let runDate: Date
    let parameters: SimulationParameters
    
    // Aggregate statistics
    let successRate: Double  // % of runs where money lasted full horizon
    let medianFinalBalance: Double
    let meanFinalBalance: Double
    
    // Percentile outcomes
    let percentile10: Double  // 10th percentile final balance
    let percentile25: Double
    let percentile50: Double  // Median
    let percentile75: Double
    let percentile90: Double
    
    // Year-by-year projections (median values)
    let yearlyBalances: [YearlyProjection]
    
    // Distribution of outcomes
    let finalBalanceDistribution: [Double]  // All final balances for histogram
    
    // Withdrawal statistics
    let totalWithdrawn: Double  // Median total withdrawn
    let averageAnnualWithdrawal: Double
    
    // Risk metrics
    let probabilityOfRuin: Double  // % chance of running out of money
    let yearsUntilRuin: Double?  // Average years until depletion (if applicable)
    let maxDrawdown: Double  // Largest portfolio decline
    
    init(
        id: UUID = UUID(),
        runDate: Date = Date(),
        parameters: SimulationParameters,
        successRate: Double,
        medianFinalBalance: Double,
        meanFinalBalance: Double,
        percentile10: Double,
        percentile25: Double,
        percentile50: Double,
        percentile75: Double,
        percentile90: Double,
        yearlyBalances: [YearlyProjection],
        finalBalanceDistribution: [Double],
        totalWithdrawn: Double,
        averageAnnualWithdrawal: Double,
        probabilityOfRuin: Double,
        yearsUntilRuin: Double?,
        maxDrawdown: Double
    ) {
        self.id = id
        self.runDate = runDate
        self.parameters = parameters
        self.successRate = successRate
        self.medianFinalBalance = medianFinalBalance
        self.meanFinalBalance = meanFinalBalance
        self.percentile10 = percentile10
        self.percentile25 = percentile25
        self.percentile50 = percentile50
        self.percentile75 = percentile75
        self.percentile90 = percentile90
        self.yearlyBalances = yearlyBalances
        self.finalBalanceDistribution = finalBalanceDistribution
        self.totalWithdrawn = totalWithdrawn
        self.averageAnnualWithdrawal = averageAnnualWithdrawal
        self.probabilityOfRuin = probabilityOfRuin
        self.yearsUntilRuin = yearsUntilRuin
        self.maxDrawdown = maxDrawdown
    }
}

// Year-by-year median projection
struct YearlyProjection: Codable, Identifiable {
    let year: Int
    let medianBalance: Double
    let percentile10Balance: Double
    let percentile90Balance: Double
    let medianWithdrawal: Double
    
    var id: Int { year }
}

// Individual simulation run (for detailed analysis)
struct SimulationRun: Codable {
    let runNumber: Int
    let yearlyBalances: [Double]
    let yearlyWithdrawals: [Double]
    let finalBalance: Double
    let success: Bool  // Did money last the full horizon?
    let yearsLasted: Int  // How many years did the money last?
}

// MARK: - Sample Result for Previews

extension SimulationResult {
    static let sample: SimulationResult = {
        // Pre-compute yearly balances to avoid compiler timeout
        let yearlyBalances: [YearlyProjection] = (0...30).map { year in
            let yearDouble = Double(year)
            return YearlyProjection(
                year: year,
                medianBalance: 1_000_000 * pow(1.05, yearDouble) - yearDouble * 40_000,
                percentile10Balance: 1_000_000 * pow(1.02, yearDouble) - yearDouble * 40_000,
                percentile90Balance: 1_000_000 * pow(1.08, yearDouble) - yearDouble * 40_000,
                medianWithdrawal: 40_000 * pow(1.02, yearDouble)
            )
        }
        
        // Pre-compute distribution
        let distribution: [Double] = (0..<100).map { _ in Double.random(in: 0...3_000_000) }
        
        return SimulationResult(
            parameters: .moderate,
            successRate: 0.89,
            medianFinalBalance: 1_250_000,
            meanFinalBalance: 1_450_000,
            percentile10: 450_000,
            percentile25: 750_000,
            percentile50: 1_250_000,
            percentile75: 1_800_000,
            percentile90: 2_500_000,
            yearlyBalances: yearlyBalances,
            finalBalanceDistribution: distribution,
            totalWithdrawn: 1_200_000,
            averageAnnualWithdrawal: 40_000,
            probabilityOfRuin: 0.11,
            yearsUntilRuin: 28.5,
            maxDrawdown: 0.35
        )
    }()
}
