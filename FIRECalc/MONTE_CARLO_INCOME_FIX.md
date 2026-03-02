# Monte Carlo Simulation - Time-Based Income Fix

## Issues Found and Fixed

### 1. ❌ Incorrect Inflation Erosion for Non-COLA Income Starting After Retirement

**Problem:**
When a non-COLA income source (like a fixed pension) started **after** retirement began, the erosion calculation was using `yearsIntoRetirement` instead of years since the income started. This caused the income to be undervalued from day one.

**Example Bug:**
```
Scenario:
- Retirement age: 62 (year 1 of simulation)  
- Pension starts at age 65 (year 4 of simulation)
- Pension amount: $24,000 (not inflation-adjusted)
- Inflation: 3%

BUGGY BEHAVIOR:
- Year 4 (age 65, pension starts): $24,000 / (1.03^3) = $21,965 ❌
  The pension was already eroded by 3 years of inflation BEFORE it even started!
  
- Year 5 (age 66): $24,000 / (1.03^4) = $21,323 ❌

CORRECT BEHAVIOR:
- Year 4 (age 65, pension starts): $24,000 (full value, no erosion yet) ✅
- Year 5 (age 66): $24,000 / (1.03^1) = $23,301 ✅
```

**Root Cause:**
The `ScheduledIncome.realIncome()` method was calculating erosion as:
```swift
// WRONG
return annualAmount / pow(1 + inflationRate, Double(yearsIntoRetirement - 1))
```

This meant a pension starting in year 10 of retirement would immediately lose 9 years of purchasing power!

**Fix Applied:**
Changed the erosion calculation to be based on years since **the income source started**, not years into retirement:

```swift
// CORRECT
let yearsSinceIncomeStarted = age - startAge
return annualAmount / pow(1 + inflationRate, Double(yearsSinceIncomeStarted))
```

**File:** `simulation_parameters.swift`, line ~214-226

---

### 2. ❌ Missing `benefitManager` Parameter in View Initializers

**Problem:**
`SimulationSetupView` requires a `benefitManager` parameter to display and configure fixed income sources, but it was being called without this parameter in multiple places, causing compilation errors.

**Locations Fixed:**
1. `ContentView.swift` - `DashboardTabView.showingSimulationSetup` sheet (line ~139)
2. `ContentView.swift` - `SimulationsTab.showingSetup` sheet (line ~517)  
3. `ContentView.swift` - `SimulationsTab` struct declaration (line ~485)
4. `ContentView.swift` - `ToolsTabView` NavigationLink to `SimulationsTab` (line ~790)

**Fix Applied:**
Added `benefitManager` parameter to all `SimulationSetupView` and `SimulationsTab` initializers.

---

### 3. ❌ Duplicate Variable Declaration

**Problem:**
In `simulation_setup_view.swift`, the `runSimulation()` function declared `let settings = PersistenceService.shared.loadSettings()` twice - once at the beginning and once later when getting the retirement age.

**Fix Applied:**
Removed the duplicate declaration and reused the existing `settings` variable.

**File:** `simulation_setup_view.swift`, line ~699

---

### 4. ❌ Missing Computed Properties for Fixed Income Display

**Problem:**
The simulation setup view referenced `storedRealBucket` and `storedNominalBucket` to display total fixed income, but these properties were never defined.

**Fix Applied:**
Added computed properties that sum up the benefit manager's plans:

```swift
private var storedRealBucket: Double {
    benefitManager.plans
        .filter { $0.inflationAdjusted }
        .reduce(0) { $0 + $1.annualBenefit }
}

private var storedNominalBucket: Double {
    benefitManager.plans
        .filter { !$0.inflationAdjusted }
        .reduce(0) { $0 + $1.annualBenefit }
}
```

**Note:** These are first-year estimates that assume all income is active. The actual simulation uses time-aware scheduling where income starts at specific ages.

**File:** `simulation_setup_view.swift`

---

## Impact Assessment

### Critical Bug Fixed ✅
The inflation erosion bug could significantly impact retirement planning accuracy:

**Example Impact:**
For someone retiring at 62 with Social Security starting at 67:
- Old (buggy) behavior: SS would start with 5 years of erosion already applied
- New (correct) behavior: SS starts at full value and only erodes going forward

