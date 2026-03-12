# 🚀 Quick Deploy Guide - Daily Change Update

## TL;DR

**iOS:** ✅ Already done  
**Backend:** 🔄 Needs update  
**Cost:** $0 (no API increase)

---

## Step 1: Update Backend (5 minutes)

```bash
cd ~/Documents/firecalc-backend
```

**Option A: Replace entire file**
```bash
# Copy the updated server.js content from UPDATED_BACKEND_SERVER.js
# Save it, replacing your current server.js
```

**Option B: Manual update (2 changes)**

1. Change line 96:
   ```javascript
   // FROM:
   const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbol}&limit=1`;
   
   // TO:
   const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbol}&limit=2`;
   ```

2. Add after line 101 (after getting data):
   ```javascript
   // Calculate daily change using yesterday's close as reference
   if (data.data && data.data.length >= 2) {
       const today = data.data[0];
       const yesterday = data.data[1];
       
       today.previousClose = yesterday.close;
       today.dailyChange = today.close - yesterday.close;
       today.dailyChangePercent = (today.dailyChange / yesterday.close);
       
       console.log(`✅ ${symbol}: $${today.close} (${today.dailyChangePercent >= 0 ? '+' : ''}${(today.dailyChangePercent * 100).toFixed(2)}%)`);
   }
   ```

3. Change line 123:
   ```javascript
   // FROM:
   const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbols}`;
   
   // TO:
   const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbols}&limit=2`;
   ```

4. Add batch processing logic (see UPDATED_BACKEND_SERVER.js lines 130-166)

---

## Step 2: Test Locally

```bash
npm start
```

Open browser: `http://localhost:3000/api/quote/AAPL`

✅ Look for `previousClose`, `dailyChange`, `dailyChangePercent` in response

---

## Step 3: Deploy to Render

```bash
git add .
git commit -m "Add limit=2 for accurate daily change calculation"
git push
```

Wait 2-3 minutes for Render to redeploy.

---

## Step 4: Test iOS App

1. Press `Cmd+B` in Xcode to rebuild
2. Run app
3. Refresh portfolio
4. Check console for: `✅ [CONFIG] Successfully fetched quote for AAPL: $181.25 (+1.54%)`

---

## Done! 🎉

Your app now calculates daily change as **current vs. yesterday's close** (industry standard).

**No increase in API usage** - still 1 call per symbol.

---

## If Something Goes Wrong

1. Check Render logs for backend errors
2. Verify `limit=2` is in both endpoints
3. Make sure you pushed to GitHub
4. Rebuild iOS app after backend is updated

**Need help?** See:
- `DAILY_CHANGE_UPDATE_GUIDE.md` - Detailed instructions
- `UPDATED_BACKEND_SERVER.js` - Complete backend code
- `DAILY_CHANGE_IMPLEMENTATION_SUMMARY.md` - Full technical details

---

## Backend Changes Summary

**Before:**
```javascript
limit=1  // Only today's data
```

**After:**
```javascript
limit=2  // Today + yesterday for accurate daily change
```

**Result:**
- More accurate daily change percentages
- Matches Yahoo Finance, Bloomberg, etc.
- Same API cost (1 call per symbol)
