//
//  monte_carlo_engine.swift
//  FIRECalc
//
//  CORRECTED v2 - Fixed order of operations in retirement phase
//  Works consistently in REAL (inflation-adjusted) terms
//

import Foundation

actor MonteCarloEngine {
    
    // Simulation options
    private struct SimulationOptions {
        let reportRealDollars: Bool = true
        let successCriterion: SuccessCriterion = .strict
        
        enum SuccessCriterion {
            case strict   // Must have money left at end
            case lenient  // Just need to last the full duration
        }
    }
    
    private static let options = SimulationOptions()
    
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
        print("Working in REAL terms (all returns inflation-adjusted)")

        // Split work into batches — one per logical CPU core — so task-creation
        // overhead stays low while all cores stay saturated.
        let coreCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
        let totalRuns = parameters.numberOfRuns
        let batchSize = max(1, (totalRuns + coreCount - 1) / coreCount)

        let allRuns: [SimulationRun] = try await withThrowingTaskGroup(
            of: [SimulationRun].self
        ) { group in

            var start = 0
            while start < totalRuns {
                let batchStart = start
                let batchEnd   = min(start + batchSize, totalRuns)
                group.addTask {
                    // Each task is nonisolated — pure value-type computation,
                    // no shared mutable state.
                    var batchRuns: [SimulationRun] = []
                    batchRuns.reserveCapacity(batchEnd - batchStart)
                    for runNumber in batchStart..<batchEnd {
                        let run = MonteCarloEngine.performSingleRun(
                            portfolio: portfolio,
                            parameters: parameters,
                            historicalData: historicalData,
                            runNumber: runNumber
                        )
                        batchRuns.append(run)
                    }
                    return batchRuns
                }
                start = batchEnd
            }

            var collected: [SimulationRun] = []
            collected.reserveCapacity(totalRuns)
            for try await batch in group {
                collected.append(contentsOf: batch)
            }
            return collected
        }
        
        // Analyze results
        let result = MonteCarloEngine.analyzeResults(runs: allRuns, parameters: parameters)
        
        print("Simulation complete. Success rate: \(String(format: "%.1f%%", result.successRate * 100))")
        
        return result
    }
    
    // MARK: - Single Run Simulation

    private static func performSingleRun(
        portfolio: Portfolio,
        parameters: SimulationParameters,
        historicalData: HistoricalData,
        runNumber: Int
    ) -> SimulationRun {
        
        // All balances are in REAL (today's) dollars
        var balance = parameters.effectiveInitialValue
        var yearlyBalances: [Double] = [balance]
        var yearlyWithdrawals: [Double] = []
        
        let totalYears = parameters.timeHorizonYears
        let withdrawalCalc = WithdrawalCalculator()
        
        // Determine bootstrap start index for block bootstrap, if enabled
        let blockLength = parameters.bootstrapBlockLength
        var bootstrapStartIndex: Int? = nil
        if parameters.useHistoricalBootstrap, let blockLen = blockLength, blockLen >= 2 {
            let stockReturns = historicalData.returns(for: .stocks)
            if !stockReturns.isEmpty {
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
            // ============================================
            // WITHDRAWAL PHASE
            // ============================================

            // STEP 1: Apply returns FIRST (to full beginning-of-year balance)
            let realReturn = generateRealReturn(
                portfolio: portfolio,
                parameters: parameters,
                historicalData: historicalData,
                year: year,
                runNumber: runNumber,
                bootstrapStartIndex: bootstrapStartIndex,
                blockLength: blockLength
            )

            balance *= (1 + realReturn)

            // STEP 2: Calculate withdrawal (from grown balance)
            // Withdrawal is in REAL dollars (today's purchasing power)
            let withdrawal = withdrawalCalc.calculateWithdrawal(
                currentBalance: balance,
                year: year,
                baselineWithdrawal: baselineWithdrawal,
                initialBalance: parameters.initialPortfolioValue,
                config: parameters.withdrawalConfig
            )

            // Always track the actual withdrawal taken so strategies like
            // Guardrails correctly compound their year-over-year adjustments.
            if year == 1 || parameters.withdrawalConfig.strategy != .fixedPercentage {
                baselineWithdrawal = withdrawal
            }

            // Fixed income (pensions, Social Security) is already offset
            // inside WithdrawalCalculator via config.fixedIncome — no
            // second subtraction needed here.

            // STEP 3: Subtract withdrawal from balance
            balance -= withdrawal

            yearlyWithdrawals.append(max(0, withdrawal))

            // Check for failure
            if balance <= 0 {
                balance = 0
                yearlyBalances.append(0)
                yearsLasted = year
                failed = true

                // Fill remaining years with zeros
                if year < totalYears {
                    for _ in (year + 1)...totalYears {
                        yearlyWithdrawals.append(0)
                        yearlyBalances.append(0)
                    }
                }
                break
            }

            yearlyBalances.append(balance)
            yearsLasted = year
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
        
        assert(yearlyBalances.count == totalYears + 1,
               "yearlyBalances length mismatch: \(yearlyBalances.count) vs \(totalYears + 1)")
        assert(yearlyWithdrawals.count == totalYears,
               "yearlyWithdrawals length mismatch: \(yearlyWithdrawals.count) vs \(totalYears)")
        
        return SimulationRun(
            runNumber: runNumber,
            yearlyBalances: yearlyBalances,
            yearlyWithdrawals: yearlyWithdrawals,
            finalBalance: balance,
            success: success,
            yearsLasted: yearsLasted
        )
    }
    
    // MARK: - Return Generation (REAL TERMS)
    
    /// Generate a real (inflation-adjusted) return
    private static func generateRealReturn(
        portfolio: Portfolio,
        parameters: SimulationParameters,
        historicalData: HistoricalData,
        year: Int,
        runNumber: Int,
        bootstrapStartIndex: Int?,
        blockLength: Int?
    ) -> Double {
        
        if parameters.useHistoricalBootstrap {
            return generateHistoricalBootstrapRealReturn(
                portfolio: portfolio,
                historicalData: historicalData,
                year: year,
                bootstrapStartIndex: bootstrapStartIndex,
                blockLength: blockLength
            )
        } else {
            return generateNormalRealReturn(
                portfolio: portfolio,
                parameters: parameters,
                year: year,
                runNumber: runNumber
            )
        }
    }
    
    /// Generate real return from historical data (nominal - inflation)
    private static func generateHistoricalBootstrapRealReturn(
        portfolio: Portfolio,
        historicalData: HistoricalData,
        year: Int,
        bootstrapStartIndex: Int?,
        blockLength: Int?
    ) -> Double {
        
        let totalValue = portfolio.totalValue
        guard totalValue > 0 else { return 0 }
        
        // Get historical inflation data
        let historicalInflation = getHistoricalInflation()
        
        // Sample a year index
        let yearIndex: Int
        if let startIdx = bootstrapStartIndex, let blockLen = blockLength, blockLen >= 2 {
            // Block bootstrap
            let offset = (year - 1) % blockLen
            yearIndex = (startIdx + offset) % historicalInflation.count
        } else {
            // Simple random sampling
            yearIndex = Int.random(in: 0..<historicalInflation.count)
        }
        
        // Calculate nominal portfolio return for that year using the portfolio's
        // actual holdings. Custom allocation weights are applied upstream by
        // Portfolio.applyingAllocationWeights(_:) before the engine is called,
        // so the portfolio here already reflects the desired weights.
        var nominalPortfolioReturn: Double = 0

        for asset in portfolio.assets {
            let weight = asset.totalValue / totalValue
            let assetReturns = historicalData.returns(for: asset.assetClass)

            let assetReturn: Double
            if yearIndex < assetReturns.count {
                assetReturn = assetReturns[yearIndex]
            } else {
                // Fallback if index out of range
                assetReturn = assetReturns.randomElement() ?? asset.assetClass.defaultReturn
            }

            nominalPortfolioReturn += weight * assetReturn
        }
        
        // Get inflation for the same year to maintain correlation
        let inflation = yearIndex < historicalInflation.count ?
            historicalInflation[yearIndex] : 0.025
        
        // Convert to real return using Fisher equation
        let realReturn = ((1 + nominalPortfolioReturn) / (1 + inflation)) - 1
        
        return realReturn
    }
    
    /// Generate a log-normal, fat-tailed, cross-asset-correlated real return.
    ///
    /// Three improvements over a simple normal draw:
    ///
    /// 1. **Log-normal**: each asset return is drawn as `exp(μ_ln + σ_ln·Z) − 1`
    ///    so losses are naturally bounded at −100% and the arithmetic mean/variance
    ///    still match the user-supplied values.
    ///
    /// 2. **Fat tails**: the base random variates are drawn from a Student's
    ///    t-distribution (ν = 5) rather than a standard normal.  The draw is
    ///    scaled back to unit variance so σ retains its original meaning.
    ///    ν = 5 is a common empirical fit for annual equity-return kurtosis.
    ///
    /// 3. **Cross-asset correlation**: each asset class has a known empirical
    ///    correlation to the broad equity market.  One shared market shock drives
    ///    the correlated component; an independent idiosyncratic shock drives the
    ///    residual.  This replicates the effect of a one-factor correlation model
    ///    (e.g. Sharpe single-index) without requiring a full Cholesky decomposition.
    ///
    /// None of this code is reachable from the historical-bootstrap path.
    private static func generateNormalRealReturn(
        portfolio: Portfolio,
        parameters: SimulationParameters,
        year: Int,
        runNumber: Int
    ) -> Double {

        let totalValue = portfolio.totalValue
        guard totalValue > 0 else { return 0 }

        // One RNG per (run, year) — advanced sequentially for each draw so
        // every variate is independent while the sequence remains reproducible.
        let baseSeed: UInt64 = (parameters.rngSeed ?? 0)
            &+ UInt64(runNumber) &* 1_000_003
            &+ UInt64(year) &* 999_983
        var rng = makeRNG(seed: baseSeed)

        // ── Shared market shock (one per year/run, fat-tailed) ──────────────
        let marketZ = generateStudentT(seed: rng.next())

        var nominalReturn = 0.0

        if let customWeights = parameters.customAllocationWeights {
            // Custom allocation: build synthetic "assets" from the weight map
            for (assetClass, weight) in customWeights {
                guard weight > 0 else { continue }
                let mu  = parameters.customReturns?[assetClass]    ?? assetClass.defaultReturn
                let vol = parameters.customVolatility?[assetClass] ?? assetClass.defaultVolatility

                let idioZ = generateStudentT(seed: rng.next())
                let rho = marketCorrelation(for: assetClass)
                let combinedZ = rho * marketZ + sqrt(1 - rho * rho) * idioZ

                let sigmaLnSq = log(1 + pow(vol / (1 + mu), 2))
                let sigmaLn   = sqrt(sigmaLnSq)
                let muLn      = log(1 + mu) - sigmaLnSq / 2

                let assetReturn = exp(muLn + sigmaLn * combinedZ) - 1
                nominalReturn  += weight * assetReturn
            }
        } else {
            for asset in portfolio.assets {
                let weight = asset.totalValue / totalValue

                // Prefer user-supplied custom values; fall back to asset-class defaults.
                let mu  = parameters.customReturns?[asset.assetClass]    ?? asset.assetClass.defaultReturn
                let vol = parameters.customVolatility?[asset.assetClass] ?? asset.assetClass.defaultVolatility

                // ── Per-asset idiosyncratic shock ────────────────────────────────
                let idioZ = generateStudentT(seed: rng.next())

                // ── Correlation factor ───────────────────────────────────────────
                let rho = marketCorrelation(for: asset.assetClass)
                let combinedZ = rho * marketZ + sqrt(1 - rho * rho) * idioZ

                // ── Log-normal conversion ────────────────────────────────────────
                let sigmaLnSq = log(1 + pow(vol / (1 + mu), 2))
                let sigmaLn   = sqrt(sigmaLnSq)
                let muLn      = log(1 + mu) - sigmaLnSq / 2

                let assetReturn = exp(muLn + sigmaLn * combinedZ) - 1
                nominalReturn  += weight * assetReturn
            }
        }

        // Fisher equation — consistent with the bootstrap path.
        return ((1 + nominalReturn) / (1 + parameters.inflationRate)) - 1
    }

    // MARK: - Empirical market correlation by asset class

    /// Returns ρ, the approximate correlation of each asset class with the
    /// broad equity market (S&P 500), derived from long-run historical data.
    /// Used to build a one-factor correlated shock.
    private static func marketCorrelation(for assetClass: AssetClass) -> Double {
        switch assetClass {
        case .stocks:         return 1.00  // IS the market factor
        case .reits:          return 0.70  // High equity sensitivity
        case .corporateBonds: return 0.30  // Moderate credit/equity link
        case .bonds:          return -0.10 // Mild flight-to-quality offset
        case .realEstate:     return 0.50  // Moderate
        case .preciousMetals: return 0.05  // Near-zero equity correlation
        case .crypto:         return 0.40  // Positive but noisy
        case .cash:           return 0.00  // Uncorrelated by construction
        case .other:          return 0.50  // Conservative middle estimate
        }
    }

    // MARK: - Fat-tailed random variate (Student's t, ν = 5)

    /// Returns a draw from a Student's t-distribution with ν = 5 degrees of
    /// freedom, scaled to unit variance.  ν = 5 is a standard empirical fit
    /// for annual equity return kurtosis (excess kurtosis ≈ 6 vs. normal's 0).
    ///
    /// Method: t = Z / √(χ²/ν) where Z ~ N(0,1) and χ² ~ χ²(ν).
    /// χ²(5) is approximated as the sum of 5 independent N(0,1)² draws.
    /// The result is then divided by √(ν/(ν−2)) = √(5/3) to restore unit variance.
    private static func generateStudentT(seed: UInt64) -> Double {
        let nu: Double = 5

        // Use a single advancing RNG so every draw is independent.
        var rng = makeRNG(seed: seed)

        // Standard normal draw for the numerator
        let z = generateStandardNormal(using: &rng)

        // χ²(ν) as sum of ν squared independent normals
        var chiSq: Double = 0
        for _ in 0..<Int(nu) {
            let xi = generateStandardNormal(using: &rng)
            chiSq += xi * xi
        }

        let t = z / sqrt(chiSq / nu)

        // Scale to unit variance: Var(t_ν) = ν/(ν−2)
        let unitVarianceScale = sqrt((nu - 2) / nu)   // √(3/5)
        return t * unitVarianceScale
    }

    /// Box-Muller standard normal draw consuming two values from the provided RNG.
    private static func generateStandardNormal(using rng: inout LinearCongruentialGenerator) -> Double {
        let u1 = Double.random(in: 0.0001...0.9999, using: &rng)
        let u2 = Double.random(in: 0.0001...0.9999, using: &rng)
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }

    /// Create a seeded random number generator
    private static func makeRNG(seed: UInt64) -> LinearCongruentialGenerator {
        return LinearCongruentialGenerator(seed: seed)
    }
    
    /// Get historical inflation data
    private static func getHistoricalInflation() -> [Double] {
        // Historical CPI inflation (1928-2024)
        return [
            -0.0116, 0.0012, 0.0012, 0.0000, -0.0636, -0.0909, -0.1028, -0.0520,
            0.0152, 0.0305, 0.0145, 0.0299, 0.0290, 0.0096, 0.0000, 0.0000,
            0.0097, 0.0290, 0.0305, 0.0290, 0.0196, 0.0294, 0.0188, 0.0285,
            0.0809, 0.1434, 0.0880, 0.0299, 0.0237, 0.0076, 0.0188, 0.0179,
            0.0313, 0.0336, 0.0000, 0.0075, 0.0224, 0.0298, 0.0838, 0.0299,
            0.0596, 0.0894, 0.0299, 0.0299, 0.0199, 0.0299, 0.0617, 0.0299,
            0.0122, 0.0075, 0.0037, 0.0000, 0.0075, 0.0037, 0.0149, 0.0372,
            0.0299, 0.0186, 0.0149, 0.0111, 0.0074, 0.0111, 0.0147, 0.0294,
            0.0442, 0.0610, 0.0412, 0.0335, 0.0649, 0.1335, 0.0904, 0.0696,
            0.0486, 0.0390, 0.0385, 0.0338, 0.0325, 0.0413, 0.0361, 0.0132,
            0.0427, 0.0438, 0.0156, 0.0284, 0.0174, 0.0268, 0.0290, 0.0254,
            0.0168, 0.0233, 0.0188, 0.0340, 0.0277, 0.0161, 0.0227, 0.0284,
            0.0339, 0.0207, 0.0082
        ]
    }
    
    // MARK: - Results Analysis
    
    private static func analyzeResults(
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
            yearlyRealBalances: yearlyProjections, // Same since we work in real terms
            finalBalanceDistribution: finalBalances,
            finalRealBalanceDistribution: finalBalances, // Same since we work in real terms
            allSimulationRuns: runs,
            totalWithdrawn: medianTotalWithdrawn,
            averageAnnualWithdrawal: avgAnnualWithdrawal,
            probabilityOfRuin: probabilityOfRuin,
            yearsUntilRuin: yearsUntilRuin,
            maxDrawdown: maxDrawdown
        )
    }
    
    private static func buildYearlyProjections(
        runs: [SimulationRun],
        parameters: SimulationParameters
    ) -> [YearlyProjection] {
        
        let totalYears = parameters.timeHorizonYears
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
    
    private static func percentile(_ sortedArray: [Double], _ p: Double) -> Double {
        guard !sortedArray.isEmpty else { return 0 }
        
        let index = p * Double(sortedArray.count - 1)
        let lower = Int(floor(index))
        let upper = Int(ceil(index))
        
        if lower == upper {
            return sortedArray[lower]
        }
        
        let weight = index - Double(lower)
        return sortedArray[lower] * (1 - weight) + sortedArray[upper] * weight
    }
    
    private static func calculateMaxDrawdown(runs: [SimulationRun]) -> Double {
        var maxDrawdown: Double = 0
        
        for run in runs {
            var peak: Double = run.yearlyBalances[0]
            
            for balance in run.yearlyBalances {
                if balance > peak {
                    peak = balance
                }
                
                if peak > 0 {
                    let drawdown = (peak - balance) / peak
                    maxDrawdown = max(maxDrawdown, drawdown)
                }
            }
        }
        
        return maxDrawdown
    }
}

// MARK: - Linear Congruential Generator (for reproducible randomness)

struct LinearCongruentialGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Simulation Errors

enum SimulationError: Error, LocalizedError {
    case invalidParameters([String])
    case emptyPortfolio
    case dataLoadFailure
    
    var errorDescription: String? {
        switch self {
        case .invalidParameters(let errors):
            return "Invalid parameters: \(errors.joined(separator: ", "))"
        case .emptyPortfolio:
            return "Portfolio must contain at least one asset"
        case .dataLoadFailure:
            return "Failed to load historical data"
        }
    }
}