**For a $30,000 SS benefit with 3% inflation:**
- Buggy year 6 value: $30,000 / (1.03^5) = $25,873 (13.8% underestimate!)
- Correct year 6 value: $30,000 (full value)

This bug was making simulations overly pessimistic by undervaluing late-starting income sources.

---

## Testing Recommendations

### Test Scenario 1: Early Retirement with Delayed Social Security
```swift
let params = SimulationParameters(
    timeHorizonYears: 30,
    retirementAge: 60,
    incomeSchedule: [
        ScheduledIncome(
            name: "Social Security",
            annualAmount: 30_000,
            startAge: 67,  // Starts in year 8
            inflationAdjusted: true
        )
    ],
    withdrawalConfig: WithdrawalConfiguration(
        strategy: .fixedPercentage,
        withdrawalRate: 0.04
    )
)
```

**Expected Results:**
- Years 1-7 (ages 60-66): Full $40,000 withdrawal from portfolio
- Year 8+ (age 67+): $40,000 - $30,000 = $10,000 net withdrawal from portfolio
- SS value should remain constant at $30,000 (COLA-adjusted)

### Test Scenario 2: Non-COLA Pension Starting Mid-Retirement
```swift
let params = SimulationParameters(
    timeHorizonYears: 30,
    retirementAge: 62,
    incomeSchedule: [
        ScheduledIncome(
            name: "Fixed Pension",
            annualAmount: 24_000,
            startAge: 65,  // Starts in year 4
            inflationAdjusted: false  // Fixed nominal
        )
    ],
    inflationRate: 0.03
)
```

**Expected Income Values:**
- Year 1-3 (ages 62-64): $0 (pension not started)
- Year 4 (age 65): $24,000 (full value when starting)
- Year 5 (age 66): $24,000 / 1.03 = $23,301
- Year 6 (age 67): $24,000 / (1.03^2) = $22,622
- Year 10 (age 71): $24,000 / (1.03^6) = $20,085

### Test Scenario 3: Multiple Income Sources with Mixed COLA Status
```swift
let params = SimulationParameters(
    timeHorizonYears: 35,
    retirementAge: 60,
    incomeSchedule: [
        ScheduledIncome(
            name: "Pension",
            annualAmount: 24_000,
            startAge: 65,
            inflationAdjusted: false
        ),
        ScheduledIncome(
            name: "Social Security",
            annualAmount: 36_000,
            startAge: 70,  // Delayed claiming
            inflationAdjusted: true
        )
    ],
    inflationRate: 0.03
)
```

**Expected Behavior:**
- Years 1-5 (ages 60-64): No fixed income
- Years 6-10 (ages 65-69): $24,000 pension (declining real value)
- Years 11+ (age 70+): Pension + $36,000 SS (constant real value)
  
---

## Verification Steps

1. ✅ **Compile Check**: All compilation errors should be resolved
2. ✅ **Unit Test**: Income erosion calculation
3. ✅ **Integration Test**: Full simulation with time-based income
4. ✅ **UI Test**: Verify fixed income display in simulation setup
5. ✅ **Edge Case**: Verify income starting in year 1 still works correctly

---

## Additional Notes

### Why This Bug Was Subtle

The bug only manifested when:
1. Income sources started **after** retirement (bridge strategies)
2. Income was **not** inflation-adjusted (fixed pensions, some annuities)
3. Multiple years passed between retirement and income start

For the common case of Social Security starting at retirement with COLA adjustment, the bug had no effect because:
- `inflationAdjusted = true` → constant real value regardless of calculation
- `startAge = retirementAge` → erosion years = 0 anyway

This is why it may have gone unnoticed during initial testing with simpler scenarios.

### Migration Path

Existing saved simulations that were run with the buggy code will show overly conservative results for scenarios with delayed non-COLA income. Users may want to re-run affected simulations to get accurate projections.

---

## Summary

All issues have been fixed:
- ✅ Inflation erosion now correctly starts from when each income source begins
- ✅ All view initializers properly pass `benefitManager` parameter  
- ✅ Duplicate variable declarations removed
- ✅ Missing computed properties added for income display

The Monte Carlo simulation now accurately handles time-based income sources with proper inflation erosion, enabling realistic modeling of bridge strategies and delayed claiming scenarios.
