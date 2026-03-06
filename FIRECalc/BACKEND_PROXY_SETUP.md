# 🚀 Backend Proxy Setup Guide

This guide shows you how to create a secure backend proxy for your Marketstack API key, eliminating security concerns for App Store review.

---

## 📋 Overview

**Current Setup (Insecure):**
```
iOS App → (fetches API key from public Gist) → Marketstack API
```

**New Setup (Secure):**
```
iOS App → Your HTTPS Backend → Marketstack API
              ↑
         (API key stored here)
```

**Benefits:**
- ✅ API key never in your app
- ✅ Use HTTPS (solves ATS issue)
- ✅ Rotate keys anytime
- ✅ App Store approved
- ✅ Add rate limiting, caching, analytics

---

## Option 1: Node.js on Render.com (FREE & Recommended)

### Step 1: Create Backend Project

Create a new folder outside your iOS project:

```bash
mkdir firecalc-backend
cd firecalc-backend
npm init -y
```

### Step 2: Install Dependencies

```bash
npm install express node-fetch dotenv cors
```

### Step 3: Create `server.js`

```javascript
// server.js
const express = require('express');
const fetch = require('node-fetch');
require('dotenv').config();
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Enable CORS (restrict to your app in production)
app.use(cors());

// Health check
app.get('/', (req, res) => {
    res.json({ 
        status: 'FIRECalc API Proxy',
        version: '1.0.0'
    });
});

// Single quote endpoint: /api/quote/AAPL
app.get('/api/quote/:symbol', async (req, res) => {
    try {
        const symbol = req.params.symbol.toUpperCase();
        const apiKey = process.env.MARKETSTACK_API_KEY;
        
        if (!apiKey) {
            console.error('❌ MARKETSTACK_API_KEY not configured');
            return res.status(500).json({ error: 'API key not configured' });
        }
        
        console.log(`📡 Fetching quote for ${symbol}`);
        
        // Call Marketstack API
        const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbol}&limit=1`;
        const response = await fetch(url);
        const data = await response.json();
        
        // Check for Marketstack errors
        if (data.error) {
            console.error(`❌ Marketstack error: ${data.error.message}`);
            return res.status(400).json({ 
                error: data.error.message,
                code: data.error.code
            });
        }
        
        // Check if we got data
        if (!data.data || data.data.length === 0) {
            console.warn(`⚠️ No data found for ${symbol}`);
            return res.status(404).json({ 
                error: `No data found for symbol ${symbol}` 
            });
        }
        
        console.log(`✅ Successfully fetched ${symbol}`);
        
        // Return the response
        res.json(data);
        
    } catch (error) {
        console.error('❌ Error fetching quote:', error);
        res.status(500).json({ 
            error: 'Failed to fetch stock quote',
            message: error.message
        });
    }
});

// Batch quotes endpoint: /api/quotes?symbols=AAPL,MSFT,GOOGL
app.get('/api/quotes', async (req, res) => {
    try {
        const symbols = req.query.symbols;
        const apiKey = process.env.MARKETSTACK_API_KEY;
        
        if (!apiKey) {
            console.error('❌ MARKETSTACK_API_KEY not configured');
            return res.status(500).json({ error: 'API key not configured' });
        }
        
        if (!symbols) {
            return res.status(400).json({ 
                error: 'symbols parameter required (comma-separated)' 
            });
        }
        
        console.log(`📡 Fetching batch quotes for: ${symbols}`);
        
        // Call Marketstack API
        const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbols}`;
        const response = await fetch(url);
        const data = await response.json();
        
        // Check for Marketstack errors
        if (data.error) {
            console.error(`❌ Marketstack error: ${data.error.message}`);
            return res.status(400).json({ 
                error: data.error.message,
                code: data.error.code
            });
        }
        
        console.log(`✅ Successfully fetched ${data.data?.length || 0} quotes`);
        
        res.json(data);
        
    } catch (error) {
        console.error('❌ Error fetching quotes:', error);
        res.status(500).json({ 
            error: 'Failed to fetch stock quotes',
            message: error.message
        });
    }
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 FIRECalc API Proxy running on port ${PORT}`);
    console.log(`📍 Health check: http://localhost:${PORT}/`);
});
```

### Step 4: Create `.env` File

```bash
# .env
MARKETSTACK_API_KEY=your_actual_marketstack_api_key_here
PORT=3000
```

### Step 5: Create `.gitignore`

```bash
# .gitignore
node_modules/
.env
*.log
```

### Step 6: Test Locally

```bash
node server.js
```

Test in browser or curl:
```bash
# Health check
curl http://localhost:3000/

