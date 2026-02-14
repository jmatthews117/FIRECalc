//
//  AssetClass.swift
//  FIRECalc
//
//  Defines the types of assets users can hold in their portfolio
//

import Foundation
import SwiftUI

enum AssetClass: String, Codable, CaseIterable, Identifiable {
    case stocks = "Stocks"
    case bonds = "Bonds"
    case corporateBonds = "Corporate Bonds"
    case reits = "REITs"
    case realEstate = "Real Estate"
    case preciousMetals = "Precious Metals"
    case crypto = "Cryptocurrency"
    case cash = "Cash"
    case other = "Other"
    
    var id: String { rawValue }
    
    // Default expected annual return (can be customized by user)
    var defaultReturn: Double {
        switch self {
        case .stocks: return 0.10      // 10%
        case .bonds: return 0.045      // 4.5%
        case .corporateBonds: return 0.055 // 5.5%
        case .reits: return 0.09       // 9%
        case .realEstate: return 0.08  // 8%
        case .preciousMetals: return 0.05 // 5%
        case .crypto: return 0.15      // 15% (high risk)
        case .cash: return 0.02        // 2%
        case .other: return 0.05       // 5%
        }
    }
    
    // Default standard deviation (volatility)
    var defaultVolatility: Double {
        switch self {
        case .stocks: return 0.18      // 18%
        case .bonds: return 0.06       // 6%
        case .corporateBonds: return 0.08  // 8%
        case .reits: return 0.20       // 20%
        case .realEstate: return 0.12  // 12%
        case .preciousMetals: return 0.15 // 15%
        case .crypto: return 0.60      // 60% (very volatile)
        case .cash: return 0.01        // 1%
        case .other: return 0.10       // 10%
        }
    }
    
    // Icon name for SF Symbols
    var iconName: String {
        switch self {
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .bonds: return "doc.text"
        case .corporateBonds: return "building.columns"
        case .reits: return "building.2"
        case .realEstate: return "house"
        case .preciousMetals: return "crown"
        case .crypto: return "bitcoinsign.circle"
        case .cash: return "dollarsign.circle"
        case .other: return "questionmark.circle"
        }
    }
    
    // Color theme for charts
    var color: Color {
        switch self {
        case .stocks:         return .blue
        case .bonds:          return .green
        case .corporateBonds: return .teal
        case .reits:          return .purple
        case .realEstate:     return .orange
        case .preciousMetals: return .yellow.opacity(0.8)
        case .crypto:         return .pink
        case .cash:           return .gray
        case .other:          return .brown
        }
    }
    
    // Whether this asset class supports ticker symbols
    var supportsTicker: Bool {
        switch self {
        case .stocks, .reits, .crypto:
            return true
        default:
            return false
        }
    }
}
