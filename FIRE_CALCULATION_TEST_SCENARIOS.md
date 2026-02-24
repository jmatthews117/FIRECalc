# FIRE Calculation Test Scenarios

Use these test scenarios to verify that all FIRE calculations across the app are now aligned and producing consistent results.

## Test Scenario 1: Basic Case (No Inflation)

### Inputs
- Current Age: 35
- Current Savings: $100,000
- Annual Savings: $20,000
- Annual Expenses: $40,000
- Expected Return: 7%
- Withdrawal Rate: 4%
- Inflation Rate: 0%

### Expected Results (All Three Calculations)
- **FIRE Number**: $1,000,000 ($40,000 / 0.04)
- **Years to FIRE**: ~17 years
- **Retirement Age**: 52
- **Retirement Year**: 2043 (if current year is 2026)

### Where to Verify
1. **FIRE Calculator** (main tab): Press "Calculate FIRE Date"
2. **FIRE Timeline Card** (dashboard and top of FIRE Calculator): Check the projected timeline
3. **Sensitivity Analysis** (Tools tab): Check the baseline row in the table

All three should show **Age 52** and **17 years**.

---

## Test Scenario 2: With Inflation (More Realistic)

### Inputs
- Current Age: 30
- Current Savings: $50,000
- Annual Savings: $15,000
- Annual Expenses: $50,000
- Expected Return: 8%
- Withdrawal Rate: 4%
- Inflation Rate: 2.5%

### Expected Results (All Three Calculations)
- **FIRE Number**: $1,250,000 ($50,000 / 0.04)
- **Years to FIRE**: ~22-23 years (inflation increases contribution amount over time)
- **Retirement Age**: 52-53
- **Retirement Year**: 2048-2049 (if current year is 2026)

### Where to Verify
1. **FIRE Calculator**: Should show consistent age and year
2. **FIRE Timeline Card**: Should match the calculator's results
3. **Sensitivity Analysis**: Baseline should match

All three should show the **same retirement age** within the **same year**.

---

## Test Scenario 3: High Savings Rate (Quick FIRE)

### Inputs
- Current Age: 40
- Current Savings: $500,000
- Annual Savings: $80,000
- Annual Expenses: $40,000
- Expected Return: 7%
- Withdrawal Rate: 4%
- Inflation Rate: 2.5%

### Expected Results
- **FIRE Number**: $1,000,000
- **Years to FIRE**: ~5 years
- **Retirement Age**: 45
- **Retirement Year**: 2031 (if current year is 2026)

### Where to Verify
All three calculations should show **Age 45** and **5 years**.

---

## Test Scenario 4: Already at FIRE

### Inputs
- Current Age: 50
- Current Savings: $2,000,000
- Annual Savings: $0
- Annual Expenses: $60,000
- Expected Return: 7%
- Withdrawal Rate: 4%
- Inflation Rate: 2.5%

### Expected Results
- **FIRE Number**: $1,500,000 ($60,000 / 0.04)
- **Years to FIRE**: 0 (already achieved!)
- **Retirement Age**: 50 (current age)
- **Retirement Year**: 2026 (current year)

### Where to Verify
All three should show **Years: 0** or "Already funded!" or similar messaging.

---

## Test Scenario 5: Edge Case - Very Long Timeline

### Inputs
- Current Age: 25
- Current Savings: $10,000
- Annual Savings: $5,000
- Annual Expenses: $40,000
- Expected Return: 5%
- Withdrawal Rate: 4%
- Inflation Rate: 3%

### Expected Results
- **FIRE Number**: $1,000,000
- **Years to FIRE**: ~40+ years
- **Retirement Age**: 65+
- **Retirement Year**: 2066+

### Where to Verify
All three should show the **same retirement age** and be consistent about whether FIRE is achievable within 100 years.

---

## Verification Checklist

For each test scenario, verify:

- [ ] **Age Consistency**: The retirement age shown is the same across all three calculations
- [ ] **Year Consistency**: The retirement year matches the current year + years to FIRE
- [ ] **Age/Year Relationship**: retirement age = current age + years to FIRE
- [ ] **Display Alignment**: Text like "Age 52 in 17 years (2043)" should all align mathematically

## Common Issues to Watch For

### ❌ Off-by-One Errors
- Retirement age differs by 1 year between calculations
- Year display doesn't match age + years calculation
- Caused by: Incorrect inflation indexing or loop starting point

### ❌ Inflation Discrepancies
- Results differ when inflation > 0% but match when inflation = 0%
- Caused by: Missing inflation adjustment in one calculation

### ❌ Rounding Errors
- Small differences (< 1 year) between calculations
- Usually acceptable if within ±6 months
- Can be caused by: Display rounding vs. calculation precision

## Debugging Tips

If you find discrepancies:

1. **Set Inflation to 0%**: This simplifies the math and helps isolate issues
2. **Use Simple Numbers**: Round numbers make it easier to verify manually
3. **Check Console Logs**: Add debug prints to see intermediate values
4. **Compare Year-by-Year**: Look at the yearly projections in detail

## Manual Calculation Example

For Scenario 1 (no inflation), you can verify manually:

```
Year 0: $100,000
Year 1: $100,000 × 1.07 + $20,000 = $127,000
Year 2: $127,000 × 1.07 + $20,000 = $155,890
Year 3: $155,890 × 1.07 + $20,000 = $186,802
...
Continue until balance ≥ $1,000,000
```

This should reach ~$1,000,000 after 17 years, making retirement age 52.
