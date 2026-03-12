# Ticker Mapping System - Mutual Funds & Crypto ETF Suggestions

## Overview

This feature intercepts ticker lookups for mutual funds and cryptocurrencies that cannot be tracked via Marketstack API and suggests equivalent ETF alternatives. This prevents wasted API calls and provides users with helpful alternatives.

## Components

### 1. TickerMappings.json
**Location:** `/repo/TickerMappings.json`

A JSON file containing mappings for:
- **18 popular mutual funds** (Vanguard, Fidelity, Schwab index funds)
- **11 cryptocurrencies** (BTC, ETH, and other major coins)

Each mapping includes:
```json
{
  "TICKER": {
    "name": "Full Asset Name",
    "etfAlternative": "ETF_TICKER",
    "etfName": "ETF Full Name",
    "reason": "Why this ETF is a good alternative"
  }
}
```

**Example mappings:**
- `VTSAX` → `VTI` (Vanguard Total Stock Market ETF)
- `BTC` → `IBIT` (iShares Bitcoin Trust)
- `FXAIX` → `VOO` (Vanguard S&P 500 ETF)

**To add more mappings:** Simply edit this JSON file and add new entries under `mutualFunds` or `crypto` sections.

### 2. TickerMappingService.swift
**Location:** `/repo/TickerMappingService.swift`

An actor-based service that:
- Loads mappings from JSON on initialization
- Provides `checkTicker()` to determine if a ticker is supported
- Returns mapping suggestions with detailed explanations
- Thread-safe with Swift concurrency

**Key API:**
```swift
let result = await TickerMappingService.shared.checkTicker("VTSAX")
// Returns: .unsupportedMutualFund(original: "VTSAX", mapping: ...)
```

### 3. Enhanced MarketstackError
**Location:** `/repo/MarketstackTestService.swift`

Added two new error cases:
```swift
case .unsupportedMutualFund(original: String, mapping: TickerMapping)
case .unsupportedCrypto(original: String, mapping: TickerMapping)
```

These errors carry the mapping information so the UI can display suggestions.

### 4. MarketstackService Integration
**Location:** `/repo/MarketstackService.swift`

Both `fetchQuote()` and `fetchCryptoQuote()` now:
1. Check ticker against mapping service before making API calls
2. Throw appropriate error if ticker is unsupported
3. Prevent unnecessary API calls for mutual funds/crypto

**Example flow:**
```
User enters "VTSAX" → Service checks mapping → Throws unsupportedMutualFund error
→ No API call made → User sees suggestion to use VTI instead
```

### 5. AddAssetView UI Enhancement
**Location:** `/repo/add_asset_view.swift`

Added beautiful suggestion card that displays when unsupported ticker is detected:

**Features:**
- Orange-themed warning card
- Shows original ticker and why it's unsupported
- Displays ETF alternative with full name
- "Use This" button to automatically switch to suggested ETF
- Explanation of why the ETF is equivalent
- Dismiss button to close suggestion

**Example UI:**
```
⚠️ Unsupported Ticker
VTSAX cannot be tracked with live prices.

Consider using instead:
VTI
Vanguard Total Stock Market ETF
[Use This]

Why? Nearly identical holdings and performance

[Dismiss]
```

## How It Works

### User Journey

1. **User enters mutual fund ticker (e.g., "VTSAX")**
   - Types in AddAssetView
   - Clicks "Load Price"

2. **System intercepts before API call**
   - TickerMappingService checks if "VTSAX" is in mappings
   - Finds it's a mutual fund
   - Returns mapping to VTI

3. **MarketstackService throws error**
   - `throw MarketstackError.unsupportedMutualFund(original: "VTSAX", mapping: ...)`
   - No API call is made (saves quota)

4. **UI displays suggestion**
   - Shows warning card with VTI suggestion
   - User clicks "Use This"
   - Ticker field updates to "VTI"
   - Automatically triggers new price load

5. **VTI price loads successfully**
   - Normal API flow proceeds
   - Live price displayed
   - User can add asset

### Code Flow

```
AddAssetView.loadPrice()
  ↓
AlternativePriceService.fetchPrice()
  ↓
MarketstackService.fetchQuote()
  ↓
TickerMappingService.checkTicker() → .unsupportedMutualFund
  ↓
throw MarketstackError.unsupportedMutualFund(...)
  ↓
AddAssetView catches error
  ↓
Sets tickerMappingSuggestion & showMappingSuggestion
  ↓
UI displays suggestion card
```

## Benefits

### 1. Prevents Wasted API Calls
- Mutual funds don't have live prices via Marketstack
- Crypto often not supported on stock APIs
- Catching these BEFORE API call saves quota

### 2. Better User Experience
- Clear explanation of why ticker isn't supported
- Helpful suggestion with reasoning
- One-click to switch to alternative
- Educational (teaches users about ETF equivalents)

