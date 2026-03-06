# FIRECalc Backend Proxy

Secure API proxy for the FIRECalc iOS app. This backend keeps your Marketstack API key safe on the server and provides HTTPS endpoints for your mobile app.

## 🚀 Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and add your Marketstack API key:

```
MARKETSTACK_API_KEY=your_actual_api_key_here
```

### 3. Run Locally

```bash
npm start
```

Visit http://localhost:3000 to verify it's running.

### 4. Test Endpoints

```bash
# Health check
curl http://localhost:3000/

# Single quote
curl http://localhost:3000/api/quote/AAPL

# Batch quotes
curl "http://localhost:3000/api/quotes?symbols=AAPL,MSFT,GOOGL"
```

## 📡 API Endpoints

### `GET /`
Health check endpoint

**Response:**
```json
{
  "status": "online",
  "service": "FIRECalc API Proxy",
  "version": "1.0.0"
}
```

### `GET /api/quote/:symbol`
Get a single stock quote

**Example:** `/api/quote/AAPL`

**Response:**
```json
{
  "pagination": { ... },
  "data": [
    {
      "symbol": "AAPL",
      "date": "2026-03-05",
      "open": 150.5,
      "high": 152.0,
      "low": 149.5,
      "close": 151.25,
      "volume": 50000000
    }
  ]
}
```

### `GET /api/quotes?symbols=AAPL,MSFT,GOOGL`
Get multiple stock quotes in one request

**Response:**
```json
{
  "pagination": { ... },
  "data": [
    { "symbol": "AAPL", ... },
    { "symbol": "MSFT", ... },
    { "symbol": "GOOGL", ... }
  ]
}
```

## 🌐 Deploy to Render.com (Free)

1. **Push to GitHub:**
   ```bash
   git init
   git add .
   git commit -m "Initial backend"
   git push origin main
   ```

2. **Deploy on Render:**
   - Go to https://render.com
   - Click "New +" → "Web Service"
   - Connect your GitHub repo
   - Settings:
     - **Name:** firecalc-proxy
     - **Environment:** Node
     - **Build Command:** `npm install`
     - **Start Command:** `npm start`
   - Environment Variables:
     - `MARKETSTACK_API_KEY` = your API key
   - Click "Create Web Service"

3. **Your API will be live at:** `https://firecalc-proxy.onrender.com`

## 🔒 Security Features

- ✅ API key stored securely on server
- ✅ HTTPS only (when deployed)
- ✅ Rate limiting (100 requests per 15 minutes per IP)
- ✅ CORS enabled for mobile apps
- ✅ Input validation
- ✅ Error handling

## 📊 Monitoring

Check Render logs for:
- Request logs
- Error messages
- API usage

## 🛠️ Development

```bash
# Run with auto-reload
npm run dev

# Test locally
npm test
```

## 📝 License

MIT
