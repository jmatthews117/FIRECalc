# FIRECalc - Implementation Guide

## 📋 What We've Built So Far

### ✅ Phase 1 Complete: Core Models & Data

I've created the complete foundational architecture for your FIRE calculator app:

#### Models (Data Structures)
1. **AssetClass.swift** - Defines all asset types (stocks, bonds, REITs, etc.)
2. **Asset.swift** - Individual asset holdings with ticker support
3. **Portfolio.swift** - Collection of assets with allocation calculations
4. **WithdrawalStrategy.swift** - All 6 withdrawal strategy types
5. **SimulationParameters.swift** - Monte Carlo configuration
6. **SimulationResult.swift** - Simulation output with statistics
7. **UserProfile.swift** - User data, portfolios, and performance tracking

#### Services (Core Logic)
1. **MonteCarloEngine.swift** - Complete simulation engine with historical bootstrapping
2. **WithdrawalCalculator.swift** - All 6 withdrawal strategies implemented:
   - 4% Rule (Fixed Percentage)
   - Dynamic Percentage
   - Guardrails (Guyton-Klinger)
   - Required Minimum Distribution (RMD)
   - Fixed Dollar Amount
   - Custom Strategy

3. **HistoricalDataService.swift** - Loads and provides historical return data
4. **IEXCloudService.swift** - Live stock price integration with rate limiting

#### Data Files
1. **HistoricalReturns.json** - Real historical data (1926-2024) for:
   - S&P 500 stocks
   - 10-Year Treasury bonds
   - REITs
   - Real estate (Case-Shiller)
   - Gold
   - Bitcoin (2011-2024)
   - Cash/Money Market

2. **Constants.swift** - App-wide configuration and settings

---

## 📂 Current File Structure in Xcode

```
FIRECalc/
├── Models/
│   ├── AssetClass.swift ✅
│   ├── Asset.swift ✅
│   ├── Portfolio.swift ✅
│   ├── WithdrawalStrategy.swift ✅
│   ├── SimulationParameters.swift ✅
│   ├── SimulationResult.swift ✅
│   └── UserProfile.swift ✅
│
├── Services/
│   ├── MonteCarloEngine.swift ✅
│   ├── WithdrawalCalculator.swift ✅
│   ├── HistoricalDataService.swift ✅
│   └── IEXCloudService.swift ✅
│
├── Data/
│   └── HistoricalReturns.json ✅
│
└── Utilities/
    └── Constants.swift ✅
```

---

## 🚀 Next Steps: What to Build

### Phase 2: Persistence & ViewModels

#### 1. PersistenceService.swift
Location: `FIRECalc/Services/PersistenceService.swift`

This service will handle:
- Saving/loading portfolios from local storage
- UserDefaults for settings
- iCloud backup capability
- Export/import functionality

**Key Features:**
```swift
- savePortfolio(portfolio: Portfolio)
- loadPortfolios() -> [Portfolio]
- saveUserProfile(profile: UserProfile)
- loadUserProfile() -> UserProfile?
- exportToJSON() -> Data
- importFromJSON(data: Data)
```

#### 2. PortfolioViewModel.swift
Location: `FIRECalc/ViewModels/PortfolioViewModel.swift`

Manages portfolio state and operations:
```swift
@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var portfolios: [Portfolio]
    @Published var activePortfolio: Portfolio?
    @Published var isLoading: Bool
    @Published var errorMessage: String?
    
    func addAsset(_ asset: Asset)
    func updateAsset(_ asset: Asset)
    func deleteAsset(_ asset: Asset)
    func refreshPrices() async
    func savePortfolio()
}
```

#### 3. SimulationViewModel.swift
Location: `FIRECalc/ViewModels/SimulationViewModel.swift`

Manages simulations:
```swift
@MainActor
class SimulationViewModel: ObservableObject {
    @Published var parameters: SimulationParameters
    @Published var currentResult: SimulationResult?
    @Published var isSimulating: Bool
    @Published var progress: Double
    
    func runSimulation(portfolio: Portfolio) async
    func updateParameters(_ params: SimulationParameters)
    func saveResult()
}
```

