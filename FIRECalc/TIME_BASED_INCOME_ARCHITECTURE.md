# Time-Based Income System Architecture

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      User Input Layer                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐         ┌──────────────────────┐         │
│  │ Retirement Age   │         │ Defined Benefit Plans│         │
│  │                  │         │                      │         │
│  │  - Age: 62       │         │  - Social Security   │         │
│  │  - Start year: 0 │         │    Start: 67, COLA   │         │
│  └──────────────────┘         │  - Pension           │         │
│                               │    Start: 65, Fixed  │         │
│                               └──────────────────────┘         │
│                                         │                       │
└─────────────────────────────────────────┼───────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Conversion Layer                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SimulationParameters.createIncomeSchedule(from: plans)        │
│                                                                 │
│  DefinedBenefitPlan → ScheduledIncome                          │
│  ┌─────────────────────────────────────────────┐               │
│  │ ScheduledIncome                             │               │
│  │  - id: UUID                                 │               │
│  │  - name: String                             │               │
│  │  - annualAmount: Double                     │               │
│  │  - startAge: Int                            │               │
│  │  - endAge: Int?                             │               │
│  │  - inflationAdjusted: Bool                  │               │
│  └─────────────────────────────────────────────┘               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Simulation Parameters                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  struct SimulationParameters {                                 │
│    var retirementAge: Int?                                     │
│    var incomeSchedule: [ScheduledIncome]?                      │
│    var inflationRate: Double                                   │
│    // ... other parameters                                     │
│                                                                 │
│    func totalScheduledIncome(year: Int) -> Double {            │
│      // Calculate age: retirementAge + year - 1               │
│      // Sum all active income sources                         │
│    }                                                           │
│  }                                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              Monte Carlo Engine (per year loop)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  for year in 1...timeHorizonYears {                            │
│                                                                 │
│    ┌─────────────────────────────────────────────┐             │
│    │ 1. Apply Returns                            │             │
│    │    balance *= (1 + realReturn)              │             │
│    └─────────────────────────────────────────────┘             │
│                        ▼                                        │
│    ┌─────────────────────────────────────────────┐             │
│    │ 2. Get Scheduled Income for This Year       │             │
│    │    scheduledIncome =                         │             │
│    │      parameters.totalScheduledIncome(year)   │             │
│    │                                              │             │
│    │    ┌──────────────────────────────────┐     │             │
│    │    │ For each income source:          │     │             │
│    │    │  - Check if age >= startAge      │     │             │
│    │    │  - Check if age <= endAge        │     │             │
│    │    │  - Apply COLA or erosion         │     │             │
│    │    │  - Sum all active sources        │     │             │
│    │    └──────────────────────────────────┘     │             │
│    └─────────────────────────────────────────────┘             │
│                        ▼                                        │
│    ┌─────────────────────────────────────────────┐             │
│    │ 3. Calculate Withdrawal                     │             │
│    │    withdrawal = withdrawalCalc.calculate(   │             │
│    │      ...,                                   │             │
│    │      scheduledIncome: scheduledIncome       │             │
│    │    )                                        │             │
│    └─────────────────────────────────────────────┘             │
│                        ▼                                        │
│    ┌─────────────────────────────────────────────┐             │
│    │ 4. Subtract Withdrawal                      │             │
│    │    balance -= withdrawal                    │             │
│    └─────────────────────────────────────────────┘             │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Withdrawal Calculator                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  func calculateWithdrawal(                                     │
│    ...,                                                        │
│    scheduledIncome: Double                                     │
│  ) -> Double {                                                 │
│                                                                 │
│    // Calculate base withdrawal from strategy                  │
│    var withdrawal = baseWithdrawalAmount                       │
│                                                                 │
│    // Offset by scheduled income                              │
│    if scheduledIncome > 0 {                                    │
│      withdrawal = max(0, withdrawal - scheduledIncome)         │
│    }                                                           │
│                                                                 │
│    return withdrawal                                           │
│  }                                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Timeline Example: Retire at 60, SS at 67, Pension at 62

```
Age Timeline:
───────────────────────────────────────────────────────────────────
Age:        60    61    62    63    64    65    66    67    68 ...
Year:        1     2     3     4     5     6     7     8     9 ...
───────────────────────────────────────────────────────────────────

Pension:    ──────────────[████████████████████████████████████]
            $0    $0   $24k  $23k  $22k  $21k  $20k  $20k  $19k
                         ▲                                  ▲
                      Starts                          Erodes (no COLA)

SS:         ────────────────────────────────────────[████████████]
            $0    $0    $0    $0    $0    $0    $0   $30k  $30k
                                                      ▲
                                                   Starts (COLA)

Total:      $0    $0   $24k  $23k  $22k  $21k  $20k  $50k  $49k


Portfolio Withdrawal (assuming $80k spending need):
───────────────────────────────────────────────────────────────────
Need:      $80k  $80k  $80k  $80k  $80k  $80k  $80k  $80k  $80k
Income:     $0    $0   $24k  $23k  $22k  $21k  $20k  $50k  $49k
           ─────────────────────────────────────────────────────────
Withdraw:  $80k  $80k  $56k  $57k  $58k  $59k  $60k  $30k  $31k
           ████  ████  ███   ███   ███   ███   ███   █▓    █▓
```

## Income Calculation Logic

### For COLA Income (inflationAdjusted = true)

```swift
func realIncome(at age: Int, inflationRate: Double, yearsIntoRetirement: Int) -> Double {
    guard age >= startAge else { return 0 }
    if let end = endAge, age > end { return 0 }
    
    if inflationAdjusted {
        return annualAmount  // ✅ Constant real value
    }
    // ...
}
```

**Example: Social Security**
```
annualAmount: $30,000
Year 1:  $30,000 / (1.025)^0 = $30,000
Year 5:  $30,000 / (1.025)^0 = $30,000  ← Real value stays constant
Year 10: $30,000 / (1.025)^0 = $30,000
```

### For Fixed Nominal Income (inflationAdjusted = false)

```swift
func realIncome(at age: Int, inflationRate: Double, yearsIntoRetirement: Int) -> Double {
    guard age >= startAge else { return 0 }
    if let end = endAge, age > end { return 0 }
    
    if inflationAdjusted {
        // ...
    } else {
        return annualAmount / pow(1 + inflationRate, Double(yearsIntoRetirement - 1))
    }
}
```

**Example: Fixed Pension at 2.5% inflation**
```
annualAmount: $24,000
Year 1:  $24,000 / (1.025)^0 = $24,000
Year 2:  $24,000 / (1.025)^1 = $23,415
Year 5:  $24,000 / (1.025)^4 = $21,774  ← Real value erodes
Year 10: $24,000 / (1.025)^9 = $19,232
Year 20: $24,000 / (1.025)^19 = $14,960
```

## Age Calculation Logic

```swift
extension SimulationParameters {
    func totalScheduledIncome(year: Int) -> Double {
        guard let schedule = incomeSchedule, let retAge = retirementAge else { 
            return 0 
        }
        
        // Year 1 = retirement age
        // Year 2 = retirement age + 1, etc.
        let currentAge = retAge + year - 1
        
        return schedule.reduce(0) { total, income in
            total + income.realIncome(
                at: currentAge,
                inflationRate: inflationRate,
                yearsIntoRetirement: year
            )
        }
    }
}
```

**Example:**
```
retirementAge: 62
year: 8

currentAge = 62 + 8 - 1 = 69

For Social Security (startAge: 67):
  69 >= 67 ✅ → Income active

For Pension (startAge: 62):
  69 >= 62 ✅ → Income active
```

## Complete Scenario Walkthrough

### Setup
```swift
let params = SimulationParameters(
    retirementAge: 60,
    incomeSchedule: [
        ScheduledIncome(name: "Pension", annualAmount: 24_000, startAge: 62, inflationAdjusted: false),
        ScheduledIncome(name: "SS", annualAmount: 30_000, startAge: 67, inflationAdjusted: true)
    ],
    inflationRate: 0.025
)
```

### Year 1 (Age 60)
```
currentAge = 60 + 1 - 1 = 60

Pension: 60 >= 62? ❌ → $0
SS:      60 >= 67? ❌ → $0

totalScheduledIncome = $0
```

### Year 3 (Age 62)
```
currentAge = 60 + 3 - 1 = 62

Pension: 62 >= 62? ✅
  inflationAdjusted = false
  realValue = $24,000 / (1.025)^(3-1) = $24,000 / 1.050625 = $22,843

SS:      62 >= 67? ❌ → $0

totalScheduledIncome = $22,843
```

### Year 8 (Age 67)
```
currentAge = 60 + 8 - 1 = 67

Pension: 67 >= 62? ✅
  inflationAdjusted = false
  realValue = $24,000 / (1.025)^(8-1) = $24,000 / 1.1887 = $20,188

SS:      67 >= 67? ✅
  inflationAdjusted = true
  realValue = $30,000 (constant)

totalScheduledIncome = $20,188 + $30,000 = $50,188
```

## Integration Points

### 1. User Input → Parameters
```swift
// In your view model or setup view
let incomeSchedule = benefitManager.createIncomeSchedule()

let params = SimulationParameters(
    retirementAge: userRetirementAge,
    incomeSchedule: incomeSchedule
)
```

### 2. Parameters → Engine
```swift
// Monte Carlo engine uses it automatically
for year in 1...totalYears {
    let scheduledIncome = parameters.totalScheduledIncome(year: year)
    // Use in withdrawal calculation
}
```

### 3. Engine → Results
```swift
// Results show year-by-year balances and withdrawals
// Now accurately reflecting when income starts/stops
result.yearlyBalances  // Correct portfolio depletion
result.yearlyWithdrawals  // Correct withdrawal amounts
```

## Comparison: Old vs New

### Old System
```
┌──────────────────────────────────────┐
│ DefinedBenefitPlan                   │
│  - startAge: 67  ← IGNORED!          │
├──────────────────────────────────────┤
│ Convert to simple buckets:           │
│  fixedIncomeReal: $30,000            │
│  fixedIncomeNominal: $24,000         │
├──────────────────────────────────────┤
│ Applied from year 1 ❌                │
└──────────────────────────────────────┘
```

### New System
```
┌──────────────────────────────────────┐
│ ScheduledIncome                      │
│  - startAge: 67  ← RESPECTED! ✅      │
│  - inflationAdjusted: true           │
├──────────────────────────────────────┤
│ Applied when age >= startAge         │
│ Calculated per year:                 │
│  Year 1-7: $0                        │
│  Year 8+:  $30,000                   │
└──────────────────────────────────────┘
```

## Summary

The time-based income system:

1. **Tracks retirement age** as the baseline (year 0)
2. **Converts age-based plans** to time-aware schedules
3. **Calculates current age** each simulation year
4. **Applies income only when active** (age >= startAge && age <= endAge)
5. **Handles COLA vs fixed** nominal income correctly
6. **Integrates seamlessly** with existing Monte Carlo logic

This produces **accurate retirement projections** that respect the timing of income sources.
