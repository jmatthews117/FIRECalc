# Debug Console Guide - Price Refresh Issues

## How to Debug

### Step 1: Open Console in Xcode
1. In Xcode, press `Cmd + Shift + Y` to open the debug console at the bottom
2. Or go to: View > Debug Area > Show Debug Area

### Step 2: Clear Console
- Click the trash icon in the console to clear old logs
- Or right-click and select "Clear Console"

### Step 3: Run Refresh
1. With console visible, run your app
2. Pull down to refresh on the dashboard
3. Watch the console output in real-time

## What to Look For

### Expected Output (Success)

```
============================================================
🔄 REFRESH PRICES STARTED
============================================================
📅 Time: 2026-02-20 15:30:45 +0000
📊 Total assets in portfolio: 1
🎯 Assets with tickers: 1

📋 All Assets:
   1. SPY
      - Asset Class: Stocks
      - Ticker: SPY
      - Current Price: Optional(550.25)
      - Last Updated: Optional(2026-02-20 15:00:00 +0000)
      - Quantity: 1.0

🎯 Tickers to update: SPY

------------------------------------------------------------
🚀 BEGINNING API CALLS
------------------------------------------------------------

📡 [1/1] Processing: SPY
   Asset Name: SPY
   Asset ID: [UUID]
   Current Price: Optional(550.25)
   Last Updated: Optional(2026-02-20 15:00:00 +0000)
   ⏳ Calling YahooFinanceService.shared.fetchQuote(ticker: "SPY")...
   ✅ SUCCESS! Got quote:
      - Symbol: SPY
      - Price: $551.50
      - Change: Optional(1.25)
      - Change %: Optional(0.00227)
   📝 Updating asset in portfolio...
      - Old price: Optional(550.25)
      - New price: Optional(551.50)
      - Old lastUpdated: Optional(2026-02-20 15:00:00 +0000)
      - New lastUpdated: Optional(2026-02-20 15:30:50 +0000)
   ✅ Asset updated in portfolio successfully
   ⏸️  Waiting 0.3 seconds before next request...

------------------------------------------------------------
💾 SAVING PORTFOLIO
------------------------------------------------------------
✅ Portfolio saved

============================================================
📊 FINAL RESULTS
============================================================
✅ Successful updates: 1
❌ Failed updates: 0
🎉 All prices updated successfully!
============================================================
```

### Common Error Patterns

#### Pattern 1: No Assets with Tickers
```
📊 Total assets in portfolio: 3
🎯 Assets with tickers: 0

⚠️ NO ASSETS WITH TICKERS - EXITING
```
**What it means**: Assets don't have ticker symbols set
**Fix**: Check that assets have tickers in the "Ticker" field

#### Pattern 2: Network Error
```
📡 [1/1] Processing: SPY
   ⏳ Calling YahooFinanceService.shared.fetchQuote(ticker: "SPY")...
   ❌ FAILED!
      Error Type: URLError
      Error: Error Domain=NSURLErrorDomain Code=-1009 "The Internet connection appears to be offline."
```
**What it means**: No internet connection
**Fix**: Check WiFi/cellular connection

#### Pattern 3: Invalid Ticker
```
📡 [1/1] Processing: INVALIDTICKER
   ⏳ Calling YahooFinanceService.shared.fetchQuote(ticker: "INVALIDTICKER")...
   ❌ FAILED!
      Error Type: YFError
      Error: tickerNotFound("INVALIDTICKER")
      Localized: Ticker 'INVALIDTICKER' not found on Yahoo Finance. Please verify the symbol is correct.
```
**What it means**: Ticker symbol doesn't exist on Yahoo Finance
**Fix**: Verify ticker on yahoo.com/finance

#### Pattern 4: API Call Succeeds But Asset Not Updated
```
📡 [1/1] Processing: SPY
   ⏳ Calling YahooFinanceService.shared.fetchQuote(ticker: "SPY")...
   ✅ SUCCESS! Got quote:
      - Symbol: SPY
      - Price: $551.50
   📝 Updating asset in portfolio...
      - Old price: Optional(550.25)
      - New price: Optional(550.25)  ← STILL THE SAME!
      - Old lastUpdated: Optional(2026-02-20 15:00:00 +0000)
      - New lastUpdated: Optional(2026-02-20 15:00:00 +0000)  ← NOT UPDATED!
```
**What it means**: `updatedWithLivePrice()` isn't working
**Fix**: This is a code bug - need to investigate the Asset model

#### Pattern 5: Updates Happening But Portfolio Not Saved
```
✅ Asset updated in portfolio successfully
✅ Asset updated in portfolio successfully

------------------------------------------------------------
💾 SAVING PORTFOLIO
------------------------------------------------------------
[no "✅ Portfolio saved" message]
```
**What it means**: Portfolio save is failing
**Fix**: Check PersistenceService

## Questions to Answer From Console

When you share the console output, we need to know:

1. **How many assets do you have?**
   - Look for: `📊 Total assets in portfolio: X`

2. **How many have tickers?**
   - Look for: `🎯 Assets with tickers: X`

3. **What are the ticker symbols?**
   - Look for: `🎯 Tickers to update: [list]`

4. **Does the API call succeed?**
   - Look for: `✅ SUCCESS! Got quote:` or `❌ FAILED!`

5. **What's the actual error?**
   - Look for the full error details after `❌ FAILED!`

6. **Are the old/new values changing?**
   - Compare "Old price" vs "New price"
   - Compare "Old lastUpdated" vs "New lastUpdated"

## Next Steps

After running the refresh and getting console output:

1. **Copy the ENTIRE console output** (from the first `====` line to the last)
2. **Share it** so we can see exactly what's happening
3. **Note the error message** you see in the app UI
4. **Check if prices updated** in the portfolio view

The detailed logging will tell us exactly where things are breaking!
