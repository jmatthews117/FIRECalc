# 🎯 Marketstack Crypto Quick Reference

## Ticker Formats at a Glance

| What User Enters | What's Stored | What's Sent to Marketstack |
|-----------------|---------------|---------------------------|
| BTC | BTC | BTCUSD |
| ETH | ETH | ETHUSD |
| LTC | LTC | LTCUSD |
| BCH | BCH | BCHUSD |
| XRP | XRP | XRPUSD |
| ADA | ADA | ADAUSD |

**Key Rule:** NO DASHES! `BTCUSD` not `BTC-USD`

---

## Supported Crypto Input Formats

All of these work (app converts automatically):

✅ `BTC` → Converted to `BTCUSD`  
✅ `BTC-USD` → Converted to `BTCUSD`  
✅ `BTCUSD` → Stays as `BTCUSD`  
✅ `btc` → Uppercased to `BTC`, then `BTCUSD`  
✅ ` BTC ` → Trimmed and converted to `BTCUSD`

---

## Current Behavior (Free Tier)

```
User adds BTC
    ↓
App accepts it ✅
    ↓
Shows fallback price (hardcoded) ✅
    ↓
On refresh: Shows error ⚠️
    "Crypto requires paid plan"
```

---

## After Paid Upgrade

```
User adds BTC
    ↓
App accepts it ✅
    ↓
Fetches live price from Marketstack ✅
    ↓
On refresh: Updates with latest price ✅
```

---

## Error Messages

### Free Tier
```
"Cryptocurrency data requires a paid Marketstack plan 
(Standard tier or above, starting at $79.99/month). 
The free tier does not include cryptocurrency quotes. 
Visit marketstack.com/product to upgrade."
```

### Invalid Ticker
```
"Invalid ticker symbol: INVALIDCRYPTO"
```

### API Error
```
"HTTP error: 403. Service may be temporarily unavailable."
```

---

## Testing Commands

### Test on Free Tier (Should Fail Gracefully)
```swift
Task {
    do {
        let service = MarketstackService.shared
        let quote = try await service.fetchCryptoQuote(symbol: "BTC")
        print("Unexpected success: \(quote.latestPrice)")
    } catch MarketstackError.cryptoNotSupported {
        print("✅ Expected error - crypto not available on free tier")
    } catch {
        print("❌ Unexpected error: \(error)")
    }
}
```

### Test After Paid Upgrade
```swift
Task {
    let service = MarketstackService.shared
    
    // Test Bitcoin
    let btc = try await service.fetchCryptoQuote(symbol: "BTC")
    print("BTC: $\(btc.latestPrice)")
    
    // Test Ethereum
    let eth = try await service.fetchCryptoQuote(symbol: "ETH")
    print("ETH: $\(eth.latestPrice)")
    
    // Test with different formats
    let btc2 = try await service.fetchCryptoQuote(symbol: "BTC-USD")
    print("BTC (alt format): $\(btc2.latestPrice)")
}
```

---

## API Endpoints

### Stock/Crypto Endpoint (EOD - End of Day)
```
GET http://api.marketstack.com/v1/eod/latest
    ?access_key=YOUR_KEY
    &symbols=BTCUSD,ETHUSD,AAPL,MSFT
```

**Note:** Crypto and stocks use the SAME endpoint on Marketstack!

### Response Format
```json
{
  "data": [
    {
      "symbol": "BTCUSD",
      "date": "2024-03-15",
      "close": 42500.00,
      "open": 42000.00,
      "high": 43000.00,
      "low": 41800.00,
      "volume": 12345678,
      "exchange": "CRYPTO"
    }
  ]
}
```

---

## Marketstack Plan Comparison

| Feature | Free | Standard ($79.99/mo) | Professional ($199.99/mo) |
|---------|------|---------------------|---------------------------|
| Crypto Quotes | ❌ | ✅ 70+ coins | ✅ 70+ coins |
| API Calls | 100/mo | 10,000/mo | 100,000/mo |
| Stock Data | ✅ US only | ✅ Multiple exchanges | ✅ Multiple exchanges |
| Data Type | EOD | EOD + Intraday | EOD + Real-time |
| HTTPS | ❌ | ✅ | ✅ |

---

## Common Cryptos Supported

### Top 10
- Bitcoin (BTC)
- Ethereum (ETH)
- Tether (USDT)
- Binance Coin (BNB)
- USD Coin (USDC)
- XRP (XRP)
- Cardano (ADA)
- Dogecoin (DOGE)
- Polygon (MATIC)
- Solana (SOL)