---

### Phase 3: User Interface (Views)

#### Simple Flow (Priority 1)
1. **SimpleInputView.swift** - Quick portfolio entry
2. **DashboardView.swift** - Main overview screen
3. **SimulationResultsView.swift** - Display results

#### Advanced Features (Priority 2)
4. **AdvancedInputView.swift** - Detailed asset entry
5. **AssetListView.swift** - Manage assets
6. **SimulationSetupView.swift** - Configure parameters
7. **SettingsView.swift** - App settings & API key

#### Charts (Priority 3)
8. **AllocationChartView.swift** - Pie chart of assets
9. **ProjectionChartView.swift** - Timeline projections
10. **SuccessProbabilityView.swift** - Monte Carlo results

---

## 🏗️ How to Set Up in Xcode

### Step 1: Create New Project
1. Open Xcode
2. File → New → Project
3. Choose "iOS" → "App"
4. Product Name: **FIRECalc**
5. Interface: **SwiftUI**
6. Language: **Swift**
7. Minimum Deployment: **iOS 17.0**

### Step 2: Create Folder Structure
1. In Project Navigator, right-click "FIRECalc" folder
2. Create these groups (folders):
   - Models
   - ViewModels
   - Views
   - Services
   - Data
   - Utilities

### Step 3: Add Files
1. **For Swift files:**
   - Right-click the appropriate folder
   - New File → Swift File
   - Copy the code I provided
   - Paste into the file

2. **For JSON file (HistoricalReturns.json):**
   - Right-click "Data" folder
   - New File → Empty file
   - Name it "HistoricalReturns.json"
   - Copy the entire JSON content
   - Paste into the file
   - **IMPORTANT:** In File Inspector, check "Target Membership" for FIRECalc

### Step 4: Update Info.plist
Add description for internet access:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>cloud.iexapis.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

---

## 🧪 Testing the Core Logic

### Test 1: Load Historical Data
```swift
// In any view or test file
Task {
    do {
        let service = HistoricalDataService.shared
        let data = try service.loadHistoricalData()
        print("Loaded \(data.assetClasses.count) asset classes")
        
        if let stockData = data.assetClasses["stocks"] {
            print("Stock returns: \(stockData.historicalReturns.count) years")
            print("Mean return: \(stockData.summary.mean)")
        }
    } catch {
        print("Error: \(error)")
    }
}
```

### Test 2: Run Simple Simulation
```swift
// Create a simple portfolio
let portfolio = Portfolio(
    name: "Test Portfolio",
    assets: [
        Asset(name: "Stocks", assetClass: .stocks, quantity: 1, unitValue: 500000),
        Asset(name: "Bonds", assetClass: .bonds, quantity: 1, unitValue: 300000)
    ]
)

// Set up parameters
let params = SimulationParameters(
    numberOfRuns: 1000,
    timeHorizonYears: 30,
    inflationRate: 0.02,
    useHistoricalBootstrap: true,
    initialPortfolioValue: 800000
)

// Run simulation
Task {
    do {
        let engine = MonteCarloEngine()
        let historicalData = try HistoricalDataService.shared.loadHistoricalData()
        
        let result = try await engine.runSimulation(
            portfolio: portfolio,
            parameters: params,
            historicalData: historicalData
        )
        
        print("Success Rate: \(result.successRate * 100)%")
        print("Median Final Balance: \(result.medianFinalBalance.toCurrency())")
    } catch {
        print("Simulation error: \(error)")
    }
}
```

---

## 🎨 Recommended UI Approach

### Color Scheme
- **Primary:** Blue (trust, stability)
- **Success:** Green (growth, positive returns)
- **Warning:** Orange (caution, moderate risk)
- **Danger:** Red (high risk, depletion)

### Key Screens Layout

