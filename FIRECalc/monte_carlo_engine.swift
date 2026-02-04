//  monte_carlo_engine.swift
//  FIRECalc
//
//  FIXED - Proper withdrawal calculations and realistic failure detection
//

import Foundation

enum SuccessCriterion {
    case strict   // balance must be > 0 at end of horizon
    case lenient  // meeting withdrawals through last year counts as success
}

struct EngineOptions {
    var reinvestSurplusIncome: Bool = false
    var reportRealDollars: Bool = false // if true, store balances/withdrawals also deflated by inflation
    var successCriterion: SuccessCriterion = .strict
}

actor MonteCarloEngine {
    var options = EngineOptions()
    
    // Seeded/System RNG factory
    private func makeRNG(seed: UInt64?) -> AnyRandomNumberGenerator {
        AnyRandomNumberGenerator(seed: seed)
    }
    
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
        
        // Run all simulations concurrently
        let allRuns: [SimulationRun] = await withTaskGroup(of: SimulationRun.self) { group in
            for runNumber in 0..<parameters.numberOfRuns {
                group.addTask { [portfolio, parameters, historicalData] in
                    await self.performSingleRun(
                        portfolio: portfolio,
                        parameters: parameters,
                        historicalData: historicalData,
                        runNumber: runNumber
                    )
                }
            }
            var results: [SimulationRun] = []
            var completed = 0
            for await run in group {
                results.append(run)
                completed += 1
                if completed % 1000 == 0 {
                    print("Completed \(completed)/\(parameters.numberOfRuns) runs")
                }
            }
            return results
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
        var yearlyRealBalances: [Double]? = options.reportRealDollars ? [balance] : nil
        
        var yearlyWithdrawals: [Double] = []
        var yearlyRealWithdrawals: [Double]? = options.reportRealDollars ? [] : nil
        
        let totalYears = parameters.yearsUntilRetirement + parameters.timeHorizonYears
        let withdrawalCalc = WithdrawalCalculator()
        
        // Determine bootstrap start index for block bootstrap, if enabled
        let blockLength = parameters.bootstrapBlockLength
        var bootstrapStartIndex: Int? = nil
        if parameters.useHistoricalBootstrap, let blockLen = blockLength, blockLen >= 2 {
            let stockReturns = historicalData.returns(for: .stocks)
            if !stockReturns.isEmpty {
                // Derive a deterministic seed per run if provided
                let seedBase: UInt64 = (parameters.rngSeed ?? 0) &+ UInt64(runNumber) &* 1_000_003
                var rng = makeRNG(seed: seedBase)
                let count = stockReturns.count
                let r = Double.random(in: 0..<Double(count), using: &rng)
                bootstrapStartIndex = Int(r)
            }
        }
        
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
                    year: year,
                    runNumber: runNumber,
                    bootstrapStartIndex: bootstrapStartIndex,
                    blockLength: blockLength
                )
                
                // Apply return
                balance *= (1 + nominalReturn)
                
                // Add contributions
                let annualContribution = parameters.monthlyContribution * 12
                balance += annualContribution
                
                yearlyWithdrawals.append(0)
                yearlyBalances.append(balance)
                if options.reportRealDollars {
                    let deflator = pow(1 + parameters.inflationRate, Double(year))
                    yearlyRealBalances?.append(balance / deflator)
                    yearlyRealWithdrawals?.append(0)
                }
                
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
                
                let rawNetWithdrawal = withdrawal - totalIncome
                let netWithdrawal: Double
                if options.reinvestSurplusIncome {
                    // allow negative withdrawal to be added back to balance later
                    netWithdrawal = rawNetWithdrawal
                } else {
                    netWithdrawal = max(0, rawNetWithdrawal)
                }
                
                // Check if cash needed exceeds balance
                if netWithdrawal > balance {
                    balance = 0
                    yearlyWithdrawals.append(balance)
                    yearlyBalances.append(0)
                    if options.reportRealDollars {
                        let deflator = pow(1 + parameters.inflationRate, Double(year))
                        yearlyRealBalances?.append(0)
                        yearlyRealWithdrawals?.append(0)
                    }
                    yearsLasted = yearsIntoRetirement - 1
                    failed = true
                    // Fill remaining years with zeros
                    if year < totalYears {
                        for _ in year..<totalYears {
                            yearlyWithdrawals.append(0)
                            yearlyBalances.append(0)
                            if options.reportRealDollars {
                                yearlyRealWithdrawals?.append(0)
                                yearlyRealBalances?.append(0)
                            }
                        }
                    }
                    break
                }
                
                if netWithdrawal >= 0 {
                    balance -= netWithdrawal
                } else {
                    // Surplus income reinvested
                    balance += abs(netWithdrawal)
                }
                yearlyWithdrawals.append(max(0, netWithdrawal))
                if options.reportRealDollars {
                    let deflator = pow(1 + parameters.inflationRate, Double(year))
                    yearlyRealWithdrawals?.append(max(0, netWithdrawal) / deflator)
                }
                
                // Generate return
                let nominalReturn = generateReturn(
                    portfolio: portfolio,
                    parameters: parameters,
                    historicalData: historicalData,
                    year: year,
                    runNumber: runNumber,
                    bootstrapStartIndex: bootstrapStartIndex,
                    blockLength: blockLength
                )
                
                // Apply investment return on REMAINING balance
                balance *= (1 + nominalReturn)
                
                if balance <= 0 {
                    balance = 0
                    yearlyBalances.append(0)
                    if options.reportRealDollars {
                        yearlyRealBalances?.append(0)
                    }
                    yearsLasted = yearsIntoRetirement
                    failed = true
                    if year < totalYears {
                        for _ in (year + 1)...totalYears {
                            yearlyWithdrawals.append(0)
                            yearlyBalances.append(0)
                            if options.reportRealDollars {
                                yearlyRealWithdrawals?.append(0)
                                yearlyRealBalances?.append(0)
                            }
                        }
                    }
                    break
                }
                
                yearlyBalances.append(balance)
                if options.reportRealDollars {
                    let deflator = pow(1 + parameters.inflationRate, Double(year))
                    yearlyRealBalances?.append(balance / deflator)
                }
                yearsLasted = yearsIntoRetirement
            }
        }
        
        // If we made it through all years without failing
        if !failed {
            yearsLasted = parameters.timeHorizonYears
        }
        
        let success: Bool
        switch options.successCriterion {
        case .strict:
            success = yearsLasted >= parameters.timeHorizonYears && balance > 0
        case .lenient:
            success = yearsLasted >= parameters.timeHorizonYears
        }
        
        assert(yearlyBalances.count == totalYears + 1, "yearlyBalances length mismatch: \(yearlyBalances.count) vs \(totalYears + 1)")
        assert(yearlyWithdrawals.count == totalYears, "yearlyWithdrawals length mismatch: \(yearlyWithdrawals.count) vs \(totalYears)")
        
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
        year: Int,
        runNumber: Int,
        bootstrapStartIndex: Int?,
        blockLength: Int?
    ) -> Double {
        
        if parameters.useHistoricalBootstrap {
            // TODO: Pass parameters (e.g., rngSeed, block length) into bootstrap function to enable seeded/block sampling
            return generateHistoricalBootstrapReturn(
                portfolio: portfolio,
                historicalData: historicalData,
                year: year,
                bootstrapStartIndex: bootstrapStartIndex,
                blockLength: blockLength
            )
        } else {
            return generateNormalReturn(
                portfolio: portfolio,
                parameters: parameters,
                year: year,
                runNumber: runNumber
            )
        }
    }
    
    private func generateHistoricalBootstrapReturn(
        portfolio: Portfolio,
        historicalData: HistoricalData,
        year: Int,
        bootstrapStartIndex: Int?,
        blockLength: Int?
    ) -> Double {
        let stockReturns = historicalData.returns(for: .stocks)
        guard !stockReturns.isEmpty else { return 0 }
        let totalValue = portfolio.totalValue
        guard totalValue > 0 else { return 0 }
        let count = stockReturns.count
        
        // If blockLength provided, advance index sequentially from start; otherwise pick a random index per year
        let index: Int
        if let start = bootstrapStartIndex, let blockLen = blockLength, blockLen >= 2 {
            // Advance by (year-1) within the sequence
            index = (start + (year - 1)) % count
        } else {
            // Independent yearly sampling
            index = Int.random(in: 0..<count)
        }
        
        var portfolioReturn: Double = 0
        for asset in portfolio.assets {
            let weight = asset.totalValue / totalValue
            let assetReturns = historicalData.returns(for: asset.assetClass)
            let assetReturn: Double
            if index < assetReturns.count {
                assetReturn = assetReturns[index]
            } else {
                assetReturn = historicalData.summary(for: asset.assetClass)?.mean ?? asset.assetClass.defaultReturn
            }
            portfolioReturn += weight * assetReturn
        }
        return portfolioReturn
    }
    
    private func generateNormalReturn(
        portfolio: Portfolio,
        parameters: SimulationParameters,
        year: Int,
        runNumber: Int
    ) -> Double {
        // Prefer custom returns/volatility when provided
        let expectedReturn: Double
        let volatility: Double
        if let customR = parameters.customReturns, let customV = parameters.customVolatility, !customR.isEmpty, !customV.isEmpty {
            let total = portfolio.totalValue
            if total > 0 {
                var er: Double = 0
                var varProxy: Double = 0
                for asset in portfolio.assets {
                    let w = asset.totalValue / total
                    let r = customR[asset.assetClass] ?? asset.expectedReturn
                    let v = customV[asset.assetClass] ?? asset.volatility
                    er += w * r
                    varProxy += pow(w * v, 2)
                }
                expectedReturn = er
                volatility = sqrt(varProxy)
            } else {
                expectedReturn = customR.values.reduce(0, +) / Double(customR.count)
                volatility = sqrt(customV.values.map { pow($0, 2) }.reduce(0, +) / Double(customV.count))
            }
        } else {
            expectedReturn = portfolio.weightedExpectedReturn
            volatility = portfolio.weightedVolatility
        }
        
        // Derive a deterministic seed per (run, year) if provided
        let baseSeed: UInt64 = parameters.rngSeed ?? 0
        var rng = makeRNG(seed: baseSeed &+ UInt64(runNumber) &* 1_000_003 &+ UInt64(year))
        let marketShock = normalRandom(using: &rng)
        let specificShock = normalRandom(using: &rng)
        
        let correlationWeight = 0.6
        let combinedShock = (correlationWeight * marketShock + (1 - correlationWeight) * specificShock)
        
        return expectedReturn + combinedShock * volatility
    }
    
    private func normalRandom<R: RandomNumberGenerator>(using rng: inout R) -> Double {
        let u1 = Double.random(in: 0.0001...0.9999, using: &rng)
        let u2 = Double.random(in: 0.0001...0.9999, using: &rng)
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
        
        // Real-dollar projections (deflated by cumulative inflation)
        let inflation = parameters.inflationRate
        let totalYears = parameters.yearsUntilRetirement + parameters.timeHorizonYears
        let deflators: [Double] = (0...totalYears).map { year in pow(1 + inflation, Double(year)) }
        let realYearlyProjections: [YearlyProjection] = yearlyProjections.enumerated().map { (idx, proj) in
            let d = deflators[idx]
            return YearlyProjection(
                year: proj.year,
                medianBalance: proj.medianBalance / d,
                percentile10Balance: proj.percentile10Balance / d,
                percentile90Balance: proj.percentile90Balance / d,
                medianWithdrawal: proj.medianWithdrawal / (idx > 0 ? deflators[idx] : 1)
            )
        }
        
        // Real-dollar final balance distribution
        let finalRealBalances = finalBalances.map { $0 / pow(1 + inflation, Double(parameters.timeHorizonYears)) }
        
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
            yearlyRealBalances: realYearlyProjections,
            finalBalanceDistribution: finalBalances,
            finalRealBalanceDistribution: finalRealBalances,
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
        if sortedData.count == 1 { return sortedData[0] }
        let clampedP = min(max(p, 0), 1)
        let x = Double(sortedData.count - 1) * clampedP
        let i = Int(floor(x))
        let j = min(i + 1, sortedData.count - 1)
        let frac = x - Double(i)
        return sortedData[i] * (1 - frac) + sortedData[j] * frac
    }
}

// MARK: - RNG Implementations

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed != 0 ? seed : 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        // xorshift64*
        var x = state
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        state = x
        return x &* 2685821657736338717
    }
}

struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var seeded: SeededGenerator?
    private var system = SystemRandomNumberGenerator()
    init(seed: UInt64?) {
        if let s = seed { self.seeded = SeededGenerator(seed: s) } else { self.seeded = nil }
    }
    mutating func next() -> UInt64 {
        if var s = seeded {
            let value = s.next()
            seeded = s
            return value
        } else {
            return system.next()
        }
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

