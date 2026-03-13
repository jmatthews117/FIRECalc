# Ticker Name Customization Feature

## Overview
Enhanced the ticker mapping suggestion card to allow users to **display their assets using the original mutual fund ticker (e.g., FXAIX)** while using the ETF alternative (e.g., VOO) for price lookups behind the scenes.

## User Experience

### Example: Adding FXAIX (Fidelity 500 Index Fund)

1. **User enters**: `FXAIX`
2. **System detects**: Mutual fund (unsupported for live prices)
3. **Suggestion card shows**:
   - Warning that FXAIX cannot be tracked with live prices
   - Suggests using VOO (Vanguard S&P 500 ETF) as equivalent
   - Auto-loads VOO price
   - User enters their FXAIX holdings value (e.g., $10,000)
   - System calculates equivalent VOO shares (e.g., 21.5432 shares @ $465.00)

4. **NEW: Display Name Toggle**:
   ```
   ☑ Keep original ticker name (FXAIX)
   
   ℹ Asset will show as FXAIX, but prices will be tracked using VOO
   ```

5. **User clicks**: "Add as FXAIX" (button text updates based on toggle)

6. **Result**: 
   - Asset name in portfolio: **FXAIX**
   - Ticker used for price lookups: **VOO**
   - User sees their familiar ticker but gets accurate pricing

## Technical Implementation

### 1. Updated TickerMappingSuggestionCard

**New State Variable**:
```swift
@State private var keepOriginalName: Bool = true
```

**Updated Callback Signature**:
```swift
let onUseAlternative: (String, String, Double, Double) -> Void
// Parameters: (displayName, lookupTicker, quantity, unitPrice)
```

**New UI Elements**:
- Toggle switch to choose between original ticker or ETF ticker
- Dynamic info text explaining what will happen
- Button text that updates based on user choice

### 2. Updated AddAssetView

**Modified Callback Handler**:
```swift
onUseAlternative: { displayName, lookupTicker, quantity, unitPrice in
    assetName = displayName      // User's chosen display name (FXAIX or VOO)
    ticker = lookupTicker         // Always the ETF ticker (VOO)
    self.quantity = String(format: "%.4f", quantity)
    unitValue = String(format: "%.2f", unitPrice)
    autoLoadedPrice = unitPrice
    
    // Clear suggestion state
    tickerMappingSuggestion = nil
    showMappingSuggestion = false
}
```

## Benefits

### For Users
1. **Familiar Names**: Portfolio shows the tickers they actually own (FXAIX)
2. **Accurate Pricing**: System uses liquid ETF prices (VOO) for updates
3. **Clear Communication**: Toggle makes it obvious what's happening
4. **Flexibility**: Can choose to use ETF name if they prefer

### For the System
1. **Better Data Quality**: Uses liquid ETF prices instead of mutual fund NAVs
2. **API Efficiency**: No wasted calls on unsupported tickers
3. **Clear Separation**: Display name vs. lookup ticker are distinct
4. **Backwards Compatible**: Users who prefer ETF names can still use them

## Data Flow

```
User Input: FXAIX
    ↓
Mapping Check: Detected as mutual fund
    ↓
Suggestion: Use VOO for pricing
    ↓
User Choice: Keep FXAIX name ☑
    ↓
Asset Creation:
    - name: "FXAIX"        (displayed in portfolio)
    - ticker: "VOO"        (used for price lookups)
    - quantity: 21.5432
    - unitValue: $465.00
    ↓
Price Updates: System fetches VOO prices
    ↓
UI Display: Shows "FXAIX • $10,032.59"
```

## UI Flow

### When Toggle is ON (Keep Original Name)
```
☑ Keep original ticker name (FXAIX)

ℹ Asset will show as FXAIX, but prices will be tracked using VOO

[Add as FXAIX]
```

### When Toggle is OFF
```
☐ Keep original ticker name (FXAIX)

ℹ Asset will show as VOO

[Add as VOO]
```

## Example Use Cases

### Case 1: 401(k) Mutual Fund Tracking
**Scenario**: User has VTSAX in their 401(k)
- **Enters**: VTSAX
- **Chooses**: Keep original name ☑
- **Result**: Portfolio shows "VTSAX" but tracks using VTI prices
- **Why**: Matches their 401(k) statements exactly

### Case 2: Crypto Alternative
**Scenario**: User wants to track Bitcoin exposure
- **Enters**: BTC
- **Chooses**: Keep original name ☑
- **Result**: Portfolio shows "BTC" but tracks using IBIT (Bitcoin ETF)
- **Why**: More intuitive to see "BTC" than "IBIT"

### Case 3: Professional Investor
**Scenario**: User wants standardized ETF names
- **Enters**: FXAIX
- **Chooses**: Use ETF name ☐
- **Result**: Portfolio shows "VOO" 
- **Why**: Prefers liquid, tradable tickers

## Testing Scenarios

### Test 1: FXAIX → VOO
1. Enter "FXAIX" as ticker
2. Click "Load Price"
3. Should immediately show suggestion (no API delay)
4. Toggle should default to ON (Keep original name)
5. Enter value: $10,000
6. Should show converted shares of VOO
7. Button should say "Add as FXAIX"
8. Asset should show as FXAIX in portfolio

### Test 2: Toggle OFF
1. Enter "VTSAX" as ticker
2. Get suggestion for VTI
3. Toggle OFF "Keep original name"
4. Button should say "Add as VTI"
5. Asset should show as VTI in portfolio

### Test 3: Crypto Mapping
1. Enter "BTC" as ticker
2. Get suggestion for IBIT
3. Keep toggle ON
4. Asset shows as "BTC" but uses IBIT prices
5. Verify price updates work correctly

### Test 4: No Mapping Needed
1. Enter "AAPL" as ticker
2. Should NOT show suggestion card
3. Should proceed normally to price fetch

## Future Enhancements

### Potential Additions
1. **Display Mapping in Portfolio**: Show "(tracked via VOO)" under FXAIX
2. **Bulk Import Support**: Apply naming preference to CSV imports
3. **Settings Preference**: Remember user's default choice (always keep original vs. always use ETF)
4. **Multiple Mapping Options**: Allow user to choose between multiple ETF alternatives
5. **Historical Context**: Show performance comparison between mutual fund and ETF

### UI Improvements
1. **Inline Edit**: Allow changing display name after asset is added
2. **Batch Rename**: Change multiple assets from FXAIX → VOO at once
3. **Smart Suggestions**: "Most users keep the original name" hint
4. **Visual Indicator**: Badge or icon showing asset uses mapped pricing

## Related Files

- `TickerMappingSuggestionCard.swift` - Main suggestion card UI
- `add_asset_view.swift` - Asset creation flow
- `TickerMappingService.swift` - Mapping detection logic
- `MarketstackService.swift` - Price fetching with mapping support
- `TickerMappings (2).json` - Mapping data (1000+ mutual funds + crypto)

## Related Documentation

- `TICKER_MAPPING_EARLY_VALIDATION.md` - How early validation prevents API waste
- `TICKER_MAPPING_SYSTEM.md` - Overall system architecture
- `ENHANCED_TICKER_MAPPING_SUMMARY.md` - Complete mapping reference

---

**Last Updated**: March 12, 2026
**Feature Status**: ✅ Implemented
**User Impact**: High - Improves portfolio clarity and user control
