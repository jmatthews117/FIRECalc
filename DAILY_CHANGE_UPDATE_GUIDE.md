# 📊 Daily Change Calculation Update

## What Changed?

Your app now calculates **daily change as current price vs. yesterday's close** instead of current price vs. today's open.

This matches how major financial apps (Yahoo Finance, Bloomberg, etc.) display daily changes.

---

## Example

**Before:**
- Today's open: $178.50
- Today's close: $181.25
- **Daily change: +$2.75 (+1.54%)**

**After:**
- Yesterday's close: $175.00
- Today's close: $181.25
- **Daily change: +$6.25 (+3.57%)**

Much more accurate! 📈

---

## What You Need to Do

### Step 1: Update Your Backend (server.js)

Replace your entire `server.js` file with the updated version in `UPDATED_BACKEND_SERVER.js`.

**Quick update:**

```bash
cd ~/Documents/firecalc-backend
cp UPDATED_BACKEND_SERVER.js server.js
```

Or manually update these sections:

#### Single Quote Endpoint (`/api/quote/:symbol`)

Change:
```javascript
const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbol}&limit=1`;
```

To:
```javascript
const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbol}&limit=2`;
```

Then add this processing **after** fetching the data:

```javascript
// Calculate daily change using yesterday's close as reference
if (data.data && data.data.length >= 2) {
    const today = data.data[0];
    const yesterday = data.data[1];
    
    // Add calculated change to today's data
    today.previousClose = yesterday.close;
    today.dailyChange = today.close - yesterday.close;
    today.dailyChangePercent = (today.dailyChange / yesterday.close);
    
    console.log(`✅ ${symbol}: $${today.close} (${today.dailyChangePercent >= 0 ? '+' : ''}${(today.dailyChangePercent * 100).toFixed(2)}%)`);
}
```

#### Batch Quotes Endpoint (`/api/quotes`)

Change:
```javascript
const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbols}`;
```

To:
```javascript
const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbols}&limit=2`;
```

Then add this processing logic (see `UPDATED_BACKEND_SERVER.js` for full code).

---

### Step 2: Test Your Backend Locally

```bash
npm start
```

Visit in your browser:
```
http://localhost:3000/api/quote/AAPL
```

You should see:
```json
{
  "data": [
    {
      "symbol": "AAPL",
      "close": 181.25,
      "previousClose": 178.50,
      "dailyChange": 2.75,
      "dailyChangePercent": 0.0154,
      ...
    }
  ]
}
```

✅ If you see `previousClose`, `dailyChange`, and `dailyChangePercent`, you're good!

---

### Step 3: Deploy to Render

```bash
cd ~/Documents/firecalc-backend

git add .
git commit -m "Update to limit=2 for accurate daily change calculation"
git push
```

Render will automatically detect the push and redeploy (takes 2-3 minutes).

---

### Step 4: Update Your iOS App (Already Done! ✅)

I've already updated these files for you:

1. ✅ **MarketstackTestService.swift** - Updated `MarketstackQuote` struct to include:
   - `previousClose: Double?`
   - `dailyChange: Double?`
   - `dailyChangePercent: Double?`

2. ✅ **MarketstackConfig.swift** - Updated to parse the new backend response

3. ✅ **Mock data** - All test data now includes accurate daily changes

**No further iOS changes needed!** Just rebuild your app after deploying the backend.

---

## API Usage Impact

### Before (limit=1):
```
GET /v1/eod/latest?symbols=AAPL&limit=1
```
- Returns 1 day of data
- Charges for 1 API call

### After (limit=2):
```
GET /v1/eod/latest?symbols=AAPL&limit=2
```
- Returns 2 days of data
- **Still charges for 1 API call** (same request!)

**Cost: ZERO increase** ✅

Marketstack charges **per HTTP request**, not per day of data returned. You're just asking for more data in the same call.

---

## How It Works Now

### Backend Side:
1. iOS app requests quote for AAPL
2. Backend requests `limit=2` from Marketstack
3. Marketstack returns:
   ```json
   {
     "data": [
       {"symbol": "AAPL", "date": "2024-03-11", "close": 181.25},  // Today
       {"symbol": "AAPL", "date": "2024-03-10", "close": 178.50}   // Yesterday
     ]
   }
   ```
4. Backend calculates:
   - `previousClose = 178.50`
   - `dailyChange = 181.25 - 178.50 = 2.75`
   - `dailyChangePercent = 2.75 / 178.50 = 0.0154`
5. Backend sends enhanced data to iOS app

### iOS Side:
1. Receives quote with `previousClose`, `dailyChange`, `dailyChangePercent`
2. `MarketstackQuote.toStockQuote()` uses these values
3. Portfolio calculations automatically use the accurate daily change
4. UI displays: **"AAPL +$2.75 (+1.54%)"**

---

## Testing Checklist

After deploying the backend:

- [ ] Visit `https://your-backend.onrender.com/api/quote/AAPL`
- [ ] Confirm response includes `previousClose`, `dailyChange`, `dailyChangePercent`
- [ ] Build and run your iOS app
- [ ] Refresh portfolio prices
- [ ] Check console logs for: `✅ [CONFIG] Successfully fetched quote for AAPL: $181.25 (+1.54%)`
- [ ] Verify daily gain/loss matches new calculation

---

## Rollback (If Needed)

If something goes wrong, you can quickly rollback:

1. In your backend, change `limit=2` back to `limit=1`
2. Remove the daily change calculation code
3. Push to GitHub
4. Render will redeploy the old version

Your iOS app will gracefully fallback to using `open` for daily change calculation.

---

## Summary

✅ **iOS app updated** - Already done, no action needed  
🔄 **Backend needs update** - Copy `UPDATED_BACKEND_SERVER.js` to `server.js`  
🚀 **Deploy to Render** - `git push` and wait 2-3 minutes  
💰 **Cost impact** - ZERO (still 1 API call per symbol)  
📊 **Result** - More accurate daily change calculations!

---

## Questions?

- **Does this use more API calls?** No! Still 1 call per symbol.
- **Why is this more accurate?** Financial markets compare to previous close, not today's open.
- **What if yesterday's data is missing?** App falls back to `close - open` calculation.
- **Can I test before deploying?** Yes! Test locally first at `localhost:3000`.

Ready to deploy? Just update your backend and push to GitHub! 🚀
