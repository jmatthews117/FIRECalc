# App Store Submission Checklist for FICalc

## 🔴 CRITICAL - Required Before Submission

### 1. Privacy Policy & Legal
- [ ] Create Privacy Policy covering:
  - Data collection (portfolio values, simulation history, settings)
  - Local storage + iCloud sync explanation
  - Third-party APIs (Yahoo Finance for price data)
  - No sharing of personal financial data
  - User data deletion process
- [ ] Host privacy policy on website (can use GitHub Pages, Notion, or TermsFeed)
- [ ] Add Privacy Policy link to Settings view in app
- [ ] Add Privacy Policy URL to App Store Connect

**Where to add in code:**
```swift
// In SettingsView.swift, add a new section:
Section("Legal") {
    Link("Privacy Policy", destination: URL(string: "https://yourwebsite.com/privacy")!)
    Link("Terms of Service", destination: URL(string: "https://yourwebsite.com/terms")!)
}
```

### 2. App Icons
- [ ] Create app icon in all required sizes (use Xcode Asset Catalog)
  - 1024×1024 (App Store)
  - 180×180 (iPhone)
  - 167×167 (iPad Pro)
  - 152×152 (iPad, iPad mini)
  - 120×120 (iPhone, iPod touch)
  - 87×87 (iPhone, iPod touch @3x)
  - 80×80 (iPad, iPad mini @2x)
  - 76×76 (iPad, iPad mini)
  - 60×60 (iPhone, iPod touch)
  - 58×58 (iPhone, iPod touch @2x)
  - 40×40 (iPhone, iPod touch)
  - 29×29 (iPhone, iPod touch)
- [ ] Icon should be simple, professional, finance-related (calculator, chart, flag icon)
- [ ] No transparency, no rounded corners (iOS adds them)
- [ ] Consider using SF Symbols or a combination: flag.checkered + chart.bar

**Tools:**
- Use Figma, Sketch, or https://appicon.co/ to generate all sizes
- SF Symbols app for Apple's icon library

