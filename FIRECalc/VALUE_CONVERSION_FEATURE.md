# Value-Based Ticker Conversion Feature

## Overview

This enhancement allows users to seamlessly convert their mutual fund or cryptocurrency holdings into equivalent ETF positions by entering their total portfolio value. The system automatically calculates the correct number of ETF shares.

## User Flow

### Example: Converting VTSAX to VTI

1. **User tries to add VTSAX**
   - Opens AddAssetView
   - Selects "Stocks" asset type
   - Enters "VTSAX" as ticker
   - Clicks "Load Price"

2. **System detects unsupported ticker**
   - TickerMappingService identifies VTSAX as mutual fund
   - Throws `MarketstackError.unsupportedMutualFund`
   - Shows suggestion card

3. **Card automatically loads ETF price**
   - Fetches current VTI price (e.g., $250.00)
   - Displays price in card

4. **User enters their VTSAX value**
   - Types "$50,000" in the value field
   - System calculates: $50,000 ÷ $250.00 = 200 shares

5. **User clicks "Add as VTI"**
   - Asset created with:
     - Name: "VTI"
     - Ticker: "VTI"
     - Quantity: 200 shares
     - Unit Price: $250.00
     - Total Value: $50,000

6. **Asset appears in portfolio**
   - Shows as VTI with live price tracking
   - User maintains exact same value
   - Just different representation (shares vs. fund value)

## Visual Layout

```
┌─────────────────────────────────────────────────────┐
│ ⚠️ Unsupported Ticker                               │
│ VTSAX cannot be tracked with live prices            │
├─────────────────────────────────────────────────────┤
│ We'll track it using this equivalent ETF:           │
│                                                      │
│ VTI                                    $250.00       │
│ Vanguard Total Stock Market ETF        per share    │
│                                                      │
│ ℹ️ Nearly identical holdings and performance        │
├─────────────────────────────────────────────────────┤
│ What's your total VTSAX value?                      │
│ $ [  50,000  ]                                       │
│                                                      │
│ ➡️ Converts to:                                      │
│   200.0000 shares                                    │
│   of VTI @ $250.00                                   │
├─────────────────────────────────────────────────────┤
│ Cancel              [✓ Add as VTI]                   │
└─────────────────────────────────────────────────────┘
```

## Technical Implementation

### TickerMappingSuggestionCard.swift

**New Features:**
- Value input field with dollar formatting
- Automatic ETF price loading on appear
- Real-time share calculation
- Progress indicator during price fetch
- Error handling with retry button
- Disabled "Add" button until ready

**Key State Variables:**
```swift
@State private var holdingsValue: String = ""      // User's input
@State private var isLoadingPrice: Bool = false    // Loading state
@State private var etfPrice: Double?               // Fetched ETF price
@State private var priceError: String?             // Error message
@FocusState private var isValueFieldFocused: Bool  // Keyboard control
```

**Calculation Logic:**
```swift
private var calculatedShares: Double? {
    guard let value = Double(holdingsValue.replacingOccurrences(of: ",", with: "")),
          let price = etfPrice,
          value > 0,
          price > 0 else {
        return nil
    }
    return value / price
}
```

**Callback Signature:**
```swift
let onUseAlternative: (Double, Double) -> Void  // (quantity, unitPrice)
```

### AddAssetView Integration

**Updated Callback:**
```swift
onUseAlternative: { quantity, unitPrice in
    // Update all relevant fields
    ticker = mapping.etfAlternative          // e.g., "VTI"
    self.quantity = String(format: "%.4f", quantity)  // e.g., "200.0000"
    unitValue = String(format: "%.2f", unitPrice)     // e.g., "250.00"
    assetName = mapping.etfAlternative       // Display name
    autoLoadedPrice = unitPrice              // Mark price as loaded
    
    // Clear suggestion UI
    tickerMappingSuggestion = nil
    showMappingSuggestion = false
}
```

## Use Cases

### Mutual Fund Conversion

