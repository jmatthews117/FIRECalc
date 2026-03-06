# 🎯 Backend Proxy: Simple Step-by-Step Guide

**Don't worry! This is simpler than it looks. Follow along step by step.**

---

## 🤔 What Are We Doing?

Right now: Your iPhone app has your API key in it (insecure ❌)

After this: Your API key lives on a server, and your iPhone app talks to your server (secure ✅)

Think of it like:
- **Old way:** Giving your credit card to a stranger
- **New way:** Using Apple Pay (the stranger never sees your card)

---

## Step 1: Create Your Backend Server (On Your Mac)

### What is a "backend"?

A backend is just a small program that runs on the internet. It's like a helper that handles your API key for you.

### Let's create it!

#### 1.1 - Open Terminal

On your Mac, press `Command + Space`, type "Terminal", press Enter.

#### 1.2 - Create a folder for your backend

```bash
cd ~/Documents
mkdir firecalc-backend
cd firecalc-backend
```

**What this does:** Creates a new folder called `firecalc-backend` in your Documents folder.

#### 1.3 - Create `package.json`

Copy and paste this command:

```bash
cat > package.json << 'EOF'
{
  "name": "firecalc-backend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "node-fetch": "^2.7.0",
    "dotenv": "^16.3.1",
    "cors": "^2.8.5",
    "express-rate-limit": "^7.1.5"
  }
}
EOF
```

Press Enter. This creates a file that tells Node.js what libraries you need.

#### 1.4 - Create `server.js`

This is the actual backend code. Copy and paste this:

```bash
cat > server.js << 'EOF'
const express = require('express');
const fetch = require('node-fetch');
require('dotenv').config();
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());

app.get('/', (req, res) => {
    res.json({ status: 'FIRECalc API Proxy Running' });
});

app.get('/api/quote/:symbol', async (req, res) => {
    try {
        const symbol = req.params.symbol.toUpperCase();
        const apiKey = process.env.MARKETSTACK_API_KEY;
        
        if (!apiKey) {
            return res.status(500).json({ error: 'API key not configured' });
        }
        
        const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbol}&limit=1`;
        const response = await fetch(url);
        const data = await response.json();
        
        if (data.error) {
            return res.status(400).json({ error: data.error.message });
        }
        
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch stock quote' });
    }
});