### 3. Screenshots (iPhone & iPad)
**Required sizes:**
- 6.7" (iPhone 14 Pro Max): 1290 × 2796 pixels
- 6.5" (iPhone 11 Pro Max): 1242 × 2688 pixels  
- 5.5" (iPhone 8 Plus): 1242 × 2208 pixels
- iPad Pro (12.9"): 2048 × 2732 pixels

**Recommended screenshots (3-10 required):**
1. **Dashboard** - Show portfolio value, daily gain, quick actions
2. **Portfolio View** - Asset list with allocation
3. **FIRE Calculator** - Timeline projection with years to FIRE
4. **Simulation Results** - Success rate, charts, key metrics
5. **Asset Allocation Chart** - Colorful pie chart
6. **Tools Overview** - List of available tools

**Tips:**
- Add text overlays explaining features
- Use bright, clean backgrounds
- Show realistic but impressive numbers
- Tools: Use Xcode simulator screenshots + https://www.screenshotone.com/ or Apple's own Screenshot app

### 4. App Store Description

**App Name:** FICalc - Retirement Planner

**Subtitle (30 chars):** Plan Your Path to Financial Independence

**Promotional Text (170 chars):**
```
Track your portfolio, run powerful Monte Carlo simulations, and visualize your path to Financial Independence and Early Retirement (FIRE).
```

**Description (4000 chars max):**
```
Plan your journey to Financial Independence and Early Retirement with FICalc, the most comprehensive FIRE calculator for iOS.

🎯 SMART RETIREMENT PLANNING
• Calculate exactly when you can retire based on your portfolio, savings, and spending
• Run Monte Carlo simulations to stress-test your retirement plan
• Compare multiple withdrawal strategies (4% rule, dynamic, guardrails, RMD, and more)
• Account for guaranteed income like pensions and Social Security

📊 PORTFOLIO TRACKING
• Track stocks, bonds, real estate, crypto, and more
• Live price updates for publicly traded assets
• Beautiful charts showing your asset allocation
• See your daily gains and overall progress

🔬 ADVANCED ANALYSIS
• Monte Carlo simulations using 100 years of historical market data (1926-2024)
• Test thousands of possible market scenarios
• Visualize success rates and projected balances
• Sensitivity analysis to optimize savings and spending
• Rebalancing advisor to maintain target allocation

📈 PERFORMANCE TRACKING
• Take portfolio snapshots over time
• Track your FIRE progress month by month
• See how close you are to your retirement goal

⚙️ FLEXIBLE & CUSTOMIZABLE
• Multiple withdrawal strategies to compare
• Define custom expected returns and volatility
• Set up pension and Social Security income
• Adjustable time horizons and inflation rates

🔒 PRIVATE & SECURE
• All data stored locally on your device
• Optional iCloud sync across your devices
• No account required, no ads
• Your financial data never leaves your control

Whether you're just starting your FIRE journey or years into accumulation, FICalc helps you plan with confidence and make data-driven decisions about your financial future.

Perfect for:
• FIRE enthusiasts and early retirement planners
• Anyone saving for retirement
• People comparing withdrawal strategies
• Investors optimizing their portfolio allocation
```

**Keywords (100 chars max):**
```
FIRE,retirement,calculator,financial,independence,portfolio,Monte Carlo,withdrawal,planning,savings
```

### 5. App Information in Xcode

**Update Info.plist or project settings:**
- [ ] Bundle display name: "FICalc"
- [ ] Bundle identifier: com.yourname.FICalc (must be unique)
- [ ] Version: 1.0
- [ ] Build number: 1
- [ ] Minimum iOS version: 17.0 (or 16.0 if you want wider compatibility)
- [ ] Supported orientations: Portrait, Landscape (or Portrait only if preferred)
- [ ] Requires full screen: No
- [ ] Supports iPad: Yes (recommended for financial apps)

**Privacy Permissions (if using):**
- User Tracking Usage Description (only if you add analytics)
- Photo Library Usage Description (only if you add export to images)

---

## 🟡 IMPORTANT - Strongly Recommended

### 6. User Onboarding
- [ ] Add a welcome screen for first launch
- [ ] Brief tutorial explaining key features
- [ ] Example portfolio to demonstrate the app
- [ ] Skip option for experienced users

**Suggested implementation:**
```swift
// In ContentView.swift or App file:
@AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false

var body: some View {
    if hasCompletedOnboarding {
        MainTabView()
    } else {
        OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
    }
}
```

### 7. Error Handling & User Feedback
- [ ] Network errors show helpful messages (already seems implemented ✅)
- [ ] Loading states for price refreshes (already implemented ✅)
- [ ] Validation for user inputs (e.g., age, portfolio values)
- [ ] Confirmation dialogs for destructive actions (delete asset) ✅
- [ ] Toast/banner for success messages ✅

### 8. App Stability
- [ ] Test on physical devices (iPhone and iPad)
- [ ] Test with empty portfolio
- [ ] Test with very large portfolios (100+ assets)
- [ ] Test airplane mode / no internet
- [ ] Test with invalid API responses
- [ ] Test background/foreground transitions
- [ ] Memory leak testing (Instruments in Xcode)
- [ ] Crash testing (add crash reporting like Sentry or use TestFlight)

### 9. Accessibility
- [ ] VoiceOver support for all interactive elements
- [ ] Dynamic Type support (text scales with user preferences)
- [ ] Sufficient color contrast (especially for charts)
- [ ] Button labels for icon-only buttons
- [ ] Semantic labels for images and charts

**Quick fixes:**
```swift
// Add to icon buttons:
.accessibilityLabel("Add new asset")

// Add to charts:
.accessibilityLabel("Portfolio allocation pie chart")
.accessibilityHint("Shows breakdown of assets by value")
```

### 10. Settings & Preferences
Verify these are included:
- [ ] Currency format preference (USD, EUR, etc.)
- [ ] Default simulation parameters
- [ ] Auto-refresh prices toggle
- [ ] Data export/backup option
- [ ] Clear all data option
- [ ] App version display

### 11. Data Persistence
- [ ] Test that data persists across app restarts ✅
- [ ] iCloud sync works (if implemented)
- [ ] Handle migration if data format changes in future
- [ ] Export portfolio to JSON/CSV
- [ ] Import portfolio from file

---

## 🟢 NICE TO HAVE - Polish & Marketing

### 12. Additional Features to Consider
- [ ] Dark mode optimization (SwiftUI handles this, but test it)
- [ ] Share simulation results as image
- [ ] Compare multiple simulation scenarios side-by-side
- [ ] Notifications for portfolio milestones
- [ ] Widget showing portfolio value
- [ ] Apple Watch complication (future update)

### 13. App Preview Video (Optional but Recommended)
- [ ] 15-30 second video showing:
  - Opening the app
  - Adding an asset
  - Running a simulation
  - Viewing results
- Use QuickTime Player to record simulator
- Add captions/annotations in iMovie or similar

### 14. Localization (Future)
- [ ] Support for other languages
- [ ] Currency formatting for different regions
- [ ] Date formatting for different locales

### 15. Marketing Website
- [ ] Simple landing page explaining the app
- [ ] Features list
- [ ] Screenshots
- [ ] Link to App Store
- [ ] Contact/support email
- [ ] Blog post about FIRE methodology

---

## 📋 Pre-Submission Testing Checklist

### Functional Testing
- [ ] Add asset with ticker → prices update
- [ ] Add asset without ticker → manual price works
- [ ] Edit asset → changes saved
- [ ] Delete asset → removed from portfolio
- [ ] Run simulation → results display correctly
- [ ] Change withdrawal strategy → affects results
- [ ] Set retirement goals → timeline updates
- [ ] Add pension/Social Security → reduces FIRE target
- [ ] Refresh prices → updates after 1 hour
- [ ] Tab between views → state persists
- [ ] Force quit app → data persists

### Edge Cases
- [ ] Empty portfolio → appropriate messages
- [ ] Zero/negative values → validation prevents
- [ ] Very large numbers (billions) → formatted correctly
- [ ] No internet → graceful handling
- [ ] API rate limit → helpful error message
- [ ] Simulation with 100,000 runs → doesn't crash
- [ ] Rapid tab switching → no crashes
- [ ] Rotation → layout adapts

### Device Testing
- [ ] iPhone SE (small screen)
- [ ] iPhone 14 Pro (notch)
- [ ] iPhone 14 Pro Max (large screen)
- [ ] iPad (different layout)
- [ ] iPad Pro (large canvas)
- [ ] iOS 17.0 (minimum version)
- [ ] Latest iOS version

### Performance Testing
- [ ] Launch time < 2 seconds
- [ ] Price refresh < 5 seconds for 20 assets
- [ ] Simulation completes in reasonable time
- [ ] No memory leaks (use Instruments)
- [ ] Smooth scrolling in all views
- [ ] Charts animate smoothly

---

## 🚀 Submission Steps

### 1. Archive & Upload
1. In Xcode: Product → Archive
2. Validate app (checks for issues)
3. Distribute to App Store
4. Upload to App Store Connect

### 2. TestFlight Beta (Optional but Recommended)
- [ ] Invite friends/family to test
- [ ] Gather feedback
- [ ] Fix critical issues
- [ ] Run for 1-2 weeks

### 3. App Store Connect Configuration
- [ ] Upload screenshots (all sizes)
- [ ] Write description
- [ ] Set pricing (Free recommended for v1.0)
- [ ] Choose availability (all countries or specific)
- [ ] Set age rating (likely 4+)
- [ ] Add keywords
- [ ] Submit for review

### 4. Review Preparation
**Apple will check:**
- App matches description
- No crashes or major bugs
- Privacy policy accessible
- No prohibited content
- Follows Human Interface Guidelines
- Financial calculations are reasonably accurate

**Common rejection reasons for financial apps:**
- Missing privacy policy
- Crashes on launch
- Misleading screenshots
- Poor error handling
- Inaccurate calculations (test your Monte Carlo engine!)

---

## 📝 Post-Launch Checklist

### Immediately After Approval
- [ ] Announce on social media
- [ ] Post to relevant subreddits (r/FIRE, r/financialindependence)
- [ ] Share with friends/family
- [ ] Monitor reviews and ratings
- [ ] Respond to user feedback

### First Week
- [ ] Check crash analytics
- [ ] Monitor support emails
- [ ] Gather user feedback
- [ ] Plan first update

### Ongoing
- [ ] Update historical data annually
- [ ] Add requested features
- [ ] Fix bugs promptly
- [ ] Keep app compatible with new iOS versions
- [ ] Refresh screenshots for new iPhone designs

---

## 🔍 Code Review Checklist

### Quick Code Improvements

#### 1. Add Privacy Policy Link to Settings
```swift
// In SettingsTabView or SettingsView, add:
Section("Legal") {
    Link("Privacy Policy", destination: URL(string: "YOUR_PRIVACY_POLICY_URL")!)
    Link("Support", destination: URL(string: "mailto:your-email@example.com")!)
}

Section("About") {
    HStack {
        Text("Version")
        Spacer()
        Text("\(AppConstants.appVersion) (\(AppConstants.buildNumber))")
            .foregroundColor(.secondary)
    }
}
```

#### 2. Improve Accessibility
```swift
// Add to ContentView tabs:
.accessibilityLabel("Dashboard tab")
.accessibilityHint("View portfolio overview and quick actions")

// Add to buttons:
Button(action: { showingAddAsset = true }) {
    Label("Add Asset", systemImage: "plus.circle")
}
.accessibilityLabel("Add new asset")
.accessibilityHint("Opens form to add a new asset to your portfolio")
```

#### 3. Add Haptic Feedback
```swift
import CoreHaptics

// Add to successful actions:
let generator = UINotificationFeedbackGenerator()
generator.notificationOccurred(.success)  // After saving asset

let impact = UIImpactFeedbackGenerator(style: .medium)
impact.impactOccurred()  // After running simulation
```

#### 4. Add Loading States
```swift
// For simulation:
if simulationVM.isSimulating {
    ProgressView("Running simulation...")
        .progressViewStyle(.circular)
} else {
    // Show results
}
```

#### 5. Input Validation
```swift
// In forms, add:
.onChange(of: quantity) { old, new in
    if let value = Double(new), value <= 0 {
        quantity = old
    }
}
```

---

## 📊 Success Metrics to Track

After launch:
- Downloads
- Daily Active Users (DAU)
- Retention rate (7-day, 30-day)
- Average simulations per user
- Crash rate (should be < 0.1%)
- App Store rating (aim for 4.5+)
- User reviews and feedback themes

---

## 🎯 Priority Order for Launch

### Must Do Before Submission (2-3 days)
1. Create and host Privacy Policy
2. Add Privacy Policy link to Settings
3. Create app icon (all sizes)
4. Take and prepare screenshots
5. Write App Store description
6. Test on real devices (iPhone and iPad)
7. Fix any critical bugs found

### Should Do Before Submission (1 week)
1. Add onboarding flow
2. Improve accessibility labels
3. Add haptic feedback
4. Input validation on all forms
5. TestFlight beta testing
6. Polish UI/animations
7. Add "About" section with version

### Nice to Have (Can Add in v1.1)
1. Share results as image
2. Widget support
3. Advanced charts
4. Export/import portfolio
5. Multiple portfolio support
6. Notification reminders
7. Apple Watch app

---

## 🆘 Common Issues & Solutions

### "Missing Privacy Policy"
**Solution:** Create one using a template and host on GitHub Pages, Notion, or your website.

### "App Crashes on Launch"
**Solution:** Test with empty UserDefaults, no saved data, and no internet connection.

### "Inaccurate Financial Calculations"
**Solution:** Add disclaimer in Settings: "This app provides estimates for educational purposes. Consult a financial advisor for personalized advice."

### "Icon Doesn't Appear"
**Solution:** Ensure icon is added to Assets.xcassets/AppIcon and all sizes are filled.

### "Screenshots Wrong Size"
**Solution:** Use simulator in exact device size, then scale if needed. See Apple's screenshot specifications.

---

## ✅ Final Pre-Flight Check

Right before you press "Submit for Review":
- [ ] App icon looks good in all sizes
- [ ] Screenshots are clear and compelling
- [ ] Description has no typos
- [ ] Privacy Policy URL works
- [ ] App doesn't crash in common scenarios
- [ ] Build number is incremented from any previous builds
- [ ] All required fields filled in App Store Connect
- [ ] App has been tested on real device(s)
- [ ] You have a support email set up
- [ ] You're ready to respond to reviews within 24 hours

---

Good luck with your App Store submission! 🚀

**Estimated Time to Launch:** 3-5 days if focused on critical items only.

**Questions?** Most common rejections are for:
1. Missing/broken privacy policy link
2. Crashes on basic functionality
3. Misleading screenshots or description
4. Missing required metadata

Your app looks solid! The main work is creating the marketing assets and legal documents. The code itself seems well-structured and functional.