#### 1. Dashboard (Main Screen)
```
┌─────────────────────────────┐
│   Portfolio Overview        │
│   💼 Total: $1,234,567      │
│                             │
│   [Simple Entry]  [Advanced]│
│                             │
│   Asset Allocation          │
│   🥧 [Pie Chart]            │
│                             │
│   Latest Simulation         │
│   ✅ 89% Success Rate       │
│   [View Details]            │
│                             │
│   [⚡ Run New Simulation]   │
└─────────────────────────────┘
```

#### 2. Simulation Results
```
┌─────────────────────────────┐
│   Simulation Results        │
│                             │
│   Success Rate: 89%         │
│   [Progress Bar]            │
│                             │
│   Final Balance             │
│   📊 [Distribution Chart]   │
│                             │
│   Projected Timeline        │
│   📈 [Line Chart]           │
│                             │
│   Key Metrics               │
│   💰 Median: $1.25M         │
│   📉 10th %ile: $450K       │
│   📈 90th %ile: $2.5M       │
└─────────────────────────────┘
```

---

## 🔑 IEX Cloud API Setup

### Getting an API Key
1. Go to https://iexcloud.io
2. Sign up for free account
3. Get your publishable token
4. **Free tier:** 50,000 requests/month (~1,600/day)

### Adding API Key in App
In Settings view, users will enter their key which gets stored securely:
```swift
await IEXCloudService.shared.setAPIKey("pk_...")
```

### Rate Limiting
The service automatically tracks requests:
```swift
let remaining = await IEXCloudService.shared.getRemainingRequests()
print("Requests remaining today: \(remaining)")
```

---

## 📊 App Store Optimization Tips

### Keywords to Target
- FIRE calculator
- retirement planning
- financial independence
- Monte Carlo simulation
- withdrawal strategy
- portfolio tracker
- early retirement calculator

### Screenshots to Prepare
1. Clean dashboard with portfolio value
2. Asset allocation pie chart
3. Simulation results with success rate
4. Projected timeline chart
5. Simple input screen

### App Description Focus
- **First Line:** "Plan your path to Financial Independence and Early Retirement (FIRE)"
- **Key Features:** Monte Carlo simulations, multiple withdrawal strategies, live portfolio tracking
- **Differentiation:** Historical bootstrapping, 6 withdrawal strategies, beautiful charts

---

## 🐛 Common Issues & Solutions

### Issue: JSON File Not Found
**Solution:** Ensure HistoricalReturns.json has Target Membership checked in File Inspector

### Issue: Simulation Takes Too Long
**Solution:** Start with 1,000 runs for testing, increase to 10,000 for production

### Issue: API Rate Limit Hit
**Solution:** Implement caching, batch requests, or prompt user to upgrade IEX plan

---

## 📝 TODO Checklist

### Immediate (Week 1)
- [ ] Set up Xcode project
- [ ] Add all Model files
- [ ] Add all Service files
- [ ] Add HistoricalReturns.json
- [ ] Test data loading
- [ ] Test simulation engine

### Short-term (Week 2-3)
- [ ] Build PersistenceService
- [ ] Create ViewModels
- [ ] Build simple input screen
- [ ] Build dashboard
- [ ] Build results view
- [ ] Add basic charts

### Medium-term (Week 4-6)
- [ ] Advanced input screens
- [ ] Settings & API integration
- [ ] Polish UI/UX
- [ ] Add animations
- [ ] Test on device
- [ ] Beta testing

### Before Launch
- [ ] App Store Connect setup
- [ ] Privacy policy
- [ ] Screenshots & marketing
- [ ] Submit for review

---

## 🤝 Ready for Next Phase?

When you're ready, I can provide:
1. **PersistenceService** - Full implementation with iCloud backup
2. **ViewModels** - Complete state management
3. **UI Views** - SwiftUI screens with charts
4. **App Entry Point** - FIRECalcApp.swift and ContentView.swift

Just let me know which component you want next, or if you have questions about what we've built so far!

---

## 📞 Need Help?

If you encounter issues:
1. Check that all files are in correct folders
2. Ensure HistoricalReturns.json is included in target
3. Verify iOS deployment target is 17.0+
4. Clean build folder (Cmd+Shift+K) and rebuild

Good luck building FIRECalc! 🚀
