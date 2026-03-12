# Ticker Mapping System - Setup Instructions

## Quick Start

Follow these steps to integrate the ticker mapping system into your Xcode project:

### 1. Add Files to Xcode Project

You need to add these new files to your Xcode project:

**Data File:**
- `TickerMappings.json` - Make sure to check "Target Membership" for your app target

**Swift Files:**
- `TickerMappingService.swift`
- `TickerMappingSuggestionCard.swift`

**Modified Files:**
- `MarketstackTestService.swift` (updated MarketstackError enum)
- `MarketstackService.swift` (added mapping checks)
- `add_asset_view.swift` (enhanced UI with suggestions)

### 2. Add JSON to Bundle

**Important:** The JSON file must be included in your app bundle.

1. In Xcode, select `TickerMappings.json`
2. Open the File Inspector (⌥⌘1)
3. Under "Target Membership", check your app target
4. Build Settings should copy it to the bundle

**Verify it's in the bundle:**
```swift
if let url = Bundle.main.url(forResource: "TickerMappings", withExtension: "json") {
    print("✅ JSON found at: \(url)")
} else {
    print("❌ JSON not in bundle!")
}
```

### 3. Build & Test

1. Clean build folder: ⇧⌘K
2. Build: ⌘B
3. Run on simulator or device
4. Test with these tickers:
   - `VTSAX` (should suggest VTI)
   - `BTC` (should suggest IBIT)
   - `AAPL` (should load normally)

## File Structure

Your project should look like this:

```
FIRECalc/
├── Models/
│   └── Asset.swift
├── Services/
│   ├── MarketstackService.swift ✏️ (modified)
│   ├── MarketstackTestService.swift ✏️ (modified)
│   └── TickerMappingService.swift ⭐ (new)
├── Views/
│   ├── add_asset_view.swift ✏️ (modified)
│   └── TickerMappingSuggestionCard.swift ⭐ (new)
├── Resources/
│   └── TickerMappings.json ⭐ (new)
└── ContentView.swift
```

## Testing Checklist

### Test Case 1: Mutual Fund Detection
1. Open AddAssetView
2. Select "Stocks" as asset type
3. Enter "VTSAX" as ticker
4. Click "Load Price"
5. **Expected:** Orange suggestion card appears
6. **Expected:** Card suggests VTI with explanation
7. Click "Use This"
8. **Expected:** Ticker changes to VTI
9. **Expected:** Price loads successfully

### Test Case 2: Crypto Detection
1. Open AddAssetView
2. Select "Crypto" as asset type
3. Enter "BTC" as ticker
4. Click "Load Price"
5. **Expected:** Orange suggestion card appears
6. **Expected:** Card suggests IBIT
7. Click "Use This"
8. **Expected:** Ticker changes to IBIT
9. **Expected:** Price loads successfully

### Test Case 3: Normal Stock (No Mapping)
1. Open AddAssetView
2. Select "Stocks" as asset type
3. Enter "AAPL" as ticker
4. Click "Load Price"
5. **Expected:** No suggestion card
6. **Expected:** Price loads directly
7. **Expected:** Green checkmark shows price

### Test Case 4: Dismiss Suggestion
1. Open AddAssetView
2. Enter "FXAIX" as ticker
3. Click "Load Price"
4. **Expected:** Suggestion card appears
5. Click "Dismiss"
6. **Expected:** Card disappears
7. **Expected:** Can try different ticker

### Test Case 5: Multiple Attempts
1. Enter "VTSAX" → See VTI suggestion
2. Enter "VFIAX" → See VOO suggestion
3. Enter "BTC" → See IBIT suggestion
4. **Expected:** Each shows correct mapping
5. **Expected:** No memory leaks or crashes

## Common Issues & Solutions

### Issue: "JSON not found in bundle"

**Solution:**
1. Select `TickerMappings.json` in Xcode
2. File Inspector → Target Membership
3. Check your app target
4. Clean and rebuild

### Issue: "Use This" button doesn't work

**Solution:**
- Check that the binding for `ticker` is correct
- Verify `loadPrice()` is called after ticker change
- Check console for errors

### Issue: Suggestion card doesn't appear

**Solution:**
- Verify `MarketstackError` has new cases
- Check that `MarketstackService` is calling `TickerMappingService`
- Add breakpoint in error handling to verify error type
- Check console for "🚫 Mutual fund intercepted" or "🚫 Crypto intercepted" logs

### Issue: App crashes on ticker lookup

**Solution:**
- Verify JSON syntax is valid (use JSONLint.com)
- Check that `TickerMapping` struct matches JSON structure
- Ensure `TickerMappingService` is initialized properly
- Check actor isolation warnings

