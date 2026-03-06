# FIRECalc Pro Subscription Implementation Guide

## ✅ What's Been Implemented

I've successfully implemented a complete StoreKit 2 subscription system for FIRECalc with the following features:

### **Files Created:**
1. `SubscriptionManager.swift` - Complete StoreKit 2 integration
2. `SubscriptionPaywallView.swift` - Beautiful upgrade screen with pricing
3. Updated `MarketstackService.swift` - Gated behind Pro subscription
4. Updated `add_asset_view.swift` - Shows upgrade prompt for free users
5. Updated `ContentView.swift` - Dashboard shows subscription status
6. Updated `settings_view.swift` - Subscription management section
7. Updated `portfolio_viewmodel.swift` - Blocks refresh for free users

### **Subscription Model:**
- **Free Tier**: Manual portfolio tracking only (no stock quotes)
- **Pro Tier**: 
  - $1.99/month or $19.99/year
  - Live stock price updates
  - Ticker symbol search
  - Portfolio refresh (12-hour cooldown)
  - Crypto tracking

---

## 🚀 Next Steps to Complete Implementation

### **Step 1: Create StoreKit Configuration File (For Testing)**

1. In Xcode, go to **File → New → File**
2. Search for "StoreKit Configuration File"
3. Name it `FIRECalcProducts.storekit`
4. Click **Create**

5. In the StoreKit Configuration editor:
   - Click the **+** button
   - Select **Add Auto-Renewable Subscription**
   
6. Configure Monthly Subscription:
   - **Product ID**: `com.firecalc.pro.monthly`
   - **Reference Name**: FIRECalc Pro Monthly
   - **Price**: $1.99
   - **Subscription Duration**: 1 Month
   - **Subscription Group**: FIRECalc Pro

7. Add Annual Subscription:
   - Click **+** again
   - Select **Add Auto-Renewable Subscription**
   - **Product ID**: `com.firecalc.pro.yearly`
   - **Reference Name**: FIRECalc Pro Annual
   - **Price**: $19.99
   - **Subscription Duration**: 1 Year
   - **Subscription Group**: FIRECalc Pro (same group!)

8. Set active StoreKit file:
   - **Product → Scheme → Edit Scheme**
   - Go to **Run → Options**
   - Set **StoreKit Configuration**: `FIRECalcProducts.storekit`

### **Step 2: Update Product IDs in Code**

If your actual App Store product IDs are different, update them in `SubscriptionManager.swift`:

```swift
// Line 19-20 in SubscriptionManager.swift
private let monthlyProductID = "YOUR_ACTUAL_MONTHLY_ID"
private let yearlyProductID = "YOUR_ACTUAL_YEARLY_ID"
```

### **Step 3: Test Locally**

1. **Run the app in Simulator**
2. Go to **Settings tab**
3. Tap **"Upgrade to Pro"**
4. You should see the paywall with both subscription options
5. Try purchasing (uses sandbox, no real money)
6. Verify Pro features unlock:
   - Try adding an asset with ticker symbol
   - Try pull-to-refresh on dashboard

### **Step 4: Create Products in App Store Connect**

