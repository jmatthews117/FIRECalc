//
//  HistoricalDataService.swift
//  FIRECalc
//
//  Loads and provides historical return data for bootstrap simulations
//

import Foundation

// MARK: - Historical Data Model

struct HistoricalData: Codable {
    let metadata: HistoricalMetadata
    let assetClasses: [String: AssetClassData]
    let correlations: CorrelationData?
    
    func randomReturn(for assetClass: AssetClass) -> Double {
        guard let data = assetClasses[assetClass.rawValue.lowercased()],
              !data.historicalReturns.isEmpty else {
            // Fallback to asset class default if no historical data
            return assetClass.defaultReturn
        }
        
        return data.historicalReturns.randomElement() ?? assetClass.defaultReturn
    }
    
    func returns(for assetClass: AssetClass) -> [Double] {
        guard let data = assetClasses[assetClass.rawValue.lowercased()] else {
            return []
        }
        return data.historicalReturns
    }
    
    func summary(for assetClass: AssetClass) -> ReturnSummary? {
        guard let data = assetClasses[assetClass.rawValue.lowercased()] else {
            return nil
        }
        return data.summary
    }
}

struct HistoricalMetadata: Codable {
    let description: String
    let dataSource: String
    let startYear: Int
    let endYear: Int
    let notes: String?
}

struct AssetClassData: Codable {
    let name: String
    let historicalReturns: [Double]
    let summary: ReturnSummary
    let notes: String?
}

struct ReturnSummary: Codable {
    let mean: Double
    let median: Double
    let standardDeviation: Double
    let min: Double
    let max: Double
}

struct CorrelationData: Codable {
    let description: String
    let matrix: [String: Double]
}

// MARK: - Historical Data Service

class HistoricalDataService {
    static let shared = HistoricalDataService()
    
    private var cachedData: HistoricalData?
    
    private init() {}
    
    /// Load historical data from JSON file
    func loadHistoricalData() throws -> HistoricalData {
        if let cached = cachedData {
            return cached
        }
        
        guard let url = Bundle.main.url(forResource: "HistoricalReturns", withExtension: "json") else {
            throw DataError.fileNotFound
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let historicalData = try decoder.decode(HistoricalData.self, from: data)
        
        cachedData = historicalData
        return historicalData
    }
    
    /// Get historical returns for a specific asset class
    func getReturns(for assetClass: AssetClass) throws -> [Double] {
        let data = try loadHistoricalData()
        return data.returns(for: assetClass)
    }
    
    /// Get summary statistics for an asset class
    func getSummary(for assetClass: AssetClass) throws -> ReturnSummary? {
        let data = try loadHistoricalData()
        return data.summary(for: assetClass)
    }
    
    /// Calculate custom return distribution from user's portfolio
    func calculatePortfolioDistribution(portfolio: Portfolio) throws -> PortfolioDistribution {
        let data = try loadHistoricalData()
        let totalValue = portfolio.totalValue
        
        guard totalValue > 0 else {
            throw DataError.emptyPortfolio
        }
        
        // Get all historical years (using stocks as reference)
        let referenceReturns = data.returns(for: .stocks)
        let numberOfYears = referenceReturns.count
        
        // Calculate portfolio return for each historical year
        var portfolioReturns: [Double] = []
        
        for yearIndex in 0..<numberOfYears {
            var yearReturn: Double = 0
            
            for asset in portfolio.assets {
                let weight = asset.totalValue / totalValue
                let assetReturns = data.returns(for: asset.assetClass)
                
                if yearIndex < assetReturns.count {
                    yearReturn += weight * assetReturns[yearIndex]
                } else {
                    // If asset class has fewer years, use its mean
                    let summary = data.summary(for: asset.assetClass)
                    yearReturn += weight * (summary?.mean ?? asset.assetClass.defaultReturn)
                }
            }
            
            portfolioReturns.append(yearReturn)
        }
        
        return PortfolioDistribution(
            returns: portfolioReturns,
            mean: portfolioReturns.reduce(0, +) / Double(portfolioReturns.count),
            standardDeviation: calculateStandardDeviation(portfolioReturns)
        )
    }
    
    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}

// MARK: - Portfolio Distribution

struct PortfolioDistribution {
    let returns: [Double]
    let mean: Double
    let standardDeviation: Double
    
    func randomReturn() -> Double {
        returns.randomElement() ?? mean
    }
}

// MARK: - Errors

enum DataError: LocalizedError {
    case fileNotFound
    case invalidFormat
    case emptyPortfolio
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Historical data file not found"
        case .invalidFormat:
            return "Historical data file is not in valid format"
        case .emptyPortfolio:
            return "Portfolio is empty"
        }
    }
}

// MARK: - Default Historical Data (Fallback)

extension HistoricalDataService {
    
    /// Provides default data if JSON fails to load
    func getDefaultData() -> HistoricalData {
        return HistoricalData(
            metadata: HistoricalMetadata(
                description: "Default historical returns",
                dataSource: "Built-in defaults",
                startYear: 1926,
                endYear: 2024,
                notes: "Fallback data when HistoricalReturns.json is unavailable"
            ),
            assetClasses: [
                "stocks": AssetClassData(
                    name: "Stocks",
                    historicalReturns: generateNormalReturns(mean: 0.10, stdDev: 0.18, count: 98),
                    summary: ReturnSummary(mean: 0.10, median: 0.10, standardDeviation: 0.18, min: -0.43, max: 0.52),
                    notes: "Generated from normal distribution"
                ),
                "bonds": AssetClassData(
                    name: "Bonds",
                    historicalReturns: generateNormalReturns(mean: 0.045, stdDev: 0.08, count: 98),
                    summary: ReturnSummary(mean: 0.045, median: 0.045, standardDeviation: 0.08, min: -0.09, max: 0.26),
                    notes: "Generated from normal distribution"
                )
            ],
            correlations: nil
        )
    }
    
    private func generateNormalReturns(mean: Double, stdDev: Double, count: Int) -> [Double] {
        var returns: [Double] = []
        
        for _ in 0..<count {
            let u1 = Double.random(in: 0...1)
            let u2 = Double.random(in: 0...1)
            let z = sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
            let returnValue = mean + z * stdDev
            returns.append(returnValue)
        }
        
        return returns
    }
}
