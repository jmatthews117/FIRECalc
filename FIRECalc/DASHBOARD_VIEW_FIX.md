# Dashboard View - Missing benefitManager Fix

## Issue Fixed

### ❌ Missing `benefitManager` Parameter in SimulationSetupView

**Error:**
```
Missing argument for parameter 'benefitManager' in call
Location: /Users/jmatthews117/Documents/FIRECalc/FIRECalc/FIRECalc/dashboard_view.swift:87:47
```

**Problem:**
The `SimulationSetupView` was being instantiated without the required `benefitManager` parameter, even though `benefitManager` was already defined as a `@StateObject` in the view.

**Fix:**
```swift
// Before (line 84-90):
.sheet(isPresented: $showingSimulationSetup) {
    SimulationSetupView(
        portfolioVM: portfolioVM,
        simulationVM: simulationVM,
        showingResults: $showingResults
    )
}

// After:
.sheet(isPresented: $showingSimulationSetup) {
    SimulationSetupView(
        portfolioVM: portfolioVM,
        simulationVM: simulationVM,
        benefitManager: benefitManager,  // ✅ Added
        showingResults: $showingResults
    )
}
```

## Context

The `DashboardView` already had `benefitManager` defined at the top of the struct:
```swift
struct DashboardView: View {
    @StateObject private var portfolioVM = PortfolioViewModel()
    @StateObject private var simulationVM = SimulationViewModel()
    @StateObject private var benefitManager = DefinedBenefitManager()  // ✅ Already exists
    @StateObject private var fireCalcVM = FIRECalculatorViewModel()
    // ...
}
```

The fix simply passes this existing `benefitManager` instance to the `SimulationSetupView`.

## Why This Parameter is Required

The `benefitManager` parameter is essential for:
1. **Displaying configured income sources** (pensions, Social Security) in the simulation setup UI
2. **Creating time-aware income schedules** that specify when each income source starts
3. **Calculating accurate withdrawals** that account for fixed income offsets

Without this parameter, users couldn't configure or view their defined benefit plans when setting up a Monte Carlo simulation.

## Files Modified

✅ `dashboard_view.swift` - Added `benefitManager` parameter to `SimulationSetupView` initialization

## Related Fixes

This is part of a series of fixes to ensure `benefitManager` is properly passed throughout the app:
- ✅ `ContentView.swift` - DashboardTabView (2 locations)
- ✅ `ContentView.swift` - SimulationsTab (2 locations)  
- ✅ `simulation_setup_view.swift` - Preview
- ✅ `dashboard_view.swift` - SimulationSetupView sheet (this fix)

All views that instantiate `SimulationSetupView` now correctly pass the `benefitManager` parameter.

## Verification

✅ Compilation error resolved
✅ Users can now access simulation setup from the dashboard
✅ Fixed income sources will be properly displayed and used in simulations