### Others
- Polkadot (DOT)
- Litecoin (LTC)
- Bitcoin Cash (BCH)
- Chainlink (LINK)
- Stellar (XLM)
- ...and 55+ more!

---

## Cache Behavior

| Action | Cache Duration | API Calls |
|--------|---------------|-----------|
| Add new crypto asset | 5 min (bypass cache) | 1 call |
| Refresh portfolio | 12 hours | 0 calls (if within window) |
| Refresh portfolio | After 12 hours | 1 call (batch) |
| Individual crypto lookup | 12 hours | Use cache if available |

---

## Upgrade Checklist

**Before Upgrade:**
- [x] Code is ready (already done!)
- [ ] Review pricing options
- [ ] Estimate API usage needs
- [ ] Plan testing approach

**During Upgrade:**
- [ ] Purchase plan at marketstack.com
- [ ] Get new API key
- [ ] Update API key in remote config

**After Upgrade:**
- [ ] Test BTC price fetch
- [ ] Test ETH price fetch
- [ ] Test batch fetching
- [ ] Monitor API usage
- [ ] Verify caching works
- [ ] Check cooldown behavior

---

## Troubleshooting

### "Crypto ticker 'BTCUSD' not found"
**Cause:** Free tier doesn't support crypto  
**Fix:** Upgrade to Standard plan

### "Invalid ticker symbol: BTC-USD"
**Cause:** Shouldn't happen (app auto-converts)  
**Fix:** Check ticker cleaning logic

### Stale crypto prices
**Cause:** 12-hour cache too long  
**Fix:** Manually clear cache or adjust duration

### Too many API calls
**Cause:** Individual fetches instead of batch  
**Fix:** Use batch fetching (already implemented)

---

## Quick Console Log Reference

### What You'll See (Free Tier)
```
🪙 fetchCryptoQuote called for: 'BTC' → cleaned: 'BTC'
🪙 Marketstack crypto ticker: 'BTCUSD'
📝 Note: Crypto data requires paid Marketstack plan
📡 API call for BTCUSD in fetchQuote
❌ Crypto ticker 'BTCUSD' not found
   This usually means:
   1. You're on the free tier
   2. The ticker format is incorrect
   3. The cryptocurrency isn't supported
```

### What You'll See (Paid Tier)
```
🪙 fetchCryptoQuote called for: 'BTC' → cleaned: 'BTC'
🪙 Marketstack crypto ticker: 'BTCUSD'
📡 API call for BTCUSD in fetchQuote
📡 Marketstack response for BTCUSD: HTTP 200
📊 Marketstack data for BTCUSD:
   Symbol: BTCUSD
   Close: $42500.00
   Date: 2024-03-15
✅ Got quote for BTCUSD: $42500.00
```

---

## Code Snippets

### Add Crypto Asset
```swift
let bitcoin = Asset(
    name: "Bitcoin",
    assetClass: .crypto,
    ticker: "BTC",        // Just "BTC" - app handles conversion
    quantity: 0.5,
    unitValue: 42500.00
)
```

### Fetch Crypto Price
```swift
let service = AlternativePriceService.shared
let asset = // your crypto asset

do {
    let price = try await service.fetchPrice(
        for: asset,
        bypassCooldown: true  // For adding new assets
    )
    print("Current price: $\(price)")
} catch PriceServiceError.cryptoRequiresPaidPlan {
    print("Need to upgrade Marketstack plan")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

### Batch Fetch Multiple Cryptos
```swift
let tickers = ["BTCUSD", "ETHUSD", "LTCUSD"]
let quotes = try await MarketstackService.shared.fetchBatchQuotes(
    tickers: tickers
)
for (ticker, quote) in quotes {
    print("\(ticker): $\(quote.latestPrice)")
}
```

---

## Files to Review

1. **MarketstackService.swift** - Core crypto fetching logic
2. **AlternativePriceService.swift** - Price service routing
3. **MARKETSTACK_CRYPTO_GUIDE.md** - Full documentation
4. **CRYPTO_IMPLEMENTATION_SUMMARY.md** - Change summary

---

## Key Contacts & Links

- **Marketstack Pricing:** https://marketstack.com/product
- **Crypto Docs:** https://marketstack.com/documentation#cryptocurrencies
- **Support:** support@marketstack.com
- **API Status:** https://status.marketstack.com

---

## Remember

✅ **Crypto ticker format:** `BTCUSD` (no dash)  
✅ **User input:** Just `BTC` (app converts)  
✅ **Free tier:** Crypto not supported  
✅ **Paid tier:** 70+ cryptos available  
✅ **Code ready:** Zero changes needed after upgrade!

---

**Ready to upgrade? Just update your API key and you're all set! 🚀**
