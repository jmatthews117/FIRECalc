//  monte_carlo_engine.swift
//  FIRECalc
//
//  FIXED - Proper withdrawal calculations and realistic failure detection
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
        var yearsLasted = 0
        var failed = false
        
        for year in 1...totalYears {
            let isAccumulation = year <= parameters.yearsUntilRetirement
            
            if isAccumulation {
                // ACCUMULATION PHASE
                let nominalReturn = generateReturn(
                    portfolio: portfolio,
                    parameters: parameters,
                    historicalData: historicalData,
                    year: year
                )
                
                // Apply return
                balance *= (1 + nominalReturn)
                
                // Add contributions
                let annualContribution = parameters.monthlyContribution * 12
                balance += annualContribution
                
                yearlyWithdrawals.append(0)
                yearlyBalances.append(balance)
                
            } else {
                // RETIREMENT/WITHDRAWAL PHASE
                let yearsIntoRetirement = year - parameters.yearsUntilRetirement
                
                // Calculate withdrawal BEFORE applying returns
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
                
                // Add any defined benefit income
                let totalIncome = (parameters.socialSecurityIncome ?? 0) +
                                 (parameters.pensionIncome ?? 0) +
                                 (parameters.otherIncome ?? 0)
                
                let netWithdrawal = max(0, withdrawal - totalIncome)
                
                // CRITICAL FIX: Check if withdrawal exceeds balance
                if netWithdrawal > balance {
                    // Portfolio depleted - record failure
                    balance = 0
                    yearlyWithdrawals.append(balance)  // Can only withdraw what's left
                    yearlyBalances.append(0)
                    yearsLasted = yearsIntoRetirement - 1
                    failed = true
                    
                    // Fill remaining years with zeros
                    for _ in year..<totalYears {
                        yearlyWithdrawals.append(0)
                        yearlyBalances.append(0)
                    }
                    break
                }
                
                // Withdraw money
                balance -= netWithdrawal
                yearlyWithdrawals.append(netWithdrawal)
                
                // Generate return
                let nominalReturn = generateReturn(
                    portfolio: portfolio,
                    parameters: parameters,
                    historicalData: historicalData,
                    year: year
                )
                
                // Apply investment return on REMAINING balance
                balance *= (1 + nominalReturn)
                
                // Check for depletion after returns
                if balance <= 0 {
                    balance = 0
                    yearlyBalances.append(0)
                    yearsLasted = yearsIntoRetirement
                    failed = true
                    
                    // Fill remaining years with zeros
                    for _ in (year + 1)...totalYears {
                        yearlyWithdrawals.append(0)
                        yearlyBalances.append(0)
                    }
                    break
                }
                
                yearlyBalances.append(balance)
                yearsLasted = yearsIntoRetirement
            }
        }
        
        // If we made it through all years without failing
        if !failed {
            yearsLasted = parameters.timeHorizonYears
        }
        
        let success = yearsLasted >= parameters.timeHorizonYears && balance > 0
        
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
        
        let stockReturns = historicalData.returns(for: .stocks)
        guard !stockReturns.isEmpty else { return 0 }
        
        // Pick a random historical year
        let randomYearIndex = Int.random(in: 0..<stockReturns.count)
        
        var portfolioReturn: Double = 0
        let totalValue = portfolio.totalValue
        
        guard totalValue > 0 else { return 0 }
        
        for asset in portfolio.assets {
            let weight = asset.totalValue / totalValue
            
            let assetReturns = historicalData.returns(for: asset.assetClass)
            
            let assetReturn: Double
            if randomYearIndex < assetReturns.count {
                assetReturn = assetReturns[randomYearIndex]
            } else {
                assetReturn = historicalData.summary(for: asset.assetClass)?.mean ?? asset.assetClass.defaultReturn
            }
            
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
        
        let marketShock = generateNormalRandom()
        let specificShock = generateNormalRandom()
        
        let correlationWeight = 0.6
        let combinedShock = (correlationWeight * marketShock + (1 - correlationWeight) * specificShock)
        
        return expectedReturn + combinedShock * volatility
    }
    
    private func generateNormalRandom() -> Double {
        let u1 = Double.random(in: 0.0001...0.9999)
        let u2 = Double.random(in: 0.0001...0.9999)
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
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
            allSimulationRuns: runs,
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
                
                let drawdown = peak > 0 ? (peak - balance) / peak : 0
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
