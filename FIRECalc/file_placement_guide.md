# File Placement Quick Reference

## 📁 Copy These Files to Your Xcode Project

### Models Folder (`FIRECalc/Models/`)
```
AssetClass.swift ..................... Defines asset types (stocks, bonds, etc.)
Asset.swift .......................... Individual asset holdings
Portfolio.swift ...................... Collection of user's assets
WithdrawalStrategy.swift ............. Retirement withdrawal strategies
SimulationParameters.swift ........... Monte Carlo configuration
SimulationResult.swift ............... Simulation output data
UserProfile.swift .................... User settings and history
```

### Services Folder (`FIRECalc/Services/`)
```
MonteCarloEngine.swift ............... Core simulation engine
WithdrawalCalculator.swift ........... Implements withdrawal strategies
HistoricalDataService.swift .......... Loads historical return data
IEXCloudService.swift ................ Live stock price API
```

### Data Folder (`FIRECalc/Data/`)
```
HistoricalReturns.json ............... 98 years of market data (1926-2024)
                                       ⚠️ MUST check "Target Membership"
```

### Utilities Folder (`FIRECalc/Utilities/`)
```
Constants.swift ...................... App-wide settings and helpers
```

---

## ⚡ Quick Setup Steps

1. **Create Xcode Project**
   - iOS App
   - Name: FIRECalc
   - Interface: SwiftUI
   - Language: Swift
   - iOS 17.0+

2. **Create Folder Groups**
   - Models
   - Services  
   - Data
   - Utilities

3. **Add Files**
   - Copy each .swift file into its folder
   - For JSON: Create file, paste content, CHECK TARGET MEMBERSHIP

4. **Verify**
   - Build (Cmd+B) - should succeed
   - All files show in Project Navigator
   - HistoricalReturns.json has checkmark in Target Membership

---

## 🧪 Quick Test

Add this to any SwiftUI view to verify everything works:

```swift
Button("Test Core") {
    Task {
        // Test 1: Load data
        let service = HistoricalDataService.shared
        let data = try! service.loadHistoricalData()
        print("✅ Loaded \(data.assetClasses.count) asset classes")
        
        // Test 2: Create portfolio
        let portfolio = Portfolio.sample
        print("✅ Portfolio value: \(portfolio.totalValue.toCurrency())")
        
        // Test 3: Run mini simulation
        let params = SimulationParameters(
            numberOfRuns: 100,
            timeHorizonYears: 5,
            initialPortfolioValue: 100000
        )
        
        let engine = MonteCarloEngine()
        let result = try! await engine.runSimulation(
            portfolio: portfolio,
            parameters: params,
            historicalData: data
        )
        
        print("✅ Success rate: \(result.successRate * 100)%")
    }
}
```

If you see three ✅ messages in console, you're ready to build the UI!

---

## 🎯 What's Working Now

✅ All data models defined  
✅ Monte Carlo simulation engine complete  
✅ 6 withdrawal strategies implemented  
✅ Historical data (1926-2024) ready  
✅ Live API integration structure  
✅ Rate limiting for free tier  

## 🚧 What's Next

Need to build:
- [ ] PersistenceService (save/load)
- [ ] ViewModels (state management)
- [ ] SwiftUI Views (UI)
- [ ] Charts (visualizations)
- [ ] Settings screen

---

## 📞 Ready to Continue?

Tell me which component to build next:
1. **PersistenceService** - Save/load portfolios
2. **ViewModels** - State management  
3. **Simple UI** - Basic screens first
4. **Full UI** - Complete interface
5. **Charts** - Data visualization

I'll provide complete, copy-paste ready code for any of these!
