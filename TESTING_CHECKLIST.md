# Quick Testing Checklist for FIRECalc Pro Subscription

## Before You Start
- [ ] StoreKit configuration file created (`FIRECalcProducts.storekit`)
- [ ] Product IDs set correctly in `SubscriptionManager.swift`
- [ ] StoreKit file selected in Edit Scheme → Run → Options
- [ ] App compiles without errors

---

## Test 1: Free User Experience (No Purchase)

### Dashboard
1. Launch app
2. Add a manual asset (Cash or Real Estate)
3. Try pull-to-refresh
   - ✅ Should show error: "Stock price updates require FIRECalc Pro"
4. Check bottom of portfolio card
   - ✅ Should show: "🔒 Upgrade for live prices"

### Add Asset View
1. Tap + to add asset
2. Select "Stocks" or "Crypto"
3. Look at ticker section
   - ✅ Should show locked upgrade prompt
   - ✅ Should NOT show ticker input field
   - ✅ Should show "Upgrade to Pro" button with pricing

### Settings
1. Go to Settings tab
2. Check top of screen
   - ✅ Should show upgrade banner with "Upgrade to Pro"
   - ✅ Should show pricing: $1.99/mo or $19.99/yr

---

## Test 2: Paywall Display

1. Tap "Upgrade to Pro" from Settings
2. Paywall should show:
   - ✅ Large icon at top
   - ✅ "FIRECalc Pro" title
   - ✅ 4 feature cards (Live Prices, Refresh, Real-Time Values, Ticker Search)
   - ✅ Two subscription options (Monthly & Annual)
   - ✅ Annual shows "Save 17%" badge
   - ✅ Monthly selected by default
   - ✅ Blue "Subscribe for $1.99" button
   - ✅ "Restore Purchases" button
   - ✅ Terms and Privacy links at bottom

---

## Test 3: Purchase Flow (Sandbox)

### Set Up Sandbox
1. Settings app → App Store
2. Scroll to Sandbox Account
3. Sign in with test Apple ID (create in App Store Connect if needed)

### Make Purchase
1. In FIRECalc, go to Settings → Upgrade to Pro
2. Select Monthly plan ($1.99)
3. Tap "Subscribe for $1.99"
4. Sandbox purchase dialog appears
   - ✅ Shows correct price
   - ✅ Shows "[Sandbox Environment]" at top
5. Confirm purchase
6. Paywall dismisses
7. Settings now shows:
   - ✅ "✅ FIRECalc Pro"
   - ✅ "Pro (Monthly) • Renews [date]"
   - ✅ "Manage Subscription" button

---

## Test 4: Pro User Features

### After Purchase:

1. **Dashboard**
   - ✅ Shows "⭐ Pull to refresh" (not locked)
   - Pull to refresh should work (if assets have tickers)

2. **Add Asset**
   - Select Stocks
   - ✅ Ticker input field is visible (not locked)
   - Enter "AAPL"
   - Tap "Load Price for AAPL"
   - ✅ Price loads successfully
   - ✅ Shows "APPLE INC • $XXX.XX"

3. **Settings**
   - ✅ Shows active subscription status
   - Tap "Manage Subscription"
   - ✅ Opens App Store subscription management

---

## Test 5: Subscription Persistence

1. Force quit the app (swipe up in app switcher)
2. Relaunch app
3. ✅ Should still be Pro subscriber
4. ✅ All Pro features still work
5. ✅ Settings still shows active subscription

---

## Test 6: Restore Purchases

1. In simulator: **Product → Manage Transactions** (StoreKit Transaction Manager)
2. Delete all transactions
3. App should revert to free tier
4. Go to Settings → Upgrade to Pro
5. Tap "Restore Purchases"
6. ✅ Should restore to Pro status
7. ✅ Paywall dismisses
8. ✅ Pro features work again

---

## Test 7: Expired Subscription

1. In simulator: **Product → Manage Transactions**
2. Find your subscription
3. Click "Refund" or change expiration date to past
4. Wait 5 seconds for status to update
5. ✅ App should revert to free tier
6. ✅ Settings shows "Subscription Expired"
7. ✅ Dashboard shows locked features again
8. ✅ Add Asset shows upgrade prompt

---

## Test 8: Error Handling

### Network Error
1. Enable Airplane Mode
2. Try to purchase subscription
3. ✅ Should show error: "Purchase failed. Please try again."
4. Disable Airplane Mode

### Cancelled Purchase
1. Start purchase flow
2. Click "Cancel" in payment dialog
3. ✅ Paywall stays open (doesn't dismiss)
4. ✅ No error message shown
5. ✅ Can try again

---

## Test 9: Annual Subscription

1. Go to Settings → Upgrade to Pro
2. Select **Annual Plan** ($19.99)
3. Verify:
   - ✅ "Save 17%" badge visible
   - ✅ "Just $1.67 per month" subtext
   - ✅ Blue ring around selected plan
4. Tap "Subscribe for $19.99"
5. Complete sandbox purchase
6. ✅ Settings shows "Pro (Annual) • Renews [date]"

---

## Common Issues & Fixes

### Products Not Loading
- **Symptom**: Paywall shows spinning loader forever
- **Fix**: 
  1. Check Product IDs in `SubscriptionManager.swift` match StoreKit config
  2. Verify StoreKit config selected in scheme
  3. Clean build (Cmd+Shift+K) and rebuild

### "Purchase Failed" Error
- **Symptom**: All purchases fail immediately
- **Fix**:
  1. Check sandbox account is signed in
  2. Verify internet connection
  3. Check console for error messages

### Subscription Status Not Updating
- **Symptom**: Purchase completes but features stay locked
- **Fix**:
  1. Check console for "✅ Active subscription" message
  2. Force quit and relaunch app
  3. Verify `isProSubscriber` is being checked correctly

### Free Features Still Accessible After Expiry
- **Symptom**: Expired subscription still has access
- **Fix**:
  1. Verify `SubscriptionManager.shared.isProSubscriber` checks
  2. Check transaction listener is running
  3. Manually call `await SubscriptionManager.shared.updateSubscriptionStatus()`

---

## Console Messages to Look For

### Successful Purchase:
```
✅ Loaded 2 subscription products
✅ Purchase successful: FIRECalc Pro Monthly
✅ Active subscription: com.firecalc.pro.monthly
```

### Free User Attempting Refresh:
```
🚫 Free tier - stock quotes disabled
Stock price updates require FIRECalc Pro. Upgrade to access live portfolio tracking.
```

### Pro User Refresh:
```
✅ Pro user - No previous refresh - allowing API call
📡 Fetching quotes for: [AAPL, MSFT]
```

---

## Ready for TestFlight?

Once all above tests pass:
- [ ] All free features work as expected
- [ ] Paywall displays correctly
- [ ] Both subscriptions purchasable
- [ ] Pro features unlock after purchase
- [ ] Subscription persists across launches
- [ ] Restore purchases works
- [ ] Expired subscriptions revert properly

✅ **You're ready to create an archive and test on real devices via TestFlight!**

---

## Quick Command Reference

### Clean Build
```
Cmd + Shift + K
```

### Show StoreKit Transaction Manager
```
Product → Manage Transactions
```

### View Console Logs
```
Cmd + Shift + Y (toggle debug area)
```

### Reset Simulator
```
Device → Erase All Content and Settings
```