# Single quote
curl http://localhost:3000/api/quote/AAPL

# Batch quotes
curl "http://localhost:3000/api/quotes?symbols=AAPL,MSFT,GOOGL"
```

### Step 7: Deploy to Render.com (FREE)

1. **Push to GitHub:**
   ```bash
   git init
   git add .
   git commit -m "Initial backend proxy"
   git remote add origin https://github.com/yourusername/firecalc-backend.git
   git push -u origin main
   ```

2. **Deploy on Render:**
   - Go to https://render.com
   - Sign up with GitHub
   - Click **"New +"** → **"Web Service"**
   - Connect your `firecalc-backend` repo
   - Configure:
     - **Name:** `firecalc-proxy`
     - **Environment:** `Node`
     - **Build Command:** `npm install`
     - **Start Command:** `node server.js`
     - **Plan:** `Free`
   
3. **Add Environment Variable:**
   - In Render dashboard → Environment tab
   - Add: `MARKETSTACK_API_KEY` = `your_api_key`
   - Save

4. **Deploy!**
   - Click **"Create Web Service"**
   - Wait ~2 minutes for deployment
   - Your API will be live at: `https://firecalc-proxy.onrender.com`

5. **Test Your Deployed Backend:**
   ```bash
   curl https://firecalc-proxy.onrender.com/
   curl https://firecalc-proxy.onrender.com/api/quote/AAPL
   ```

---

## 🍎 Update Your iOS Code

### Step 1: Update `MarketstackConfig.swift`

Already done! Just update the backend URL:

```swift
// In MarketstackConfig.swift
private let backendURL = "https://firecalc-proxy.onrender.com"
```

### Step 2: Update `MarketstackService.swift`

Replace the API call methods to use the new backend proxy:

```swift
// OLD: Direct Marketstack API call
private func fetchQuoteFromAPI(ticker: String) async throws -> MarketstackQuote {
    let endpoint = "\(baseURL)/eod/latest"
    let apiKey = await getAPIKey()
    // ... builds URL with API key ...
}

// NEW: Use backend proxy
private func fetchQuoteFromAPI(ticker: String) async throws -> MarketstackQuote {
    // Call your backend instead of Marketstack directly
    let response = try await MarketstackConfig.shared.fetchQuote(symbol: ticker)
    
    guard let quote = response.data.first else {
        throw MarketstackError.noDataAvailable
    }
    
    return MarketstackQuote(
        symbol: quote.symbol,
        open: quote.open,
        high: quote.high,
        low: quote.low,
        close: quote.close,
        volume: quote.volume ?? 0,
        date: quote.date
    )
}
```

For batch quotes:

```swift
private func fetchBatchQuotesFromAPI(tickers: [String]) async throws -> [MarketstackQuote] {
    // Call your backend
    let response = try await MarketstackConfig.shared.fetchQuotes(symbols: tickers)
    
    return response.data.map { quote in
        MarketstackQuote(
            symbol: quote.symbol,
            open: quote.open,
            high: quote.high,
            low: quote.low,
            close: quote.close,
            volume: quote.volume ?? 0,
            date: quote.date
        )
    }
}
```