## Debugging

### Enable Verbose Logging

The system already includes logging. Look for these emojis in console:

- 🔍 Ticker lookup started
- 🚫 Unsupported ticker intercepted
- ✅ Supported ticker, proceeding
- ❓ Unknown ticker, attempting fetch
- 💾 JSON loaded successfully
- ⚠️ JSON loading failed

### Console Output Examples

**Successful interception:**
```
🔍 fetchQuote called for: 'VTSAX' → cleaned: 'VTSAX' (bypass: true)
🔄 Mutual fund detected: VTSAX → suggest VTI
🚫 Mutual fund intercepted: VTSAX → suggest VTI
```

**Normal stock lookup:**
```
🔍 fetchQuote called for: 'AAPL' → cleaned: 'AAPL' (bypass: true)
✅ Ticker AAPL is supported - proceeding with price fetch
```

### Xcode Breakpoints

Set breakpoints at:
1. `TickerMappingService.checkTicker()` - See mapping check
2. `MarketstackService.fetchQuote()` - See interception
3. `AddAssetView.loadPrice()` - See error handling
4. `TickerMappingSuggestionCard` init - See UI creation

## Advanced Configuration

### Customize Suggestion Card Styling

Edit `TickerMappingSuggestionCard.swift`:

```swift
.background(Color.orange.opacity(0.08))  // Change background
.cornerRadius(12)  // Change corner radius
.stroke(Color.orange.opacity(0.3), lineWidth: 1.5)  // Change border
```

### Add Custom Ticker Categories

1. Edit `TickerMappings.json`:
```json
{
  "mutualFunds": { ... },
  "crypto": { ... },
  "commodities": {  // New category
    "GOLD": {
      "name": "Physical Gold",
      "etfAlternative": "GLD",
      "etfName": "SPDR Gold Shares",
      "reason": "Direct gold exposure"
    }
  }
}
```

2. Update `TickerMappings` struct:
```swift
struct TickerMappings: Codable {
    let mutualFunds: [String: TickerMapping]
    let crypto: [String: TickerMapping]
    let commodities: [String: TickerMapping]  // Add this
}
```

3. Update `checkTicker()`:
```swift
// Check commodities
if let mapping = mappings.commodities[cleanTicker] {
    return .unsupportedCommodity(original: cleanTicker, mapping: mapping)
}
```

4. Add new error case:
```swift
case .unsupportedCommodity(original: String, mapping: TickerMapping)
```

### Remote JSON Updates

To fetch mappings from a server instead of bundled JSON:

```swift
actor TickerMappingService {
    private var mappings: TickerMappings?
    
    private func loadMappings() async {
        // Try remote first
        if let remoteMappings = await fetchRemoteMappings() {
            mappings = remoteMappings
            return
        }
        
        // Fallback to bundled
        loadBundledMappings()
    }
    
    private func fetchRemoteMappings() async -> TickerMappings? {
        guard let url = URL(string: "https://yourserver.com/ticker-mappings.json") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(TickerMappings.self, from: data)
        } catch {
            print("⚠️ Failed to fetch remote mappings: \(error)")
            return nil
        }
    }
}
```

## Performance Notes

- JSON loaded once on app launch (lazy init)
- Dictionary lookups are O(1) - instant
- No network calls for mapping checks
- Prevents unnecessary API calls
- Thread-safe with Swift actors

## Maintenance

### Regular Updates Needed

1. **New ETFs Launch** - Update mappings when better alternatives exist
2. **Crypto ETFs** - Bitcoin/Ethereum ETF landscape changing rapidly
3. **Fund Closures** - Remove obsolete mutual funds
4. **User Requests** - Add commonly requested tickers

### Version the JSON

Consider adding version info:

```json
{
  "version": "1.0.0",
  "lastUpdated": "2026-03-09",
  "mutualFunds": { ... },
  "crypto": { ... }
}
```

Then update struct:
```swift
struct TickerMappings: Codable {
    let version: String
    let lastUpdated: String
    let mutualFunds: [String: TickerMapping]
    let crypto: [String: TickerMapping]
}
```

## Support

If you encounter issues:

1. Check this document first
2. Review console logs
3. Verify JSON is in bundle
4. Test with known tickers
5. Check Xcode warnings/errors

## Success Criteria

✅ User enters mutual fund ticker  
✅ Suggestion card appears  
✅ Alternative ETF is relevant and accurate  
✅ "Use This" button works  
✅ Price loads for suggested ticker  
✅ No API calls wasted  
✅ User experience is smooth  

When all criteria are met, the system is working correctly!
