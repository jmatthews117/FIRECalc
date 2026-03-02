# Simulation Setup View - Compilation Fixes

## Issues Fixed

### 1. ❌ Missing `benefitManager` Parameter in Preview

**Error:**
```
Missing argument for parameter 'benefitManager' in call
```

**Location:** Line 819 in `simulation_setup_view.swift` (#Preview)

**Problem:**
The `#Preview` macro was creating a `SimulationSetupView` without the required `benefitManager` parameter.

**Fix:**
```swift
// Before:
#Preview {
    SimulationSetupView(
        portfolioVM: PortfolioViewModel(portfolio: .sample),
        simulationVM: SimulationViewModel(),
        showingResults: Binding.constant(false)
    )
}

// After:
#Preview {
    SimulationSetupView(
        portfolioVM: PortfolioViewModel(portfolio: .sample),
        simulationVM: SimulationViewModel(),
        benefitManager: DefinedBenefitManager(),  // ✅ Added
        showingResults: Binding.constant(false)
    )
}
```

---

### 2. ❌ Incorrect Property Access: `settings.currentAge`

**Error:**
```
Value of type 'UserPreferences' has no member 'currentAge'
```

**Location:** Line 700 in `simulation_setup_view.swift` (runSimulation function)

**Problem:**
The code was trying to access `settings.currentAge`, but `UserPreferences` (returned by `loadSettings()`) doesn't have a `currentAge` property. The `currentAge` is stored separately in `UserDefaults`, not in the `UserPreferences` struct.

**Architecture:**
```swift
// UserPreferences struct (returned by loadSettings())
struct UserPreferences: Codable {
    var defaultSimulationRuns: Int
    var defaultTimeHorizon: Int
    var defaultInflationRate: Double
    var useHistoricalBootstrap: Bool
    var iexApiKey: String?
    var autoRefreshPrices: Bool
    var priceRefreshInterval: TimeInterval
    // ❌ NO currentAge property here!
}

// currentAge is stored directly in UserDefaults
// Key: AppConstants.UserDefaultsKeys.currentAge
```

**Fix:**
```swift
// Before (WRONG):
let settings = PersistenceService.shared.loadSettings()
let retirementAge = settings.currentAge > 0 ? settings.currentAge : nil

// After (CORRECT):
let storedAge = UserDefaults.standard.integer(forKey: AppConstants.UserDefaultsKeys.currentAge)
let retirementAge = storedAge > 0 ? storedAge : nil
```

---

## Why This Architecture?

The app uses two different storage mechanisms for user data:

### UserPreferences (Codable struct)
- Simulation defaults
- Bootstrap settings
- API keys
- Auto-refresh settings
- **Purpose:** Easily serializable settings that can be backed up/restored

### UserDefaults (Direct storage)
- Current age
- Annual savings
- Expected annual spend
- Withdrawal percentage
- Retirement target
- **Purpose:** Simple key-value storage for quick access with `@AppStorage`

The retirement planning data is stored directly in `UserDefaults` because it's accessed via `@AppStorage` property wrappers throughout the UI, which provides automatic two-way binding.

---

## Files Modified

✅ `simulation_setup_view.swift`
- Fixed preview to include `benefitManager` parameter
- Changed `settings.currentAge` to `UserDefaults.standard.integer(forKey:)`

---

## Verification

All compilation errors should now be resolved:
- ✅ Preview compiles correctly with all required parameters
- ✅ `currentAge` is accessed from the correct storage location
- ✅ Time-based income scheduling uses the correct retirement age

---

## Related Components

This fix ensures that:
1. **Monte Carlo simulations** correctly determine when scheduled income (pensions, Social Security) starts
2. **Preview mode** can be used for development/testing
3. **Data access** follows the app's storage architecture consistently

The retirement age is critical for the time-based income feature, as it determines year 0 of the simulation timeline.
