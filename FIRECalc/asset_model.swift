//
//  Asset.swift
//  FIRECalc
//
//  Individual asset holding in a portfolio
//

import Foundation

struct Asset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var assetClass: AssetClass
    var ticker: String?  // Optional ticker symbol for live price updates
    
    // Value tracking
    var quantity: Double  // Number of shares/units
    var unitValue: Double  // Price per unit (or total if quantity = 1)
    var purchaseDate: Date
    
    // Custom return expectations (overrides asset class defaults)
    var customExpectedReturn: Double?
    var customVolatility: Double?
    
    // Live price data (from API)
    var currentPrice: Double?
    var lastUpdated: Date?
    var priceChange: Double?  // Daily change percentage
    
    init(
        id: UUID = UUID(),
        name: String,
        assetClass: AssetClass,
        ticker: String? = nil,
        quantity: Double = 1.0,
        unitValue: Double,
        purchaseDate: Date = Date(),
        customExpectedReturn: Double? = nil,
        customVolatility: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.assetClass = assetClass
        self.ticker = ticker
        self.quantity = quantity
        self.unitValue = unitValue
        self.purchaseDate = purchaseDate
        self.customExpectedReturn = customExpectedReturn
        self.customVolatility = customVolatility
    }
    
    // MARK: - Computed Properties
    
    var totalValue: Double {
        if let current = currentPrice {
            return current * quantity
        }
        return unitValue * quantity
    }
    
    var expectedReturn: Double {
        customExpectedReturn ?? assetClass.defaultReturn
    }
    
    var volatility: Double {
        customVolatility ?? assetClass.defaultVolatility
    }
    
    var hasLiveData: Bool {
        currentPrice != nil && lastUpdated != nil
    }
    
    var isStale: Bool {
        guard let updated = lastUpdated else { return true }
        return Date().timeIntervalSince(updated) > 3600 // 1 hour
    }
    
    // MARK: - Helpers
    
    func updatedWithLivePrice(_ price: Double, change: Double? = nil) -> Asset {
        var updated = self
        updated.currentPrice = price
        updated.lastUpdated = Date()
        updated.priceChange = change
        return updated
    }
}

// MARK: - Sample Data for Previews

extension Asset {
    static let samples: [Asset] = [
        Asset(
            name: "Vanguard S&P 500",
            assetClass: .stocks,
            ticker: "VOO",
            quantity: 100,
            unitValue: 450.00
        ),
        Asset(
            name: "US Treasury Bonds",
            assetClass: .bonds,
            quantity: 50,
            unitValue: 1000.00
        ),
        Asset(
            name: "Bitcoin",
            assetClass: .crypto,
            ticker: "BTC-USD",
            quantity: 0.5,
            unitValue: 45000.00
        ),
        Asset(
            name: "Rental Property",
            assetClass: .realEstate,
            quantity: 1,
            unitValue: 350000.00
        ),
        Asset(
            name: "Gold ETF",
            assetClass: .preciousMetals,
            ticker: "GLD",
            quantity: 20,
            unitValue: 180.00
        )
    ]
}
