# Time-Based Income in Monte Carlo Simulations

## Overview

The Monte Carlo simulation engine now properly handles **time-based income sources** like Social Security, pensions, and annuities that start at specific ages during retirement. This ensures accurate modeling of retirement scenarios where income sources don't all begin simultaneously.

## Key Changes

### 1. New `ScheduledIncome` Structure

Replaces the simple `fixedIncome` offset with a time-aware schedule:

```swift
struct ScheduledIncome: Codable, Identifiable {
    let id: UUID
    var name: String
    var annualAmount: Double
    var startAge: Int              // Age when income begins
    var endAge: Int?               // Optional age when income ends
    var inflationAdjusted: Bool    // COLA vs. fixed nominal
}
```

### 2. Enhanced `SimulationParameters`

Now includes:
- `retirementAge: Int?` - The age at which retirement begins (year 0)
- `incomeSchedule: [ScheduledIncome]?` - Time-aware income sources

### 3. Updated Withdrawal Logic

The `WithdrawalCalculator` now:
- Accepts `scheduledIncome` parameter for each year
- Properly calculates income based on current age and erosion for non-COLA income
- Maintains backward compatibility with legacy `fixedIncome` fields

## Usage Examples

### Example 1: Social Security Starting at Age 67

```swift
let socialSecurity = ScheduledIncome(
    name: "Social Security",
    annualAmount: 30_000,
    startAge: 67,
    endAge: nil,  // Continues for life
    inflationAdjusted: true  // COLA-adjusted
)

let params = SimulationParameters(
    numberOfRuns: 10_000,
    timeHorizonYears: 30,
    inflationRate: 0.025,
    useHistoricalBootstrap: true,
    initialPortfolioValue: 1_000_000,
    retirementAge: 62,  // Retiring at 62
    incomeSchedule: [socialSecurity],
    withdrawalConfig: WithdrawalConfiguration(
        strategy: .fixedPercentage,
        withdrawalRate: 0.04
    )
)
```

**Result:** 
- Years 1-5 (ages 62-66): Full withdrawal from portfolio
- Years 6+ (age 67+): Withdrawal reduced by $30,000 (real dollars)

### Example 2: Multiple Income Sources

```swift
let pension = ScheduledIncome(
    name: "Company Pension",
    annualAmount: 24_000,
    startAge: 65,
    endAge: nil,
    inflationAdjusted: false  // Fixed nominal (erodes with inflation)
)

let socialSecurity = ScheduledIncome(
    name: "Social Security",
    annualAmount: 36_000,
    startAge: 70,  // Delayed claiming for higher benefit
    endAge: nil,
    inflationAdjusted: true
)

let params = SimulationParameters(
    numberOfRuns: 10_000,
    timeHorizonYears: 35,
    inflationRate: 0.03,
    useHistoricalBootstrap: true,
    initialPortfolioValue: 1_500_000,
    retirementAge: 60,
    incomeSchedule: [pension, socialSecurity],
    withdrawalConfig: WithdrawalConfiguration(
        strategy: .fixedPercentage,
        withdrawalRate: 0.04
    )
)
```

**Result:**
- Years 1-5 (ages 60-64): Full withdrawal from portfolio
- Years 6-10 (ages 65-69): Withdrawal offset by $24,000 pension (declining in real terms)
- Years 11+ (age 70+): Withdrawal offset by pension + $36,000 SS (constant in real terms)

### Example 3: Converting from DefinedBenefitPlans

```swift
@MainActor
class RetirementViewModel: ObservableObject {
    @Published var benefitManager = DefinedBenefitManager()
    
    func runSimulation(
        portfolio: Portfolio,
        retirementAge: Int
    ) async throws -> SimulationResult {
        
        // Convert defined benefit plans to income schedule
        let incomeSchedule = benefitManager.createIncomeSchedule()
        
        let params = SimulationParameters(
            numberOfRuns: 10_000,
            timeHorizonYears: 30,
            inflationRate: 0.025,
            useHistoricalBootstrap: true,
            initialPortfolioValue: portfolio.totalValue,
            retirementAge: retirementAge,
            incomeSchedule: incomeSchedule,  // Automatically time-aware
            withdrawalConfig: WithdrawalConfiguration(
                strategy: .fixedPercentage,
                withdrawalRate: 0.04
            )
        )
        
        let engine = MonteCarloEngine()
        let historicalData = try HistoricalData.load()
        
        return try await engine.runSimulation(
            portfolio: portfolio,
            parameters: params,
            historicalData: historicalData
        )
    }
}
```

## How It Works Internally

