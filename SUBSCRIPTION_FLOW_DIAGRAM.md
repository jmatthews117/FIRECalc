# FIRECalc Pro Subscription Flow Diagram

## User Journey Map

```
┌─────────────────────────────────────────────────────────────────┐
│                       NEW USER OPENS APP                         │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ SubscriptionManager  │
        │    initializes       │
        │  (checks status)     │
        └──────────┬───────────┘
                   │
        ┌──────────▼──────────────┐
        │ No Active Subscription  │
        │    FREE TIER USER       │
        └──────────┬──────────────┘
                   │
     ┌─────────────┼─────────────┐
     │             │             │
     ▼             ▼             ▼
┌─────────┐  ┌──────────┐  ┌─────────────┐
│Dashboard│  │Portfolio │  │   Settings  │
│         │  │   Tab    │  │     Tab     │
└────┬────┘  └─────┬────┘  └──────┬──────┘
     │             │               │
     │             │               │
     ▼             ▼               ▼


─────────────────────────────────────────────────────────────────
                    FREE USER EXPERIENCE
─────────────────────────────────────────────────────────────────

DASHBOARD:
┌─────────────────────────────────────┐
│  Portfolio Value: $50,000           │
│  🔒 Upgrade for live prices         │ ◄── Locked indicator
│  Last updated: Never                │
└─────────────────────────────────────┘

PORTFOLIO - ADD ASSET:
┌─────────────────────────────────────┐
│  Asset Type: Stocks                 │
│  ┌───────────────────────────────┐  │
│  │ 🔒 Ticker Symbol (Pro Only)   │  │
│  │                               │  │
│  │ Upgrade to FIRECalc Pro to    │  │
│  │ track stocks automatically    │  │
│  │                               │  │
│  │ ┌─────────────────────────┐   │  │
│  │ │ 🌟 Upgrade to Pro       │   │  │ ◄── Upgrade CTA
│  │ │ $1.99/mo                │   │  │
│  │ └─────────────────────────┘   │  │
│  └───────────────────────────────┘  │
│                                     │
│  Enter value manually: $100         │ ◄── Still functional
└─────────────────────────────────────┘

SETTINGS:
┌─────────────────────────────────────┐
│  ┌───────────────────────────────┐  │
│  │ 🌟 Upgrade to Pro             │  │
│  │ Get live stock prices         │  │ ◄── Prominent banner
│  │ $1.99/mo or $19.99/yr    ─►   │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘


─────────────────────────────────────────────────────────────────
                    USER UPGRADE FLOW
─────────────────────────────────────────────────────────────────

USER TAPS "Upgrade to Pro"
         │
         ▼
┌───────────────────────────────────────┐
│    SubscriptionPaywallView Opens      │
│                                       │
│  ┌─────────────────────────────────┐  │
│  │  💎 FIRECalc Pro                │  │
│  │  Track portfolio in real-time   │  │
│  └─────────────────────────────────┘  │
│                                       │
│  Features:                            │
│  ✓ Live Stock Prices                 │
│  ✓ Portfolio Refresh                 │
│  ✓ Real-Time Values                  │
│  ✓ Ticker Search                     │
│                                       │
│  Choose Your Plan:                   │
│  ┌─────────────────────────────────┐  │
│  │ ○ Monthly Plan         $1.99/mo │  │
│  └─────────────────────────────────┘  │
│  ┌─────────────────────────────────┐  │
│  │ ● Annual Plan          $19.99/yr │  │ ◄── Selected
│  │   Save 17%                      │  │
│  └─────────────────────────────────┘  │
│                                       │
│  ┌─────────────────────────────────┐  │
│  │   Subscribe for $19.99          │  │ ◄── CTA Button
│  └─────────────────────────────────┘  │
│                                       │
│  Restore Purchases                   │
└───────────────────────────────────────┘
         │
         ▼
USER TAPS "Subscribe"
         │
         ▼
┌───────────────────────────────────────┐
│    StoreKit Payment Sheet             │
│                                       │
│  [Sandbox Environment]                │ ◄── Test mode
│                                       │
│  FIRECalc Pro Annual                  │
│  $19.99 per year                      │
│                                       │
│  [Touch ID / Face ID to Purchase]     │
└───────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────┐
│  SubscriptionManager               │
│  • Receives transaction            │
│  • Verifies with Apple             │
│  • Updates isProSubscriber = true  │
│  • Finishes transaction            │
└────────────────────────────────────┘
         │
         ▼
    PAYWALL DISMISSES
         │
         ▼
    USER NOW PRO!


─────────────────────────────────────────────────────────────────
                    PRO USER EXPERIENCE
─────────────────────────────────────────────────────────────────

DASHBOARD:
┌─────────────────────────────────────┐
│  Portfolio Value: $50,000           │
│  ⭐ Pull to refresh                 │ ◄── Pro indicator
│  Last updated: 2m ago               │
└─────────────────────────────────────┘
         │
         │ USER PULLS DOWN
         ▼
┌─────────────────────────────────────┐
│  Updating prices...                 │ ◄── Loading state
│  [Progress spinner]                 │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Portfolio Value: $50,523           │ ◄── Updated!
│  ⬆ $523 (1.05%) today              │
│  Last updated: Just now             │
└─────────────────────────────────────┘

PORTFOLIO - ADD ASSET:
┌─────────────────────────────────────┐
│  Asset Type: Stocks                 │
│  ┌───────────────────────────────┐  │
│  │ Ticker Symbol                 │  │ ◄── Unlocked!
│  │                               │  │
│  │ AAPL                          │  │ ◄── User enters
│  │                               │  │
│  │ ┌─────────────────────────┐   │  │
│  │ │ Load Price for AAPL     │   │  │ ◄── Button appears
│  │ └─────────────────────────┘   │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
         │
         │ USER TAPS LOAD
         ▼
┌─────────────────────────────────────┐
│  ✓ APPLE INC • $178.45              │ ◄── Auto-loaded!
│  Quantity: 100                      │
│  Total: $17,845.00                  │
└─────────────────────────────────────┘

SETTINGS:
┌─────────────────────────────────────┐
│  ┌───────────────────────────────┐  │
│  │ ✓ FIRECalc Pro                │  │
│  │ Pro (Annual) • Renews Apr 2026│  │ ◄── Active status
│  │                               │  │
│  │ Manage Subscription     ─►    │  │ ◄── Opens App Store
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘


─────────────────────────────────────────────────────────────────
                 SUBSCRIPTION STATUS CHECKS
─────────────────────────────────────────────────────────────────

Every feature that needs Pro:
┌────────────────────────────────┐
│  if SubscriptionManager        │
│     .shared.isProSubscriber {  │
│                                │
│    // Allow Pro feature        │
│                                │
│  } else {                      │
│                                │
│    // Show upgrade prompt      │
│                                │
│  }                             │
└────────────────────────────────┘

MarketstackService.canMakeAPICall():
┌────────────────────────────────┐
│  let isPro = await MainActor   │
│    .run {                      │
│      SubscriptionManager       │
│        .shared.isProSubscriber │
│    }                           │
│                                │
│  if !isPro {                   │
│    print("🚫 Free tier")       │
│    return false                │
│  }                             │
└────────────────────────────────┘


─────────────────────────────────────────────────────────────────
              SUBSCRIPTION LIFECYCLE EVENTS
─────────────────────────────────────────────────────────────────

APP LAUNCH:
┌────────────────────┐
│ App initializes    │
│        │           │
│        ▼           │
│ SubscriptionManager│ ◄── Singleton created
│   .shared          │
│        │           │
│        ▼           │
│ Start transaction  │ ◄── Listen for updates
│   listener         │
│        │           │
│        ▼           │
│ Check current      │ ◄── Query existing status
│   subscription     │
│        │           │
│        ▼           │
│ Update UI          │
└────────────────────┘

PURCHASE COMPLETED:
┌────────────────────┐
│ Transaction update │
│        │           │
│        ▼           │
│ Verify transaction │ ◄── Apple cryptographic check
│        │           │
│        ▼           │
│ Update status      │ ◄── isProSubscriber = true
│        │           │
│        ▼           │
│ Finish transaction │ ◄── Tell Apple we processed it
│        │           │
│        ▼           │
│ Refresh UI         │ ◄── @Published triggers update
└────────────────────┘

SUBSCRIPTION RENEWAL:
┌────────────────────┐
│ Auto-renewal       │ ◄── Happens in background
│   (monthly/yearly) │
│        │           │
│        ▼           │
│ Transaction update │ ◄── Listener catches it
│        │           │
│        ▼           │
│ Update expiration  │ ◄── New expiration date
│        │           │
│        ▼           │
│ Pro status remains │ ◄── User still Pro
└────────────────────┘

SUBSCRIPTION EXPIRES:
┌────────────────────┐
│ Renewal fails /    │ ◄── Payment declined or cancelled
│   User cancels     │
│        │           │
│        ▼           │
│ Transaction update │ ◄── Expiration detected
│        │           │
│        ▼           │
│ isProSubscriber    │ ◄── Set to false
│   = false          │
│        │           │
│        ▼           │
│ UI updates to free │ ◄── Features lock again
└────────────────────┘

RESTORE PURCHASES:
┌────────────────────┐
│ User taps          │
│ "Restore Purchases"│
│        │           │
│        ▼           │
│ AppStore.sync()    │ ◄── Query Apple servers
│        │           │
│        ▼           │
│ Fetch all          │ ◄── Get transaction history
│   transactions     │
│        │           │
│        ▼           │
│ Update status      │ ◄── Restore active subscription
│        │           │
│        ▼           │
│ Unlock Pro features│
└────────────────────┘


─────────────────────────────────────────────────────────────────
                      KEY INTEGRATION POINTS
─────────────────────────────────────────────────────────────────

1. MarketstackService.swift (Line 94-107)
   └─ canMakeAPICall() checks isProSubscriber
   └─ Blocks all API calls for free users

2. portfolio_viewmodel.swift (Line 124-128)
   └─ refreshPrices() checks subscription first
   └─ Shows error for free users

3. add_asset_view.swift (Line 59-151)
   └─ Ticker section shows upgrade prompt for free users
   └─ Only shows ticker input for Pro users

4. ContentView.swift (Line 259-279)
   └─ Dashboard shows subscription status
   └─ Different messages for free vs Pro

5. settings_view.swift (Line 28-81)
   └─ Top section manages subscription
   └─ Upgrade banner for free, manage for Pro


─────────────────────────────────────────────────────────────────
                        DATA FLOW
─────────────────────────────────────────────────────────────────

┌──────────────────┐
│  StoreKit API    │ (Apple's servers)
└────────┬─────────┘
         │
         │ Transaction updates
         ▼
┌──────────────────────┐
│ SubscriptionManager  │ (Single source of truth)
│  @Published vars:    │
│  • isProSubscriber   │ ◄── Boolean flag
│  • subscriptionStatus│ ◄── Detailed state
└────────┬─────────────┘
         │
         │ SwiftUI @Published updates
         │
    ┌────┼────┬────────┬─────────┐
    │         │        │         │
    ▼         ▼        ▼         ▼
┌────────┐ ┌─────┐ ┌──────┐ ┌────────┐
│Add View│ │Dash │ │Portf │ │Settings│
│        │ │board│ │olio  │ │        │
└────────┘ └─────┘ └──────┘ └────────┘
    │         │        │         │
    └────┬────┴────┬───┴─────────┘
         │         │
         │         │ Checks isProSubscriber
         ▼         ▼
┌──────────────────────┐
│ MarketstackService   │ (API calls)
│  • Fetch stock prices│
│  • Check cooldown    │
└──────────────────────┘


─────────────────────────────────────────────────────────────────
                       SUCCESS METRICS
─────────────────────────────────────────────────────────────────

Track these after launch:

Funnel Analysis:
┌────────────────┐
│ 1000 Users     │ (100%)
└───────┬────────┘
        │
        │ 30% view paywall
        ▼
┌────────────────┐
│ 300 Views      │ (30%)
└───────┬────────┘
        │
        │ 10% start purchase
        ▼
┌────────────────┐
│ 30 Attempts    │ (3%)
└───────┬────────┘
        │
        │ 80% complete
        ▼
┌────────────────┐
│ 24 Subscribers │ (2.4% overall conversion)
└────────────────┘

Revenue per month:
• 17 monthly × $1.99 = $33.83
• 7 annual × $1.67/mo = $11.67
• Total: $45.50/month
• After Apple cut (30%): $31.85/month
• After year 1 (15%): $38.68/month


─────────────────────────────────────────────────────────────────
                    IMPLEMENTATION COMPLETE!
─────────────────────────────────────────────────────────────────

All systems ready:
✓ SubscriptionManager handles purchases
✓ Paywall UI looks professional
✓ Free tier fully functional
✓ Pro features properly gated
✓ Subscription persists across launches
✓ Restore purchases implemented
✓ Error handling in place
✓ Testing guides provided

Next: Set up StoreKit config and test!
```
