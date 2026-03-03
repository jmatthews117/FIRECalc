# 🔄 Switching to Marketstack Test Service in Your Portfolio

## ✅ Setup Complete!

I've integrated the Marketstack Test Service into your portfolio price updates. You can now easily toggle between live Yahoo Finance data and mock Marketstack test data.

---

## 🎛️ How to Use

### Option 1: Quick Toggle (Add to Your Settings)

Add the compact toggle to your existing settings view:

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Price Data") {
                PriceServiceToggleCompact()
            }
            
            // Your other settings...
        }
    }
}
```

### Option 2: Full Settings Page

Create a dedicated price service settings page:

```swift
NavigationLink("Price Service Settings") {
    PriceServiceToggle()
}
```

### Option 3: Programmatic Toggle

Toggle directly in code:

```swift
// Enable test mode (mock data)
AlternativePriceService.useMarketstackTest = true

// Disable test mode (live Yahoo data)
AlternativePriceService.useMarketstackTest = false
```

---

## 🧪 Testing Your Portfolio with Mock Data

### Step 1: Enable Test Mode

Add this somewhere in your app (like a debug menu or settings):

```swift
Button("Enable Test Mode") {
    AlternativePriceService.useMarketstackTest = true
    print("🧪 Switched to test mode!")
}
```

### Step 2: Refresh Portfolio Prices

Go to your portfolio view and pull to refresh (or tap the refresh button). Your portfolio will now update using **mock test data** from Marketstack Test Service!

### Step 3: Verify

Check the console logs. You should see:
```
🧪 MARKETSTACK TEST MODE ENABLED
Using mock data from MarketstackTestService
🧪 [TEST] API Call #1: fetchQuote(AAPL)
✅ Mock response: $181.25
```

### Step 4: Check API Usage

After refreshing, check how many mock API calls were made:

```swift
Task {
    let count = await MarketstackTestService.shared.getCallCount()
    print("Used \(count) mock API calls")
}
```

---

## 📊 What Happens

When **test mode is ENABLED** (`useMarketstackTest = true`):
- ✅ Portfolio price updates use **mock test data**
- ✅ Tracks API call count
- ✅ Returns consistent test prices:
  - AAPL: $181.25
  - MSFT: $418.75
  - BTC: $68,500
  - etc.
- ✅ **No real network calls**
- ✅ **No API costs**

When **test mode is DISABLED** (`useMarketstackTest = false`):
- ✅ Portfolio uses **live Yahoo Finance data**
- ✅ Real-time market prices
- ✅ Free and unlimited
- ✅ Your current production behavior

---

## 🎯 Example Integration

Here's a complete example showing where to add the toggle:

```swift
struct ContentView: View {
    @StateObject private var portfolioVM = PortfolioViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                // Your portfolio UI
                PortfolioListView(viewModel: portfolioVM)
                
                // Add this at the bottom or in a menu
                if isDevelopmentMode {
                    HStack {
                        Image(systemName: "flask.fill")
                            .foregroundColor(.orange)
                        Text("Test Mode Active")
                            .font(.caption)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh Prices") {
                            Task {
                                await portfolioVM.refreshPrices()
                            }
                        }
                        
                        Divider()
                        
                        Button("Toggle Test Mode") {
                            AlternativePriceService.useMarketstackTest.toggle()
                        }
                        
                        NavigationLink("Test Service UI") {
                            MarketstackTestView()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    var isDevelopmentMode: Bool {
        AlternativePriceService.useMarketstackTest
    }
}
```

---

## 🔍 Verifying It's Working

### Console Output (Test Mode ON)

When you refresh prices with test mode enabled, you'll see:

```
🔄 REFRESH PRICES STARTED
📊 Total assets in portfolio: 5
🎯 Assets with tickers: 5

🧪 MARKETSTACK TEST MODE ENABLED
Using mock data from MarketstackTestService

🧪 [TEST] API Call #1: fetchQuote(AAPL)
   ✅ Mock response: $181.25

🧪 [TEST] API Call #2: fetchQuote(MSFT)
   ✅ Mock response: $418.75

✅ Successful updates: 5
📊 Total mock API calls this session: 2
```

### Console Output (Test Mode OFF)

With test mode disabled, you'll see Yahoo Finance calls:

```
🔄 REFRESH PRICES STARTED
📡 Fetching AAPL from Yahoo Finance
✅ Got quote for AAPL: $182.50
```

---

## 📱 User Experience

Your users won't see any difference in the UI! The portfolio will show updated prices either way. The only difference is:
- **Test Mode**: Shows hardcoded mock prices
- **Live Mode**: Shows real market prices

---

## 🎛️ Quick Access Toggle

For easy testing, you might want to add this to your main portfolio view:

```swift
// At the top of your portfolio view
@State private var showTestToggle = true  // Set to false for production

// In your view body
if showTestToggle {
    HStack {
        Text("Price Source:")
            .font(.caption)
        
        Button(AlternativePriceService.useMarketstackTest ? "🧪 Test" : "📡 Live") {
            AlternativePriceService.useMarketstackTest.toggle()
        }
        .font(.caption)
        .buttonStyle(.bordered)
    }
}
```

---

## ✅ Testing Checklist

Before moving to Phase 2, test with your portfolio:

- [ ] Enable test mode
- [ ] Refresh portfolio prices
- [ ] Verify prices update to mock values
- [ ] Check console logs show "🧪 MARKETSTACK TEST MODE"
- [ ] Note the API call count
- [ ] Test with different asset types (stocks, crypto, ETFs)
- [ ] Verify batch processing works
- [ ] Calculate your estimated monthly API usage
- [ ] Disable test mode and verify Yahoo still works

---

## 🚀 What's Next?

Once you've verified everything works with test data:

1. **Calculate your API usage** based on the mock call counter
2. **Decide on Marketstack tier** (free vs paid)
3. **Get your API key** from Marketstack
4. **Let me know** and I'll build Phase 2 (real API integration)

---

## 💡 Pro Tips

### Estimate Your Costs

After a full portfolio refresh in test mode:

```swift
Task {
    let calls = await MarketstackTestService.shared.getCallCount()
    print("Portfolio refresh used \(calls) API calls")
    
    // If you refresh 3 times per day:
    let dailyCalls = calls * 3
    let monthlyCalls = dailyCalls * 30
    print("Estimated monthly usage: \(monthlyCalls) calls")
    
    // Compare to Marketstack limits:
    // Free: 100 calls/month
    // Basic: 10,000 calls/month ($9)
    // Professional: 50,000 calls/month ($49)
}
```

### Keep It Simple

For development, just toggle at app launch:

```swift
init() {
    // DEVELOPMENT: Use test data
    #if DEBUG
    AlternativePriceService.useMarketstackTest = true
    #endif
    
    // PRODUCTION: Use live data
}
```

---

## 📞 Questions?

Everything is set up! You can now:
- Toggle between test and live data anytime
- Test your portfolio with mock Marketstack prices
- Track API usage with the counter
- Verify the integration works perfectly

Let me know when you've tested it and are ready for Phase 2! 🎉