app.get('/api/quotes', async (req, res) => {
    try {
        const symbols = req.query.symbols;
        const apiKey = process.env.MARKETSTACK_API_KEY;
        
        if (!apiKey) {
            return res.status(500).json({ error: 'API key not configured' });
        }
        
        if (!symbols) {
            return res.status(400).json({ error: 'symbols parameter required' });
        }
        
        const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbols}`;
        const response = await fetch(url);
        const data = await response.json();
        
        if (data.error) {
            return res.status(400).json({ error: data.error.message });
        }
        
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch stock quotes' });
    }
});

app.listen(PORT, () => {
    console.log(`🚀 FIRECalc API Proxy running on port ${PORT}`);
});
EOF
```

Press Enter.

#### 1.5 - Create `.env` file (this stores your API key)

```bash
cat > .env << 'EOF'
MARKETSTACK_API_KEY=paste_your_actual_api_key_here
EOF
```

**IMPORTANT:** Open the `.env` file and replace `paste_your_actual_api_key_here` with your real Marketstack API key.

```bash
open .env
```

This opens the file in TextEdit. Replace the placeholder, save, and close.

#### 1.6 - Install dependencies

```bash
npm install
```

This downloads all the libraries you need. Takes about 30 seconds.

#### 1.7 - Test it!

```bash
npm start
```

You should see:
```
🚀 FIRECalc API Proxy running on port 3000
```

**Leave this terminal window open!** Your backend is now running.

#### 1.8 - Test in your browser

Open Safari and go to:
```
http://localhost:3000
```

You should see:
```json
{"status":"FIRECalc API Proxy Running"}
```

Try fetching a stock quote:
```
http://localhost:3000/api/quote/AAPL
```

You should see real stock data!

**🎉 Your backend is working!**

---

## Step 2: Deploy Your Backend to the Internet

Right now your backend only works on your Mac. We need to put it on the internet so your iPhone app can use it.

### 2.1 - Create a GitHub repo

In Terminal (open a NEW terminal window, don't close the one running your server):

```bash
cd ~/Documents/firecalc-backend

# Create .gitignore file
cat > .gitignore << 'EOF'
node_modules/
.env
*.log
EOF

# Initialize git
git init
git add .
git commit -m "Initial backend for FIRECalc"
```

Now go to https://github.com and:
1. Click the **"+"** button (top right)
2. Click **"New repository"**
3. Name it: `firecalc-backend`
4. Make it **Private** (important!)
5. Click **"Create repository"**

GitHub will show you commands. Copy the ones that look like:

```bash
git remote add origin https://github.com/YOUR-USERNAME/firecalc-backend.git
git branch -M main
git push -u origin main
```

Paste them in Terminal and press Enter.

**Your code is now on GitHub!**

### 2.2 - Deploy to Render.com (FREE!)

1. **Go to:** https://render.com
2. Click **"Get Started"** (create an account with GitHub)
3. After signing in, click **"New +"** (top right)
4. Click **"Web Service"**
5. Click **"Connect GitHub"**
6. Find your `firecalc-backend` repo and click **"Connect"**

7. **Fill in these settings:**
   - **Name:** `firecalc-proxy` (or whatever you want)
   - **Region:** Pick one close to you
   - **Branch:** `main`
   - **Runtime:** `Node`
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
   - **Instance Type:** `Free`

8. **Add Environment Variable:**
   - Click **"Advanced"**
   - Click **"Add Environment Variable"**
   - **Key:** `MARKETSTACK_API_KEY`
   - **Value:** Paste your actual Marketstack API key
   - Click **"Add"**

9. Click **"Create Web Service"**

**Wait 2-3 minutes** for deployment. You'll see logs scrolling by.

When you see:
```
🚀 FIRECalc API Proxy running on port 10000
```

Your backend is LIVE! 🎉

### 2.3 - Get your URL

At the top of the Render page, you'll see something like:
```
https://firecalc-proxy.onrender.com
```

**Copy this URL!** This is your backend's address on the internet.

### 2.4 - Test it!

In your browser, go to:
```
https://firecalc-proxy.onrender.com
```

You should see:
```json
{"status":"FIRECalc API Proxy Running"}
```

Try a stock quote:
```
https://firecalc-proxy.onrender.com/api/quote/AAPL
```

**If you see stock data, you're done with the backend!** 🚀

---

## Step 3: Connect Your iOS App

Now we need to tell your iPhone app to use your backend instead of calling Marketstack directly.

### 3.1 - Update `MarketstackConfig.swift`

In Xcode, open `MarketstackConfig.swift` and find this line (line 18):

```swift
private let backendURL = "https://your-backend-url.onrender.com"
```

Replace it with your ACTUAL Render URL:

```swift
private let backendURL = "https://firecalc-proxy.onrender.com"
```

(Use whatever URL Render gave you)

### 3.2 - Update `MarketstackService.swift`

Open the file `HOW_TO_UPDATE_SERVICE.md` I created for you.

Follow the instructions to update two methods in `MarketstackService.swift`.

### 3.3 - Build and Test!

1. Press `Command + B` to build
2. Run your app in the Simulator
3. Try refreshing your portfolio

Look at the Xcode console. You should see:
```
🔐 MarketstackConfig initialized - using secure backend proxy
✅ Received quote from backend for AAPL: $150.25
```

**If you see that, you're done!** ✅

---

## 🎉 Summary

**What you just did:**
1. Created a Node.js backend on your Mac
2. Put your Marketstack API key in the backend
3. Deployed the backend to Render.com (free!)
4. Updated your iOS app to use the backend

**What happens now:**
- iPhone app → Your backend → Marketstack API
- API key stays safe on your server
- Apple can't see your API key in the app
- You can rotate keys anytime by updating Render environment variables

**For App Store:**
- ✅ No hardcoded API keys
- ✅ HTTPS only (no ATS issues)
- ✅ Production-ready security
- ✅ Ready to submit!

---

## 🚨 Troubleshooting

**"Command not found: npm"**
You need to install Node.js:
1. Go to https://nodejs.org
2. Download and install the LTS version
3. Restart Terminal
4. Try again

**"Port 3000 already in use"**
Something else is using that port. Kill it:
```bash
lsof -ti:3000 | xargs kill
```

**Backend works locally but not on Render**
- Check Render logs (click "Logs" tab)
- Make sure you added the `MARKETSTACK_API_KEY` environment variable
- Make sure it's the correct key (no spaces or quotes)

**iOS app can't connect to backend**
- Make sure the `backendURL` in `MarketstackConfig.swift` is correct
- Make sure you're using `https://` not `http://`
- Check that your backend is actually running on Render (visit the URL in Safari)

---

## Need Help?

If you get stuck on any step, let me know which step number you're on and what error you're seeing!
