# Ticker Mapping Button Debugging Guide

## Problem Statement

Both buttons are disabled when using the ticker mapping feature:
1. The blue "Add as [TICKER]" button in the mapping suggestion card
2. The gray "Add" button at the top right of the Add Asset view

## Debug Logging Added

### In TickerMappingSuggestionCard.swift

#### Card Appearance
```swift
.onAppear {
    print("🔔 TickerMappingSuggestionCard appeared for \(originalTicker) → \(mapping.etfAlternative)")
    loadETFPrice()
}
```

#### Price Loading
```swift
private func loadETFPrice() {
    print("🔄 loadETFPrice called for \(mapping.etfAlternative)")
    // ... fetch price ...
    print("✅ Loaded ETF price: \(mapping.etfAlternative) = $\(price)")
    // OR
    print("❌ Failed to load ETF price: \(error.localizedDescription)")
}
```

#### Holdings Value Changes
```swift
TextField("10,000", text: $holdingsValue)
    .onChange(of: holdingsValue) { oldValue, newValue in
        print("💰 holdingsValue changed: '\(oldValue)' → '\(newValue)'")
    }
```

#### Share Calculation
```swift
private var calculatedShares: Double? {
    guard ... else {
        print("❌ calculatedShares = nil: holdingsValue='\(holdingsValue)', etfPrice=\(String(describing: etfPrice))")
        return nil
    }
    let shares = value / price
    print("✅ calculatedShares = \(shares): value=\(value), price=\(price)")
    return shares
}
```

#### Button Validation
```swift
private var isReadyToConvert: Bool {
    let ready = calculatedShares != nil
    print("🔘 isReadyToConvert = \(ready)")
    return ready
}
```

### In add_asset_view.swift

#### Mapping Acceptance
```swift
onUseAlternative: { displayName, lookupTicker, quantity, unitPrice in
    print("✅ Mapping accepted:")
    print("   - Display name: \(displayName)")
    print("   - Lookup ticker: \(lookupTicker)")
    print("   - Quantity: \(self.quantity)")
    print("   - Unit value: \(unitValue)")
    print("   - Auto loaded price: \(String(describing: autoLoadedPrice))")
    print("   - Total value: \(String(describing: totalValue))")
    print("   - Is valid: \(isValid)")
}
```

## Expected Console Output

### Successful Flow

```
🔔 TickerMappingSuggestionCard appeared for FXAIX → VOO
🔄 loadETFPrice called for VOO
📡 Fetching price for VOO...
✅ Loaded ETF price: VOO = $465.23
💰 holdingsValue changed: '' → '1'
❌ calculatedShares = nil: holdingsValue='1', etfPrice=Optional(465.23)
🔘 isReadyToConvert = false
💰 holdingsValue changed: '1' → '10'
❌ calculatedShares = nil: holdingsValue='10', etfPrice=Optional(465.23)
🔘 isReadyToConvert = false
💰 holdingsValue changed: '10' → '100'
❌ calculatedShares = nil: holdingsValue='100', etfPrice=Optional(465.23)
🔘 isReadyToConvert = false
💰 holdingsValue changed: '100' → '1000'
❌ calculatedShares = nil: holdingsValue='1000', etfPrice=Optional(465.23)
🔘 isReadyToConvert = false
💰 holdingsValue changed: '1000' → '10000'
✅ calculatedShares = 21.4876: value=10000.0, price=465.23
🔘 isReadyToConvert = true
[Blue button "Add as FXAIX" should now be ENABLED]

[User clicks "Add as FXAIX"]
✅ Mapping accepted:
   - Display name: FXAIX
   - Lookup ticker: VOO
   - Quantity: 21.4876
   - Unit value: 465.23
   - Auto loaded price: Optional(465.23)
   - Total value: Optional(9999.89)
   - Is valid: true
[Gray "Add" button at top right should now be ENABLED]
```

### Failed Price Load

```
🔔 TickerMappingSuggestionCard appeared for FXAIX → VOO
🔄 loadETFPrice called for VOO
📡 Fetching price for VOO...
❌ Failed to load ETF price: [error message]
[User sees "Retry" button instead of price]
[Value input field NOT shown]
[Blue button remains disabled]
```

### Subscription Issue

```
🔔 TickerMappingSuggestionCard appeared for FXAIX → VOO
🔄 loadETFPrice called for VOO
📡 Fetching price for VOO...
🚫 Free tier - stock quotes disabled
❌ Failed to load ETF price: [subscription error]
```

## Troubleshooting Steps

### 1. Check if Card Appears
**Look for**: `🔔 TickerMappingSuggestionCard appeared`

