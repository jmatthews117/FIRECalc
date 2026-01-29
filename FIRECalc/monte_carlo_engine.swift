//
//  monte_carlo_engine.swift
//  FIRECalc
//
//  MODIFIED - Now passes allSimulationRuns to SimulationResult
//

import Foundation

actor MonteCarloEngine {
    
    // MARK: - Main Simulation Method
    
    func runSimulation(
        portfolio: Portfolio,
        parameters: SimulationParameters,
        historicalData: HistoricalData
    ) async throws -> SimulationResult {
        
        guard parameters.isValid else {
            throw SimulationError.invalidParameters(parameters.validationErrors)
        }
        
        guard !portfolio.assets.isEmpty else {
            throw SimulationError.emptyPortfolio
        }
        
        print("Starting Monte Carlo simulation with \(parameters.numberOfRuns) runs...")
        
        var allRuns: [SimulationRun] = []
        
        // Run all simulations
        for runNumber in 0..<parameters.numberOfRuns {
            let run = await performSingleRun(
                portfolio: portfolio,
                parameters: parameters,
                historicalData: historicalData,
                runNumber: runNumber
            )
            allRuns.append(run)
            
            // Progress reporting (every 1000 runs)
            if (runNumber + 1) % 1000 == 0 {
                print("Completed \(runNumber + 1)/\(parameters.numberOfRuns) runs")
            }
        }
        
        // Analyze results
        let result = analyzeResults(runs: allRuns, parameters: parameters)
        
        print("Simulation complete. Success rate: \(String(format: "%.1f%%", result.successRate * 100))")
        
        return result
    }
    
    // MARK: - Single Run Simulation
    
    private func performSingleRun(
        portfolio: Portfolio,
        parameters: SimulationParameters,
        historicalData: HistoricalData,
        runNumber: Int
    ) async -> SimulationRun {
        
        var balance = parameters.initialPortfolioValue
        var yearlyBalances: [Double] = [balance]
        var yearlyWithdrawals: [Double] = []
        
        let totalYears = parameters.yearsUntilRetirement + parameters.timeHorizonYears
        let withdrawalCalc = WithdrawalCalculator()
        
        var baselineWithdrawal: Double = 0
        
        for year in 1...totalYears {
            let isAccumulation = year <= parameters.yearsUntilRetirement
            
            // Generate annual return
            let annualReturn = generateReturn(
                portfolio: portfolio,
                parameters: parameters,
                historicalData: historicalData,
                year: year
            )
            
            // Apply return to balance
            balance *= (1 + annualReturn)
            
            if isAccumulation {
                let annualContribution = parameters.monthlyContribution * 12
                balance += annualContribution
                yearlyWithdrawals.append(0)
            } else {
                let yearsIntoRetirement = year - parameters.yearsUntilRetirement
                
                let withdrawal = withdrawalCalc.calculateWithdrawal(
                    currentBalance: balance,
                    year: yearsIntoRetirement,
                    baselineWithdrawal: baselineWithdrawal,
                    initialBalance: parameters.initialPortfolioValue,
                    config: parameters.withdrawalConfig,
                    inflationRate: parameters.inflationRate
                )
                
                if yearsIntoRetirement == 1 {
                    baselineWithdrawal = withdrawal
                }
                
                let totalIncome = (parameters.socialSecurityIncome ?? 0) +
                                 (parameters.pensionIncome ?? 0) +
                                 (parameters.otherIncome ?? 0)
                
                let netWithdrawal = max(0, withdrawal - totalIncome)
                
                balance -= netWithdrawal
                yearlyWithdrawals.append(netWithdrawal)
                
                if balance <= 0 {
                    balance = 0
                }
            }
            
            yearlyBalances.append(balance)
        }
        
        let retirementYears = parameters.timeHorizonYears
        let yearsLasted = yearlyBalances.dropFirst(parameters.yearsUntilRetirement + 1)
            .prefix(retirementYears)
            .firstIndex { $0 <= 0 } ?? retirementYears
        
        let success = yearsLasted >= retirementYears
        
        return SimulationRun(
            runNumber: runNumber,
            yearlyBalances: yearlyBalances,
            yearlyWithdrawals: yearlyWithdrawals,
            finalBalance: balance,
            success: success,
            yearsLasted: yearsLasted
        )
    }
    
    // MARK: - Return Generation
    
    private func generateReturn(
        portfolio: Portfolio,
        parameters: SimulationParameters,
        historicalData: HistoricalData,
        year: Int
    ) -> Double {
        
        if parameters.useHistoricalBootstrap {
            return generateHistoricalBootstrapReturn(portfolio: portfolio, historicalData: historicalData)
        } else {
            return generateNormalReturn(portfolio: portfolio, parameters: parameters)
        }
    }
    
    private func generateHistoricalBootstrapReturn(
        portfolio: Portfolio,
        historicalData: HistoricalData
    ) -> Double {
        
        var portfolioReturn: Double = 0
        let totalValue = portfolio.totalValue
        
        guard totalValue > 0 else { return 0 }
        
        for asset in portfolio.assets {
            let weight = asset.totalValue / totalValue
            let assetReturn = historicalData.randomReturn(for: asset.assetClass)
            portfolioReturn += weight * assetReturn
        }
        
        return portfolioReturn
    }
    
    private func generateNormalReturn(
        portfolio: Portfolio,
        parameters: SimulationParameters
    ) -> Double {
        
        let expectedReturn = portfolio.weightedExpectedReturn
        let volatility = portfolio.weightedVolatility
        
        // Box-Muller transform for normal distribution
        let u1 = Double.random(in: 0...1)
        let u2 = Double.random(in: 0...1)
        let z = sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
        
        return expectedReturn + z * volatility
    }
    
    // MARK: - Results Analysis
    
    private func analyzeResults(
        runs: [SimulationRun],
        parameters: SimulationParameters
    ) -> SimulationResult {
        
        let finalBalances = runs.map { $0.finalBalance }.sorted()
        let successfulRuns = runs.filter { $0.success }
        
        let successRate = Double(successfulRuns.count) / Double(runs.count)
        
        // Calculate percentiles
        let p10 = percentile(finalBalances, 0.10)
        let p25 = percentile(finalBalances, 0.25)
        let p50 = percentile(finalBalances, 0.50)
        let p75 = percentile(finalBalances, 0.75)
        let p90 = percentile(finalBalances, 0.90)
        
        let meanFinal = finalBalances.reduce(0, +) / Double(finalBalances.count)
        
        // Build yearly projections
        let yearlyProjections = buildYearlyProjections(runs: runs, parameters: parameters)
        
        // Calculate withdrawal statistics
        let totalWithdrawals = runs.map { run in
            run.yearlyWithdrawals.reduce(0, +)
        }
        let medianTotalWithdrawn = percentile(totalWithdrawals.sorted(), 0.50)
        let avgAnnualWithdrawal = medianTotalWithdrawn / Double(parameters.timeHorizonYears)
        
        // Risk metrics
        let failedRuns = runs.filter { !$0.success }
        let probabilityOfRuin = Double(failedRuns.count) / Double(runs.count)
        
        let yearsUntilRuin: Double? = failedRuns.isEmpty ? nil :
            Double(failedRuns.map { $0.yearsLasted }.reduce(0, +)) / Double(failedRuns.count)
        
        let maxDrawdown = calculateMaxDrawdown(runs: runs)
        
        return SimulationResult(
            parameters: parameters,
            successRate: successRate,
            medianFinalBalance: p50,
            meanFinalBalance: meanFinal,
            percentile10: p10,
            percentile25: p25,
            percentile50: p50,
            percentile75: p75,
            percentile90: p90,
            yearlyBalances: yearlyProjections,
            finalBalanceDistribution: finalBalances,
            allSimulationRuns: runs,  // MODIFIED: Pass all runs for spaghetti chart
            totalWithdrawn: medianTotalWithdrawn,
            averageAnnualWithdrawal: avgAnnualWithdrawal,
            probabilityOfRuin: probabilityOfRuin,
            yearsUntilRuin: yearsUntilRuin,
            maxDrawdown: maxDrawdown
        )
    }
    
    private func buildYearlyProjections(
        runs: [SimulationRun],
        parameters: SimulationParameters
    ) -> [YearlyProjection] {
        
        let totalYears = parameters.yearsUntilRetirement + parameters.timeHorizonYears
        var projections: [YearlyProjection] = []
        
        for year in 0...totalYears {
            let balancesThisYear = runs.map { $0.yearlyBalances[year] }.sorted()
            let withdrawalsThisYear = year > 0 ? runs.map { $0.yearlyWithdrawals[year - 1] }.sorted() : []
            
            let projection = YearlyProjection(
                year: year,
                medianBalance: percentile(balancesThisYear, 0.50),
                percentile10Balance: percentile(balancesThisYear, 0.10),
                percentile90Balance: percentile(balancesThisYear, 0.90),
                medianWithdrawal: withdrawalsThisYear.isEmpty ? 0 : percentile(withdrawalsThisYear, 0.50)
            )
            
            projections.append(projection)
        }
        
        return projections
    }
    
    private func calculateMaxDrawdown(runs: [SimulationRun]) -> Double {
        var maxDrawdown: Double = 0
        
        for run in runs {
            var peak: Double = run.yearlyBalances[0]
            
            for balance in run.yearlyBalances {
                if balance > peak {
                    peak = balance
                }
                
                let drawdown = (peak - balance) / peak
                maxDrawdown = max(maxDrawdown, drawdown)
            }
        }
        
        return maxDrawdown
    }
    
    // MARK: - Utility Functions
    
    private func percentile(_ sortedData: [Double], _ p: Double) -> Double {
        guard !sortedData.isEmpty else { return 0 }
        
        let index = Int(Double(sortedData.count - 1) * p)
        return sortedData[index]
    }
}

// MARK: - Errors

enum SimulationError: LocalizedError {
    case invalidParameters([String])
    case emptyPortfolio
    case missingHistoricalData
    
    var errorDescription: String? {
        switch self {
        case .invalidParameters(let errors):
            return "Invalid parameters: \(errors.joined(separator: ", "))"
        case .emptyPortfolio:
            return "Portfolio cannot be empty"
        case .missingHistoricalData:
            return "Historical data not available"
        }
    }
}
