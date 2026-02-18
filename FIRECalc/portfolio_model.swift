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

// MARK: - Custom Allocation Support

extension Portfolio {
    /// Returns a new Portfolio whose asset values reflect `weights` (fractional,
    /// must sum to ≈ 1.0) while preserving the real per-class return/volatility
    /// assumptions of the original assets.  Classes absent from the original
    /// portfolio fall back to `AssetClass` defaults.
    ///
    /// The engine only cares about proportional weights (it normalises them
    /// internally), so we represent each class as a single notional asset
    /// worth `totalValue * weight`.
    func applyingAllocationWeights(_ weights: [AssetClass: Double]) -> Portfolio {
        let baseValue = max(totalValue, 1) // avoid zero division

        // Build a representative asset for each class in the weight map.
        let syntheticAssets: [Asset] = weights.compactMap { (ac, weight) in
            guard weight > 0 else { return nil }
            let notionalValue = baseValue * weight

            // Prefer return/volatility from the first matching real asset;
            // fall back to class defaults.
            let template = assets.first { $0.assetClass == ac }
            let expectedReturn = template?.expectedReturn ?? ac.defaultReturn
            let volatility     = template?.volatility     ?? ac.defaultVolatility

            return Asset(
                name: ac.rawValue,
                assetClass: ac,
                quantity: notionalValue,
                unitValue: 1.0,
                purchaseDate: Date(),
                customExpectedReturn: expectedReturn,
                customVolatility: volatility
            )
        }

        return Portfolio(
            id: id,
            name: name,
            assets: syntheticAssets,
            createdDate: createdDate,
            lastModified: lastModified
        )
    }
}