### Real Income Calculation

For each year of simulation, `ScheduledIncome.realIncome(at:inflationRate:yearsIntoRetirement:)` calculates:

1. **Check if active**: Is `currentAge >= startAge` and `currentAge <= endAge`?
2. **COLA income** (`inflationAdjusted = true`): Return `annualAmount` (constant purchasing power)
3. **Fixed nominal** (`inflationAdjusted = false`): Return `annualAmount / (1 + inflation)^(year - 1)`

### Integration with Monte Carlo

The engine calls `parameters.totalScheduledIncome(year:)` for each simulation year:

```swift
for year in 1...totalYears {
    let scheduledIncome = parameters.totalScheduledIncome(year: year)
    
    let withdrawal = withdrawalCalc.calculateWithdrawal(
        currentBalance: balance,
        year: year,
        baselineWithdrawal: baselineWithdrawal,
        initialBalance: parameters.initialPortfolioValue,
        config: parameters.withdrawalConfig,
        scheduledIncome: scheduledIncome  // Time-aware income
    )
    
    // ... rest of simulation logic
}
```

## Backward Compatibility

Legacy code using `fixedIncomeReal` and `fixedIncomeNominal` in `WithdrawalConfiguration` continues to work:

```swift
// Old approach (still supported)
var config = WithdrawalConfiguration(
    strategy: .fixedPercentage,
    withdrawalRate: 0.04
)
config.fixedIncomeReal = 30_000  // Treated as COLA
config.fixedIncomeNominal = 24_000  // Treated as fixed nominal

// New approach (recommended)
let params = SimulationParameters(
    // ... other params
    retirementAge: 65,
    incomeSchedule: [
        ScheduledIncome(name: "SS", annualAmount: 30_000, startAge: 67, inflationAdjusted: true),
        ScheduledIncome(name: "Pension", annualAmount: 24_000, startAge: 65, inflationAdjusted: false)
    ]
)
```

**Key difference:** The new approach properly handles income that starts **after** retirement begins, while the old approach assumes all income is available from day 1.

## Validation

The simulation now correctly models:
- ✅ Bridge strategies (early retirement before Social Security)
- ✅ Delayed Social Security claiming (ages 62-70)
- ✅ Multiple pension sources with different start ages
- ✅ Mixed COLA/non-COLA income streams
- ✅ Time-limited income (using `endAge`)
- ✅ Proper inflation erosion for nominal income sources

## Migration Checklist

When updating existing code:

1. ✅ Add `retirementAge` to `SimulationParameters`
2. ✅ Convert `DefinedBenefitPlan` arrays to `incomeSchedule` using `createIncomeSchedule()`
3. ✅ Remove manual `fixedIncome` calculations (now automatic)
4. ✅ Update UI to show income timeline (when each source starts)
5. ✅ Test edge cases (retirement before/after income starts)

## Testing Scenarios

### Scenario 1: Early Retirement (Age 55) with SS at 67

```swift
let params = SimulationParameters(
    timeHorizonYears: 35,  // Age 55 to 90
    retirementAge: 55,
    incomeSchedule: [
        ScheduledIncome(
            name: "Social Security",
            annualAmount: 30_000,
            startAge: 67,  // Starts in year 13
            inflationAdjusted: true
        )
    ],
    // ...
)
```

**Expected behavior:**
- Years 1-12: Portfolio covers full expenses
- Year 13+: Portfolio withdrawal reduced by $30,000/year

### Scenario 2: Pension Ending at Spousal Death

```swift
let spousePension = ScheduledIncome(
    name: "Spouse's Pension",
    annualAmount: 40_000,
    startAge: 65,
    endAge: 80,  // Ends at age 80
    inflationAdjusted: false
)
```

**Expected behavior:**
- Years 1-15: Pension offsets withdrawals (declining value)
- Year 16+: Pension stops, withdrawals increase

## Performance Notes

Time-based income calculation adds minimal overhead:
- **O(n × m)** where n = number of years, m = number of income sources
- Typical: 30 years × 2-3 income sources = 60-90 simple calculations per simulation run
- Negligible compared to return generation and withdrawal logic

## Conclusion

The time-aware income system provides accurate modeling of real retirement scenarios where income sources start at different ages. This is critical for:

- **Bridge strategies**: Retiring before Social Security eligibility
- **Delayed claiming**: Optimizing Social Security benefits
- **Multiple pensions**: Modeling complex income structures
- **Realistic projections**: Matching actual retirement timelines

Use `incomeSchedule` for new code and consider migrating legacy `fixedIncome` configurations for improved accuracy.
