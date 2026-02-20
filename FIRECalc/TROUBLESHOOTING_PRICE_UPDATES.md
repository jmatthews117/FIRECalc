# Troubleshooting: "Unable to Update Prices" Error

## What This Error Means

When you see "Unable to update prices" (or a variation like "Unable to update prices for: [ticker symbols]"), it means that **all** of your price update attempts failed. No assets were successfully updated.

## Quick Diagnostic Steps

### Step 1: Check Xcode Console
Open the Xcode console while testing and look for these messages:

```
🔄 Starting price refresh...
   Assets with tickers: X
   Tickers to update: VOO, BTC-USD, ...
📊 Fetching prices from Yahoo Finance...
```

Then look for:
- ✅ or ✓ = Success
- ❌ or ✗ = Failure

### Step 2: Common Causes & Solutions

#### Cause 1: Internet Connection
**Symptom**: Console shows network errors
```
❌ Network error: The Internet connection appears to be offline
```

**Solution**: 
- Check your device's WiFi/cellular connection
- Try opening Safari and visiting yahoo.com to verify connectivity
- If on simulator, check your Mac's internet connection

#### Cause 2: Invalid Ticker Symbols
**Symptom**: Console shows "Ticker not found" or HTTP 404 errors
```
❌ Failed to update ABC: Ticker 'ABC' not found on Yahoo Finance
```