**Scenario:** User has $100,000 in VTSAX

1. Enter "VTSAX" → See VTI suggestion
2. Enter "$100,000" → System calculates shares
3. VTI price: $250.00
4. Calculated shares: 400
5. Asset added: 400 shares of VTI @ $250.00 = $100,000 ✓

**Benefits:**
- Maintains exact portfolio value
- Gets live price tracking
- Can see daily gains/losses
- Portfolio auto-updates with market

### Cryptocurrency Conversion

**Scenario:** User has $10,000 in Bitcoin

1. Enter "BTC" → See IBIT suggestion
2. Enter "$10,000" → System calculates shares
3. IBIT price: $35.00
4. Calculated shares: 285.7143
5. Asset added: 285.7143 shares of IBIT @ $35.00 = $10,000 ✓

**Benefits:**
- Tracks Bitcoin exposure via regulated ETF
- Gets live price updates
- More stable than direct crypto
- App Store compliant

### Large Portfolio Conversion

**Scenario:** User has multiple mutual funds

1. Convert VTSAX ($50,000) → VTI (200 shares)
2. Convert VFIAX ($30,000) → VOO (100 shares)
3. Convert VBTLX ($20,000) → BND (250 shares)

**Result:** Entire portfolio now trackable with live prices

## Edge Cases Handled

### 1. Price Fetch Failure
```swift
if priceError != nil {
    // Show retry button
    Button("Retry") {
        loadETFPrice()
    }
}
```

### 2. Invalid Value Input
```swift
// Calculation returns nil if value is 0 or negative
guard value > 0, price > 0 else { return nil }

// "Add" button disabled when calculation is nil
.disabled(!isReadyToConvert)
```

### 3. Loading State
```swift
if isLoadingPrice {
    ProgressView()  // Show spinner
        .scaleEffect(0.8)
}
```

### 4. Empty Value Field
```swift
// Add button remains disabled until user enters value
private var isReadyToConvert: Bool {
    calculatedShares != nil  // nil if field empty
}
```

## Number Formatting

### Share Quantity
```swift
String(format: "%.4f", quantity)
// Examples:
// 200.0000 shares
// 285.7143 shares
// 0.0050 shares (for expensive assets)
```

### Price Display
```swift
price.toPreciseCurrency()
// Examples:
// $250.00
// $35.42
// $1,234.56
```

### Value Input
```swift
holdingsValue.replacingOccurrences(of: ",", with: "")
// Accepts:
// "50000"
// "50,000"
// "50000.00"
// All convert to same Double
```

## Testing Checklist

### Test Case 1: Basic Conversion
- [ ] Enter VTSAX
- [ ] See VTI suggestion
- [ ] ETF price loads automatically
- [ ] Enter $50,000
- [ ] See calculated shares
- [ ] Click "Add as VTI"
- [ ] Asset appears with correct values

### Test Case 2: Crypto Conversion
- [ ] Select Crypto asset class
- [ ] Enter BTC
- [ ] See IBIT suggestion
- [ ] ETF price loads
- [ ] Enter $10,000
- [ ] Shares calculated correctly
- [ ] Asset added successfully

### Test Case 3: Price Load Failure
- [ ] Simulate network error
- [ ] See error message
- [ ] Click "Retry"
- [ ] Price loads on retry
- [ ] Can proceed with conversion

### Test Case 4: Invalid Input
- [ ] Leave value field empty
- [ ] "Add" button is disabled
- [ ] Enter "0"
- [ ] "Add" button still disabled
- [ ] Enter "-100"
- [ ] "Add" button still disabled
- [ ] Enter "50000"
- [ ] "Add" button becomes enabled

### Test Case 5: Decimal Values
- [ ] Enter $50,123.45
- [ ] Shares calculated with decimals
- [ ] Asset added with correct precision
- [ ] Total value matches input

### Test Case 6: Small Values
- [ ] Enter $100
- [ ] Works correctly
- [ ] Enter $10
- [ ] Fractional shares calculated
- [ ] Enter $1
- [ ] Still works

