# Quick Subscription Testing Checklist

## ✅ Pre-Test Setup
- [ ] StoreKit Configuration file exists with both products
- [ ] Edit Scheme → Run → Options → StoreKit Configuration is selected
- [ ] Build the app

## 🧪 Test Flow

### 1. Before Purchase
- [ ] Settings → Debug Info shows "Pro Subscriber: ❌ NO"
- [ ] Portfolio → + → Stocks → Ticker section shows 🔒 "Pro Only"
- [ ] Dashboard portfolio card shows "🔒 Upgrade for live prices"

### 2. Purchase
- [ ] Settings → Tap "Upgrade to Pro"
- [ ] See both Monthly ($1.99) and Yearly ($19.99) options
- [ ] Tap "Start Free Trial"
- [ ] Approve purchase in StoreKit dialog
- [ ] Paywall dismisses automatically

### 3. After Purchase
- [ ] Settings → Debug Info shows "Pro Subscriber: ✅ YES"
- [ ] Settings → Debug Info shows "Status: Active: com.firecalc.pro.monthly"

### 4. Test Pro Features

#### Feature: Ticker Search
- [ ] Portfolio → Tap **+**
- [ ] Select "Stocks"
- [ ] Ticker section is **unlocked** (no lock)
- [ ] Type "AAPL"
- [ ] Name auto-fills: "Apple Inc."
- [ ] Price loads automatically

#### Feature: Portfolio Refresh
- [ ] Dashboard → Pull down on portfolio card
- [ ] See "Updating..." spinner
- [ ] Prices update (check "Updated X min ago" text)

## 🐛 If Something Goes Wrong

### Features don't unlock after purchase?
1. Check Xcode Console for errors
2. Settings → Debug Info → Tap "Refresh Subscription Status"
3. Settings → Debug Info → Tap "Check Current Entitlements"
4. Look for your product ID in console output

### Products don't show in paywall?
1. Verify StoreKit file has both products with correct IDs
2. Verify Edit Scheme has StoreKit Configuration selected
3. Clean build (Cmd+Shift+K) and rebuild

### Purchase fails silently?
1. Check console for error messages
2. Try: Editor → Clear StoreKit Transactions (in .storekit file)
3. Rebuild and try again

## 📊 Expected Console Output

### Successful Purchase:
```
🛒 Attempting to purchase: FIRECalc Pro Monthly
✅ Purchase result: success
✅ Transaction verified
✅ Transaction finished
🔄 Updating subscription status...
✅ Found active entitlement for: com.firecalc.pro.monthly
✅ User is Pro subscriber
📊 After update - isProSubscriber: true
```

### Successful Refresh Test:
```
📡 Refreshing prices for 1 assets...
✅ Loaded price for AAPL: $175.43
✅ Updated 1 prices
```

## 🎯 Success Criteria

All of these should be ✅ after purchase:
- Settings shows Pro subscriber status
- Ticker search works without lock icon
- Portfolio refresh works (pull-to-refresh)
- Dashboard shows "Pull to refresh" instead of lock
- AddAsset shows ticker fields unlocked

## 🔄 Reset for Re-testing

To test the purchase flow again:
1. Open your `.storekit` file in Xcode
2. Click **Editor** menu → **Clear StoreKit Transactions**
3. Rebuild and run the app
4. You should be back to free tier

## 📝 Notes

- StoreKit testing subscriptions **auto-renew every 5 minutes** for monthly
- You can manage/cancel test subscriptions in the StoreKit file
- Debug section only shows in Debug builds (`#if DEBUG`)
- All changes are automatically saved in `@ObservedObject` instances