### 3. Easy to Extend
- Just add entries to JSON file
- No code changes needed
- Can add new asset types if needed

### 4. Thread-Safe
- Uses Swift actors
- Safe concurrent access
- Async/await for modern Swift

## Testing

### Test Cases

1. **Mutual Fund Detection**
   ```swift
   // Enter "VTSAX" in AddAssetView
   // Expected: Suggestion card shows VTI alternative
   ```

2. **Crypto Detection**
   ```swift
   // Enter "BTC" in AddAssetView with Crypto asset class
   // Expected: Suggestion card shows IBIT alternative
   ```

3. **Regular Stock (No Mapping)**
   ```swift
   // Enter "AAPL" in AddAssetView
   // Expected: Normal price fetch, no suggestion
   ```

4. **Use Suggested Alternative**
   ```swift
   // Enter "FXAIX", see suggestion, click "Use This"
   // Expected: Ticker changes to "VOO", price loads
   ```

### Manual Testing Steps

1. Open AddAssetView
2. Select "Stocks" asset type
3. Enter "VTSAX" in ticker field
4. Click "Load Price for VTSAX"
5. Verify suggestion card appears with VTI
6. Click "Use This"
7. Verify ticker changes to VTI
8. Verify price loads successfully

## Extending the System

### Adding New Mutual Fund Mappings

Edit `TickerMappings.json`:

```json
{
  "mutualFunds": {
    "NEWFUND": {
      "name": "New Fund Name",
      "etfAlternative": "NEWETF",
      "etfName": "New ETF Name",
      "reason": "Why this is equivalent"
    }
  }
}
```

### Adding New Crypto Mappings

```json
{
  "crypto": {
    "NEWCOIN": {
      "name": "New Coin Name",
      "etfAlternative": "ETFTICKER",
      "etfName": "Crypto ETF Name",
      "reason": "Provides similar exposure"
    }
  }
}
```

### Supporting Other Asset Types

To add support for other unsupported types (e.g., commodities):

1. Add new section to JSON:
   ```json
   {
     "commodities": { ... }
   }
   ```

2. Update `TickerMappings` struct:
   ```swift
   struct TickerMappings: Codable {
       let mutualFunds: [String: TickerMapping]
       let crypto: [String: TickerMapping]
       let commodities: [String: TickerMapping] // New
   }
   ```

3. Update `checkTicker()` to check new category

4. Add new error case if needed

## Current Mappings

### Mutual Funds (18)

**Vanguard:**
- VTSAX → VTI (Total Stock Market)
- VFIAX → VOO (S&P 500)
- VTIAX → VXUS (International)
- VBTLX → BND (Total Bond)
- VGSLX → VNQ (Real Estate)
- VEXAX → VXF (Extended Market)
- VMFXX → BIL (Money Market)
- VWINX, VWELX → Balanced alternatives

**Fidelity:**
- FXAIX → VOO (S&P 500)
- FSKAX → VTI (Total Market)
- FTIHX → VXUS (International)
- FXNAX → BND (Bonds)

**Schwab:**
- SWPPX → SCHX (Large Cap)
- SWTSX → SCHB (Total Market)
- SWISX → SCHF (International)
- SWAGX → SCHZ (Bonds)

### Cryptocurrencies (11)

- BTC → IBIT (iShares Bitcoin Trust)
- ETH → ETHA (iShares Ethereum Trust)
- USDT, USDC → BIL (T-Bill ETF for stablecoins)
- SOL → ARKK (Innovation ETF)
- ADA, XRP, DOGE, DOT, MATIC, LTC → BITQ (Crypto Industry ETF)

## Performance Considerations

- JSON loaded once on service initialization
- Lookups are O(1) dictionary access
- No performance impact on normal stock tickers
- Prevents expensive API calls for unsupported types

## Future Enhancements

1. **Remote JSON hosting** - Fetch mappings from server to update without app release
2. **User contributions** - Allow users to suggest new mappings
3. **Analytics** - Track which tickers users try to add most
4. **Smart suggestions** - Use fuzzy matching for similar tickers
5. **Historical context** - Show performance comparison charts

## Notes

- This system is purely advisory - users can still manually enter any ticker as a custom label
- Mappings are educational suggestions, not financial advice
- Keep mappings up-to-date as new ETFs launch
- Consider adding disclaimer about tracking error between fund and ETF

## Integration Checklist

✅ JSON mappings file created  
✅ TickerMappingService actor created  
✅ MarketstackError extended with new cases  
✅ MarketstackService integration complete  
✅ AddAssetView UI enhanced with suggestion card  
✅ Error handling updated  
✅ State management for suggestions added  

**Next Steps:**
1. Add TickerMappings.json to Xcode project target
2. Test with various mutual fund tickers
3. Test with crypto tickers
4. Gather user feedback on suggestions
5. Expand mappings based on usage patterns