### Test Case 7: Large Values
- [ ] Enter $1,000,000
- [ ] Calculation works
- [ ] No number overflow
- [ ] Display formats correctly

### Test Case 8: Multiple Conversions
- [ ] Convert VTSAX → VTI
- [ ] Dismiss card
- [ ] Convert FXAIX → VOO
- [ ] Both work independently
- [ ] No state leakage

## User Experience Improvements

### Before (Original Design)
```
User: "I have VTSAX"
App: "Use VTI instead"
User: "How many shares?"
User: *Opens calculator app*
User: *Manually divides value by price*
User: *Comes back and enters shares*
```

### After (Value Conversion)
```
User: "I have VTSAX"
App: "Use VTI instead. What's your VTSAX value?"
User: "$50,000"
App: "That's 200 shares of VTI"
User: *Clicks "Add as VTI"*
Done! ✓
```

**Time saved:** ~2 minutes per conversion  
**Friction reduced:** No manual calculation needed  
**Error reduction:** No typing mistakes in share calculation

## Implementation Notes

### Why Auto-Load Price?

```swift
.onAppear {
    loadETFPrice()  // Automatic
}
```

**Reasons:**
1. User expects to see price immediately
2. Reduces steps (no "Get Price" click needed first)
3. Price needed for calculation anyway
4. Better UX (fewer clicks)

**Trade-off:** Uses one API call immediately, but worth it for UX

### Why Format to 4 Decimal Places?

```swift
String(format: "%.4f", quantity)
```

**Reasons:**
1. Some assets very expensive (fractional shares common)
2. Precision important for portfolio tracking
3. 4 decimals is brokerage industry standard
4. Avoids rounding errors in total value

**Example:** $10,000 in TSLA at $250.00 = 40.0000 shares (not 40)

### Why Separate Value Input?

**Alternative approach:** Let user directly edit quantity field

**Why we don't do this:**
- User thinks in dollar values for mutual funds
- Mentally easier to say "I have $50,000 in VTSAX"
- Than to say "I have ??? shares of VTSAX"
- Mutual funds often don't show share counts on statements

**Better UX:** Ask for what user knows (dollar value), calculate what they need (shares)

## Future Enhancements

### 1. Historical Cost Basis
```swift
// Add optional purchase date and original value
let originalValue: Double?
let purchaseDate: Date?

// Calculate gain/loss
let currentValue = quantity * unitPrice
let gain = currentValue - (originalValue ?? 0)
```

### 2. Multiple Funds → One ETF
```swift
// User has VTSAX ($30k) and FSKAX ($20k)
// Both convert to VTI
// Combine: $50k total = 200 shares VTI
```

### 3. Smart Rounding
```swift
// Option to round to whole shares
let roundedShares = round(calculatedShares)
// 285.7143 → 286 shares
```

### 4. Expense Ratio Comparison
```swift
// Show savings from ETF vs. mutual fund
let mutualFundER = 0.0015  // VTSAX: 0.15%
let etfER = 0.0003         // VTI: 0.03%
let annualSavings = value * (mutualFundER - etfER)
// "$50,000 saves $60/year in fees"
```

### 5. Tax Implications Note
```swift
// Warn if converting could trigger taxes
"Note: This converts your holding to an ETF for tracking purposes. If you're actually selling VTSAX to buy VTI, consult a tax advisor about capital gains."
```

## Conclusion

This value-based conversion feature transforms an educational suggestion into a practical tool. Users can instantly convert their mutual fund and crypto holdings into trackable ETF positions without manual calculation, significantly improving the user experience and reducing errors.

**Key Benefits:**
- ✅ Zero manual calculation required
- ✅ Maintains exact portfolio value
- ✅ Automatic price fetching
- ✅ Real-time share calculation
- ✅ One-click conversion
- ✅ Handles edge cases gracefully
- ✅ Professional number formatting
- ✅ Clear visual feedback

**Result:** A feature that feels magical to use! 🎉