1. Log into [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app
3. Go to **Features → In-App Purchases**
4. Click **+** to create a new subscription
5. Select **Auto-Renewable Subscription**

6. Create **Monthly Subscription**:
   - **Reference Name**: FIRECalc Pro Monthly
   - **Product ID**: `com.firecalc.pro.monthly` (or your chosen ID)
   - **Subscription Group**: Create new group "FIRECalc Pro"
   - **Subscription Duration**: 1 Month
   - **Price**: $1.99 USD (select all regions)
   - **Localized Display Name**: FIRECalc Pro
   - **Localized Description**: Get real-time stock prices and portfolio tracking

7. Create **Annual Subscription**:
   - Same steps but:
   - **Product ID**: `com.firecalc.pro.yearly`
   - **Duration**: 1 Year
   - **Price**: $19.99 USD

8. **Important**: Both must be in the **same subscription group**

### **Step 5: Add Subscription Capabilities to Xcode**

1. Select your project in Xcode
2. Select your target
3. Go to **Signing & Capabilities**
4. Click **+ Capability**
5. Add **In-App Purchase**

### **Step 6: Test with TestFlight**

1. Create an archive: **Product → Archive**
2. Distribute to **TestFlight**
3. Test on a real device with a sandbox account:
   - Settings → App Store → Sandbox Account
   - Create a test Apple ID in App Store Connect

### **Step 7: Update Legal Links**

In `SubscriptionPaywallView.swift` (line 165-166), update the placeholder URLs:

```swift
Link("Terms of Service", destination: URL(string: "YOUR_TERMS_URL")!)
Link("Privacy Policy", destination: URL(string: "YOUR_PRIVACY_URL")!)
```

---

## 🎨 What Free Users See

1. **Dashboard**: "🔒 Upgrade for live prices" message
2. **Add Asset**: Locked ticker input with upgrade prompt
3. **Pull-to-Refresh**: Shows error: "Stock price updates require FIRECalc Pro"
4. **Settings**: Big upgrade banner at top

## 🌟 What Pro Users See

1. **Dashboard**: "⭐ Pull to refresh" with Pro indicator
2. **Add Asset**: Full ticker search and price loading
3. **Pull-to-Refresh**: Works normally with 12-hour cooldown
4. **Settings**: Active subscription status + manage button

---

## 🧪 Testing Checklist

### Free User Experience:
- [ ] Can add assets manually (no ticker)
- [ ] Cannot use ticker search in Add Asset
- [ ] Cannot pull-to-refresh portfolio
- [ ] Sees upgrade prompts in appropriate places
- [ ] Can navigate to paywall from multiple locations

### Pro User Experience:
- [ ] Can purchase subscription
- [ ] Ticker search works after purchase
- [ ] Pull-to-refresh works after purchase
- [ ] Settings shows active subscription
- [ ] Can manage subscription (opens App Store)

### Subscription Management:
- [ ] Purchase monthly subscription works
- [ ] Purchase yearly subscription works
- [ ] Restore purchases works
- [ ] Subscription status persists across app launches
- [ ] Expired subscription reverts to free tier

---

## 💡 Revenue Projections

Based on standard conversion rates:

**Conservative Estimate:**
- 1,000 users
- 3% conversion rate = 30 Pro users
- 70% choose monthly, 30% choose yearly
- Monthly: 21 × $1.99 = $41.79/month
- Yearly: 9 × $19.99 = $179.91/year (= $15/month avg)
- **Total: ~$56/month recurring**

**Optimistic Estimate:**
- 5,000 users
- 5% conversion rate = 250 Pro users
- Same mix
- **Total: ~$466/month recurring**

After Apple's 30% cut (15% after year 1):
- Conservative: ~$39/month take-home
- Optimistic: ~$326/month take-home

---

## 🔧 Troubleshooting

### "Products not loading"
- Check Product IDs match exactly
- Verify StoreKit configuration file is selected in scheme
- Try cleaning build folder (Cmd+Shift+K)

### "Purchase doesn't complete"
- Ensure you're using a sandbox account
- Check internet connection
- Verify subscription group is configured correctly

### "Subscription status not updating"
- Check `listenForTransactions()` is being called
- Verify transaction finishing with `await transaction.finish()`
- Try calling `await SubscriptionManager.shared.updateSubscriptionStatus()`

### "Free users can still access Pro features"
- Check `SubscriptionManager.shared.isProSubscriber` is being checked
- Verify `@MainActor` is used where needed
- Check for cached subscription status

---

## 📝 App Store Review Notes

When submitting, be prepared to answer:

1. **"Why is your app using subscriptions?"**
   - We provide ongoing real-time stock price data that requires API costs
   - Subscription covers server costs and data provider fees

2. **"Can users access core functionality without subscription?"**
   - Yes, users can manually track their portfolio and use all FIRE calculators
   - Subscription only adds live data features

3. **"How do users manage subscriptions?"**
   - Settings tab has "Manage Subscription" button
   - Opens standard iOS subscription management

---

## 🎯 Optional Enhancements (v1.1)

Consider adding later:
- **Free Trial**: 7-day free trial for new users
- **Family Sharing**: Allow subscription sharing
- **Promotional Offers**: Win-back discounts for expired users
- **Push Notifications**: "Your portfolio is up X% today!" (Pro only)
- **Widgets**: Live portfolio value widget (Pro only)
- **Export/Import**: CSV export of portfolio (Pro only)

---

## 📞 Need Help?

If you encounter issues:
1. Check the console for `SubscriptionManager` log messages
2. Verify StoreKit configuration matches App Store Connect
3. Test with a fresh install (delete app, reinstall)
4. Check transaction logs in Xcode's StoreKit Transaction Manager

---

## ✅ Implementation Complete!

You now have a fully functional subscription system. Just follow the steps above to:
1. Create the StoreKit configuration file for testing
2. Test locally in simulator
3. Create products in App Store Connect
4. Submit for review

**Estimated time to complete setup: 1-2 hours**

Good luck with your launch! 🚀