**If NOT appearing**:
- Check if ticker is in TickerMappings.json
- Verify early validation is triggering
- Check if `showMappingSuggestion` is being set to true

### 2. Check if Price Loads
**Look for**: `✅ Loaded ETF price`

**If NOT loading**:
- Check for `🚫 Free tier` message → User needs Pro subscription
- Check for network errors
- Check if `bypassCooldown: true` is being passed
- Verify AlternativePriceService is working

### 3. Check if User Enters Value
**Look for**: `💰 holdingsValue changed` messages

**If NOT changing**:
- TextField might not be focused
- Keyboard might not be appearing
- User might not be typing

### 4. Check Share Calculation
**Look for**: `✅ calculatedShares = [number]`

**If shows ❌**:
- `holdingsValue` might be empty or invalid
- `etfPrice` might be nil (price didn't load)
- Value might be 0 or negative

### 5. Check Button State
**Look for**: `🔘 isReadyToConvert = true`

**If false**:
- Share calculation failed (see step 4)

### 6. Check Mapping Acceptance
**Look for**: `✅ Mapping accepted`

**If validation fails after acceptance**:
- Check if `onChange(of: ticker)` is resetting values
- Verify `isApplyingMapping` flag is working
- Check if `totalValue` is being calculated correctly

## Common Issues

### Issue 1: Price Doesn't Load

**Symptoms**:
- Card appears but shows "Get Price" button
- No `✅ Loaded ETF price` message

**Possible Causes**:
1. User is not a Pro subscriber
2. Network error
3. API cooldown active (shouldn't happen with `bypassCooldown: true`)
4. Marketstack backend is down

**Solutions**:
- Verify user has active Pro subscription
- Check network connectivity
- Verify backend server is running
- Check if cached price is available

### Issue 2: Button Stays Disabled After Entering Value

**Symptoms**:
- Price loaded successfully
- User entered value (see `💰 holdingsValue changed`)
- Share calculation shows nil

**Possible Causes**:
1. String parsing issue (locale/formatting)
2. Value is 0 or negative
3. etfPrice suddenly became nil

**Solutions**:
- Check exact holdingsValue string format
- Try different values (1000, 10000, etc.)
- Verify etfPrice remains set after initial load

### Issue 3: Add Button Disabled After Accepting Mapping

**Symptoms**:
- Blue button works and callback runs
- `✅ Mapping accepted` appears
- But `Is valid: false`

**Possible Causes**:
1. `onChange(of: ticker)` reset the values
2. `isApplyingMapping` flag not working
3. String formatting issue with quantity/unitValue

**Solutions**:
- Verify `isApplyingMapping` flag is set to true
- Check if onChange is bypassed during mapping
- Verify quantity and unitValue are valid number strings

### Issue 4: Validation Logic Error

**Symptoms**:
- All values seem correct in logs
- But `totalValue` is nil or 0

**Possible Causes**:
1. Double parsing fails
2. Quantity string has unexpected format
3. unitValue string has unexpected format

**Solutions**:
- Add more specific logging to `totalValue` computed property
- Test with hardcoded values
- Check locale settings (decimal separator)

## Testing Commands

### Test Price Loading
```swift
// In TickerMappingSuggestionCard
print("🧪 Testing price load...")
print("   - mapping.etfAlternative: \(mapping.etfAlternative)")
print("   - assetClass: \(assetClass)")
print("   - isLoadingPrice: \(isLoadingPrice)")
print("   - etfPrice: \(String(describing: etfPrice))")
print("   - priceError: \(String(describing: priceError))")
```

### Test Validation
```swift
// In AddAssetView
print("🧪 Testing validation...")
print("   - ticker: '\(ticker)'")
print("   - assetName: '\(assetName)'")
print("   - quantity: '\(quantity)'")
print("   - unitValue: '\(unitValue)'")
print("   - autoLoadedPrice: \(String(describing: autoLoadedPrice))")
print("   - needsQuantityAndPrice: \(needsQuantityAndPrice)")
print("   - totalValue: \(String(describing: totalValue))")
print("   - isValid: \(isValid)")
```

## Next Steps

1. **Run the app with debug logging enabled**
2. **Try to add FXAIX**
3. **Copy the complete console output**
4. **Identify where the flow breaks**
5. **Report findings with specific log messages**

The debug output will tell us exactly where the issue is occurring.

---

**Created**: March 13, 2026
**Purpose**: Debug why ticker mapping buttons are disabled
**Related Files**:
- `TickerMappingSuggestionCard.swift`
- `add_asset_view.swift`
- `alternative_price_service.swift`
- `MarketstackService.swift`
