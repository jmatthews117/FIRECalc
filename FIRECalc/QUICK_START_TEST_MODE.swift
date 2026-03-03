//
//  QUICK_START_TEST_MODE.swift
//  FIRECalc
//
//  Copy these code snippets to enable test mode in your app
//

import SwiftUI

// ═══════════════════════════════════════════════════════════════════════
// OPTION 1: Add to Your Existing Settings View
// ═══════════════════════════════════════════════════════════════════════

/*
 In settings_view.swift, add this section anywhere in your Form:

struct SettingsView: View {
    var body: some View {
        Form {
            // Your existing sections...
            
            // ADD THIS SECTION:
            Section {
                PriceServiceToggleCompact()
            } header: {
                Text("Price Data Source")
            } footer: {
                if AlternativePriceService.useMarketstackTest {
                    Text("Test mode uses mock data. Perfect for Phase 1 testing without API costs.")
                } else {
                    Text("Live mode fetches real prices from Yahoo Finance.")
                }
            }
            
            // Your other sections...
        }
    }
}

That's it! Users can now toggle test mode in settings.
*/

// ═══════════════════════════════════════════════════════════════════════
// OPTION 2: Quick Debug Menu (Fastest for Testing)
// ═══════════════════════════════════════════════════════════════════════

/*
 Add this to ANY view where you want quick access:

struct YourPortfolioView: View {
    var body: some View {
        VStack {
            // Your portfolio UI
            
            // ADD THIS for quick testing:
            #if DEBUG
            HStack {
                Text("Test Mode:")
                Button(AlternativePriceService.useMarketstackTest ? "ON 🧪" : "OFF 📡") {
                    AlternativePriceService.useMarketstackTest.toggle()
                }
                .buttonStyle(.bordered)
                .tint(AlternativePriceService.useMarketstackTest ? .orange : .green)
            }
            .font(.caption)
            .padding()
            #endif
        }
    }
}
*/

// ═══════════════════════════════════════════════════════════════════════
// OPTION 3: Enable at App Launch (Simplest!)
// ═══════════════════════════════════════════════════════════════════════

/*
 In your App file or wherever you initialize PortfolioViewModel:

@main
struct FIRECalcApp: App {
    
    init() {
        // ENABLE TEST MODE ON APP LAUNCH
        AlternativePriceService.useMarketstackTest = true
        print("🧪 App launched in TEST MODE - using mock Marketstack data")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

Then just use your app normally! Portfolio updates will use test data.
*/

// ═══════════════════════════════════════════════════════════════════════
// OPTION 4: Add Menu Item to Portfolio View
// ═══════════════════════════════════════════════════════════════════════

/*
 Add this toolbar menu to your portfolio view:

.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Menu {
            Button {
                Task {
                    await portfolioVM.refreshPrices()
                }
            } label: {
                Label("Refresh Prices", systemImage: "arrow.clockwise")
            }
            
            Divider()
            
            // ADD THIS:
            Button {
                AlternativePriceService.useMarketstackTest.toggle()
            } label: {
                if AlternativePriceService.useMarketstackTest {
                    Label("Switch to Live Data", systemImage: "wifi")
                } else {
                    Label("Switch to Test Data", systemImage: "flask")
                }
            }
            
            // Optional: Direct link to test UI
            NavigationLink {
                MarketstackTestView()
            } label: {
                Label("Test Service", systemImage: "wrench.and.screwdriver")
            }
            
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
*/

// ═══════════════════════════════════════════════════════════════════════
// 🎯 RECOMMENDATION: Use Option 3 for Now
// ═══════════════════════════════════════════════════════════════════════

/*
 For Phase 1 testing, I recommend Option 3:
 
 1. Just add this line when your app launches:
    AlternativePriceService.useMarketstackTest = true
 
 2. Run your app
 
 3. Go to your portfolio and refresh prices
 
 4. Check the console - you'll see:
    🧪 MARKETSTACK TEST MODE ENABLED
    🧪 [TEST] API Call #1: fetchQuote(AAPL)
    ✅ Mock response: $181.25
 
 5. Your portfolio will show the mock prices!
 
 6. Check API usage:
    Task {
        let count = await MarketstackTestService.shared.getCallCount()
        print("Used \(count) mock API calls")
    }
 
 That's it! Super simple. When you're done testing, just change it to:
    AlternativePriceService.useMarketstackTest = false
 
 Or add a proper UI toggle later with Option 1 or 2.
*/

// ═══════════════════════════════════════════════════════════════════════
// 📊 Verify It's Working
// ═══════════════════════════════════════════════════════════════════════

struct TestVerification {
    static func checkTestMode() {
        print("════════════════════════════════════════")
        print("Test Mode Status:")
        print("  Enabled: \(AlternativePriceService.useMarketstackTest)")
        
        Task {
            let count = await MarketstackTestService.shared.getCallCount()
            print("  API Calls: \(count)")
            print("════════════════════════════════════════")
        }
    }
}

// Call this anywhere to check status:
// TestVerification.checkTestMode()

// ═══════════════════════════════════════════════════════════════════════
// 🎉 Ready to Test!
// ═══════════════════════════════════════════════════════════════════════

/*
 Once test mode is enabled:
 
 1. Your portfolio price refreshes will use mock Marketstack data
 2. No real API calls are made
 3. You'll see consistent test prices:
    - AAPL: $181.25
    - MSFT: $418.75
    - GOOGL: $144.25
    - BTC: $68,500
    - ETH: $3,475
 
 4. API call counter tracks usage for Phase 2 planning
 
 5. Everything else works exactly the same!
 
 When ready for Phase 2, let me know and I'll build the real Marketstack
 service with your API key! 🚀
*/