**Solution**: 
- Verify ticker symbols at [Yahoo Finance](https://finance.yahoo.com)
- Common issues:
  - **Crypto**: Must use `-USD` suffix (e.g., `BTC-USD`, not `BTC`)
  - **International stocks**: May need exchange suffix (e.g., `.L` for London)
  - **Delisted stocks**: Won't have price data
  - **Typos**: Double-check spelling

#### Cause 3: Yahoo Finance API Rate Limiting
**Symptom**: First few tickers succeed, then all fail
```
✅ Updated VOO: $450.25
✅ Updated AAPL: $175.50
❌ HTTP error: 429
```

**Solution**:
- Wait 5-10 minutes before trying again
- The app batches requests with delays to avoid this
- If you have many assets, updates may take longer

#### Cause 4: Yahoo Finance Service Outage
**Symptom**: Consistent HTTP 5xx errors (500, 503, etc.)
```
❌ HTTP error: 503. Yahoo Finance may be temporarily unavailable.
```

**Solution**:
- Wait and try again later (usually resolves within minutes)
- Check [Yahoo Finance status](https://finance.yahoo.com) in a browser
- This is rare but can happen during market hours with high traffic

#### Cause 5: Market Hours (Less Common)
**Symptom**: Updates work during trading hours but fail outside market hours
```
❌ HTTP error: 404 (for newly added stocks only)
```

**Note**: Yahoo Finance usually provides prices 24/7, but newly listed stocks may not have after-hours data immediately.

**Solution**: Wait until market opens or check the ticker is correct

## Detailed Diagnostics

### Check Your Ticker Symbols

Run through each asset in your portfolio and verify:

1. **For US Stocks/ETFs**:
   - ✅ Correct: `VOO`, `AAPL`, `MSFT`
   - ❌ Wrong: `voo`, `Apple`, `Microsoft`

2. **For Cryptocurrencies**:
   - ✅ Correct: `BTC-USD`, `ETH-USD`, `DOGE-USD`
   - ❌ Wrong: `BTC`, `BITCOIN`, `Ethereum`

3. **For International Stocks**:
   - ✅ Correct: `BP.L` (London), `SAP.DE` (Germany)
   - ❌ Wrong: `BP`, `SAP`

### Test Individual Tickers

You can test if a ticker works by:
1. Opening Safari on your device
2. Going to: `https://finance.yahoo.com/quote/VOO`
3. Replace `VOO` with your ticker
4. If it loads with a price, the ticker is valid

### Check Asset Configuration

Make sure your assets:
- Have a ticker symbol entered
- Ticker is in the correct field (not in the name field)
- No extra spaces before/after the ticker

## How to Fix Common Issues

### Fix 1: Update Invalid Tickers

1. Go to **Portfolio** tab
2. Tap the asset with the invalid ticker
3. Edit the ticker symbol
4. Verify it on Yahoo Finance first
5. Save and pull to refresh

### Fix 2: Remove Assets Without Valid Tickers

If you have assets that don't have tickers (like real estate, private investments):
- Leave the ticker field **empty**
- The app will use your manual valuation
- These won't be included in automatic price updates

### Fix 3: Test Network Connectivity

```swift
// The app will show specific error messages:
"Network error. Check your internet connection."  // Can't reach internet
"HTTP error: 429..."                              // Rate limited
"Ticker 'XYZ' not found..."                      // Invalid ticker
```

## Expected Console Output (Success)

When everything works, you should see:
```
🔄 Starting price refresh...
   Assets with tickers: 3
   Tickers to update: VOO, BTC-USD, AAPL
📊 Fetching prices from Yahoo Finance...
📡 Fetching VOO from: https://query1.finance.yahoo.com/v8/finance/chart/VOO
📡 HTTP Status: 200
✅ Got quote for VOO: $450.25
✅ Updated VOO: $450.25
   ✓ VOO updated successfully
[... similar for other tickers ...]
✅ Prices updated: 3 succeeded, 0 failed
```

## Expected Console Output (Partial Failure)

When some tickers fail:
```
🔄 Starting price refresh...
   Assets with tickers: 3
   Tickers to update: VOO, BADTICKER, AAPL
📊 Fetching prices from Yahoo Finance...
✅ Updated VOO: $450.25
   ✓ VOO updated successfully
❌ Failed to update BADTICKER
   ✗ BADTICKER failed to update (timestamp unchanged)
✅ Updated AAPL: $175.50
   ✓ AAPL updated successfully
✅ Prices updated: 2 succeeded, 1 failed
   Failed tickers: BADTICKER
```

## Expected Console Output (Total Failure)

When all tickers fail (what you're seeing now):
```
🔄 Starting price refresh...
   Assets with tickers: 2
   Tickers to update: BADTICKER1, BADTICKER2
📊 Fetching prices from Yahoo Finance...
❌ Failed to update BADTICKER1
   ✗ BADTICKER1 has no price data
❌ Failed to update BADTICKER2
   ✗ BADTICKER2 has no price data
✅ Prices updated: 0 succeeded, 2 failed
   Failed tickers: BADTICKER1, BADTICKER2
```

## Still Not Working?

If you've tried all the above and still getting errors:

### 1. Share Your Console Output
Look for the complete error message chain and share it. It should show:
- Which tickers are failing
- What specific error is occurring
- HTTP status codes (if network-related)

### 2. Try These Test Tickers
Add a new test asset with one of these guaranteed-working tickers:
- `SPY` - S&P 500 ETF
- `AAPL` - Apple stock
- `BTC-USD` - Bitcoin

If these work, your network is fine and the issue is with your specific ticker symbols.

### 3. Check for App Permissions
Ensure the app has network access:
- Settings > Privacy > Local Network
- Make sure app isn't blocked by any VPN or firewall

### 4. Clear and Refresh
Try this reset procedure:
1. Force quit the app
2. Reopen it
3. Wait for auto-refresh on launch
4. Manually pull to refresh

## Prevention Tips

To avoid this error in the future:

1. **Always verify tickers** on Yahoo Finance before adding them
2. **Use the correct format** for crypto (add `-USD`)
3. **Don't mix up name and ticker** - Name is "Apple Inc.", Ticker is "AAPL"
4. **Leave ticker blank** for assets without public pricing
5. **Check console logs** when adding new assets to catch errors early

## Technical Details

The app uses Yahoo Finance's free public API:
- Endpoint: `https://query1.finance.yahoo.com/v8/finance/chart/[TICKER]`
- No API key required
- Rate limiting: ~2000 requests/hour per IP
- Includes retry logic (3 attempts per ticker)
- Batches requests (3 at a time) to be respectful to the service
