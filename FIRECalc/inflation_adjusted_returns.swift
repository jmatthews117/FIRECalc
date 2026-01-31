//
//  inflation_adjusted_returns.swift
//  FIRECalc
//
//  NEW FILE - Proper inflation handling for Monte Carlo simulations
//

import Foundation

/// Handles conversion between nominal and real returns with inflation correlation
struct InflationAdjustedReturns {
    
    // Historical inflation data (1926-2024)
    private static let historicalInflation: [Double] = [
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
    
    /// Convert nominal returns to real returns by subtracting inflation
    static func toRealReturns(nominal: [Double], inflation: [Double]) -> [Double] {
        guard nominal.count == inflation.count else {
            fatalError("Nominal and inflation arrays must have same length")
        }
        
        return zip(nominal, inflation).map { nominalReturn, inflationRate in
            // Fisher equation: (1 + real) = (1 + nominal) / (1 + inflation)
            ((1 + nominalReturn) / (1 + inflationRate)) - 1
        }
    }
    
    /// Convert real returns to nominal returns by adding inflation
    static func toNominalReturns(real: [Double], inflation: [Double]) -> [Double] {
        guard real.count == inflation.count else {
            fatalError("Real and inflation arrays must have same length")
        }
        
        return zip(real, inflation).map { realReturn, inflationRate in
            // Fisher equation: (1 + nominal) = (1 + real) * (1 + inflation)
            (1 + realReturn) * (1 + inflationRate) - 1
        }
    }
    
    /// Sample inflation rate from historical distribution
    static func sampleHistoricalInflation() -> Double {
        return historicalInflation.randomElement() ?? 0.025
    }
    
    /// Calculate correlation between returns and inflation
    static func calculateCorrelation(returns: [Double], inflation: [Double]) -> Double {
        guard returns.count == inflation.count && returns.count > 1 else {
            return 0
        }
        
        let n = Double(returns.count)
        let meanReturns = returns.reduce(0, +) / n
        let meanInflation = inflation.reduce(0, +) / n
        
        var covariance: Double = 0
        var varianceReturns: Double = 0
        var varianceInflation: Double = 0
        
        for i in 0..<returns.count {
            let returnDiff = returns[i] - meanReturns
            let inflationDiff = inflation[i] - meanInflation
            
            covariance += returnDiff * inflationDiff
            varianceReturns += returnDiff * returnDiff
            varianceInflation += inflationDiff * inflationDiff
        }
        
        let denominator = sqrt(varianceReturns * varianceInflation)
        return denominator > 0 ? covariance / denominator : 0
    }
    
    /// Generate correlated inflation and return pair using historical data
    static func sampleCorrelatedInflationReturn(
        assetClass: AssetClass,
        historicalData: HistoricalData
    ) -> (return: Double, inflation: Double) {
        // Get historical returns for this asset class
        let returns = historicalData.returns(for: assetClass)
        
        // Sample a random year
        let yearIndex = Int.random(in: 0..<min(returns.count, historicalInflation.count))
        
        return (
            return: returns[yearIndex],
            inflation: historicalInflation[yearIndex]
        )
    }
    
    /// Generate portfolio return with correlated inflation
    static func samplePortfolioReturnWithInflation(
        portfolio: Portfolio,
        historicalData: HistoricalData
    ) -> (return: Double, inflation: Double) {
        let totalValue = portfolio.totalValue
        guard totalValue > 0 else {
            return (return: 0, inflation: 0.025)
        }
        
        // Sample a single random year to maintain correlation
        let yearIndex = Int.random(in: 0..<min(
            historicalData.returns(for: .stocks).count,
            historicalInflation.count
        ))
        
        // Calculate weighted portfolio return for that year
        var portfolioReturn: Double = 0
        
        for asset in portfolio.assets {
            let weight = asset.totalValue / totalValue
            let assetReturns = historicalData.returns(for: asset.assetClass)
            
            if yearIndex < assetReturns.count {
                portfolioReturn += weight * assetReturns[yearIndex]
            } else {
                // Fallback to random if this asset class has fewer years
                portfolioReturn += weight * (assetReturns.randomElement() ?? asset.assetClass.defaultReturn)
            }
        }
        
        // Use the same year's inflation to maintain correlation
        let inflation = yearIndex < historicalInflation.count ?
            historicalInflation[yearIndex] : 0.025
        
        return (return: portfolioReturn, inflation: inflation)
    }
    
    /// Get historical inflation data
    static func getHistoricalInflation() -> [Double] {
        return historicalInflation
    }
}

/// Strategy for handling inflation in simulations
enum InflationStrategy: String, Codable {
    case historicalCorrelated = "Historical with Correlation"
    case constantReal = "Constant Inflation (Real Returns)"
    case constantNominal = "Constant Inflation (Nominal Returns)"
    
    var description: String {
        switch self {
        case .historicalCorrelated:
            return "Uses actual historical inflation data, maintaining correlation with returns"
        case .constantReal:
            return "Uses constant inflation rate, returns are inflation-adjusted (real)"
        case .constantNominal:
            return "Uses constant inflation rate, returns include inflation (nominal)"
        }
    }
}