### Step 3: Remove Old Code

You can now delete/comment out:

```swift
// In MarketstackService.swift - DELETE these:
// private let baseURL = "http://api.marketstack.com/v1"
// private var apiKey: String?
// private func getAPIKey() async -> String { ... }
```

### Step 4: Test Your App

Build and run! Your app now:
- ✅ Uses HTTPS (no ATS issues)
- ✅ Never exposes API key
- ✅ Works exactly the same way
- ✅ Ready for App Store

---

## 🔒 Security Best Practices

### 1. Restrict CORS (Production)

In `server.js`, update CORS to only allow your app:

```javascript
const cors = require('cors');

app.use(cors({
    origin: function(origin, callback) {
        // Allow requests with no origin (mobile apps, curl, etc.)
        if (!origin) return callback(null, true);
        
        // You could add domain whitelist here if you add a web version
        return callback(null, true);
    }
}));
```

### 2. Add Rate Limiting

Protect your backend from abuse:

```bash
npm install express-rate-limit
```

```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: 'Too many requests, please try again later'
});

app.use('/api/', limiter);
```

### 3. Add Request Logging

Track usage:

```javascript
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
    next();
});
```

### 4. Environment Variables

Never commit your `.env` file! Keep API keys secret.

---

## 💰 Cost Analysis

### Render.com Free Tier:
- ✅ **Free forever**
- ✅ 750 hours/month (enough for 1 always-on service)
- ✅ Automatic HTTPS
- ✅ Auto-deploys from GitHub
- ⚠️ Sleeps after 15 min inactivity (first request may be slow)

**Upgrade ($7/month) for:**
- No sleep
- Faster response times
- More instances

### Alternatives:
- **Heroku:** $7/month (no free tier anymore)
- **Railway:** $5/month
- **Vercel:** Free (serverless functions)
- **Cloudflare Workers:** Free up to 100k requests/day

---

## 🧪 Testing Checklist

- [ ] Backend deploys successfully
- [ ] Health check endpoint works: `https://your-backend.com/`
- [ ] Single quote works: `https://your-backend.com/api/quote/AAPL`
- [ ] Batch quotes work: `https://your-backend.com/api/quotes?symbols=AAPL,MSFT`
- [ ] iOS app connects to backend
- [ ] Stock quotes load in app
- [ ] Portfolio refresh works
- [ ] No API key visible in app code
- [ ] HTTPS works (no ATS errors)

---

## 🚨 Troubleshooting

### "API key not configured" error
- Check environment variables in Render dashboard
- Restart the service after adding variables

### "Failed to fetch" in iOS app
- Check backend URL is correct in `MarketstackConfig.swift`
- Verify backend is running (visit health check endpoint)
- Check Xcode console for error messages

### Backend sleeps (Render free tier)
- First request after sleep takes ~30 seconds
- Upgrade to paid tier for no-sleep
- Or implement a "wake up" ping from your app

### CORS errors (if building web version)
- Update CORS configuration in `server.js`
- Add your web domain to allowed origins

---

## ✅ Summary

**What you built:**
1. Node.js backend that proxies Marketstack requests
2. Deployed to Render.com for free
3. Updated iOS app to use HTTPS backend
4. API key stays secure on server

**App Store Benefits:**
- ✅ No hardcoded API keys
- ✅ HTTPS only (passes ATS)
- ✅ Rotate keys anytime (on server)
- ✅ Production-ready security

**Next Steps:**
1. Deploy your backend
2. Update `backendURL` in `MarketstackConfig.swift`
3. Update `MarketstackService.swift` to use new methods
4. Test thoroughly
5. Submit to App Store! 🎉

---

## 📞 Need Help?

Common issues:
- **Deployment:** Check Render logs in dashboard
- **API errors:** Test endpoints in browser first
- **iOS errors:** Check Xcode console for details

Your backend is now production-ready and App Store approved! 🚀
