//
//  Portfolio.swift
//  FIRECalc
//
//  User's complete portfolio of assets
//

import Foundation

struct Portfolio: Identifiable, Codable {
    let id: UUID
    var name: String
    var assets: [Asset]
    var createdDate: Date
    var lastModified: Date
    
    init(
        id: UUID = UUID(),
        name: String = "My Portfolio",
        assets: [Asset] = [],
        createdDate: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.assets = assets
        self.createdDate = createdDate
        self.lastModified = lastModified
    }
    
    // MARK: - Computed Properties
    
    var totalValue: Double {
        assets.reduce(0) { $0 + $1.totalValue }
    }
    
    var assetAllocation: [AssetClass: Double] {
        var allocation: [AssetClass: Double] = [:]
        let total = totalValue
        
        guard total > 0 else { return allocation }
        
        for asset in assets {
            let currentValue = allocation[asset.assetClass] ?? 0
            allocation[asset.assetClass] = currentValue + asset.totalValue
        }
        
        return allocation
    }
    
    var allocationPercentages: [AssetClass: Double] {
        let total = totalValue
        guard total > 0 else { return [:] }
        
        return assetAllocation.mapValues { $0 / total }
    }
    
    var weightedExpectedReturn: Double {
        let total = totalValue
        guard total > 0 else { return 0 }
        
        return assets.reduce(0.0) { sum, asset in
            let weight = asset.totalValue / total
            return sum + (weight * asset.expectedReturn)
        }
    }
    
    var weightedVolatility: Double {
        let total = totalValue
        guard total > 0 else { return 0 }
        
        // Simplified portfolio volatility (assumes uncorrelated assets)
        let variance = assets.reduce(0.0) { sum, asset in
            let weight = asset.totalValue / total
            let assetVariance = pow(asset.volatility, 2)
            return sum + pow(weight, 2) * assetVariance
        }
        
        return sqrt(variance)
    }
    
    var assetsWithTickers: [Asset] {
        assets.filter { $0.ticker != nil }
    }
    
    var assetsNeedingPriceUpdate: [Asset] {
        assetsWithTickers.filter { $0.isStale }
    }
    
    // MARK: - Asset Management
    
    mutating func addAsset(_ asset: Asset) {
        assets.append(asset)
        lastModified = Date()
    }
    
    mutating func updateAsset(_ asset: Asset) {
        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            assets[index] = asset
            lastModified = Date()
        }
    }
    
    mutating func removeAsset(_ asset: Asset) {
        assets.removeAll { $0.id == asset.id }
        lastModified = Date()
    }
    
    mutating func removeAssets(at offsets: IndexSet) {
        assets.remove(atOffsets: offsets)
        lastModified = Date()
    }
    
    // MARK: - Filtering
    
    func assets(for assetClass: AssetClass) -> [Asset] {
        assets.filter { $0.assetClass == assetClass }
    }
    
    func totalValue(for assetClass: AssetClass) -> Double {
        assets(for: assetClass).reduce(0) { $0 + $1.totalValue }
    }
}

// MARK: - Sample Portfolio

extension Portfolio {
    static let sample = Portfolio(
        name: "Retirement Portfolio",
        assets: Asset.samples
    )
    
    static let empty = Portfolio(
        name: "New Portfolio",
        assets: []
    )
}
