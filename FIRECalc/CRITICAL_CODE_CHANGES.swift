//
//  CRITICAL_CODE_CHANGES.swift
//  FIRECalc
//
//  Code snippets to add before App Store submission
//

import SwiftUI

// MARK: - 1. Add Legal Section to Settings View
// Add this section to your SettingsView or SettingsTabView

/*
Section("Legal & Support") {
    Link(destination: URL(string: "https://yourwebsite.com/privacy")!) {
        HStack {
            Label("Privacy Policy", systemImage: "hand.raised.fill")
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    Link(destination: URL(string: "https://yourwebsite.com/terms")!) {
        HStack {
            Label("Terms of Service", systemImage: "doc.text.fill")
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    Link(destination: URL(string: "mailto:support@yourapp.com?subject=FIRECalc Support")!) {
        HStack {
            Label("Contact Support", systemImage: "envelope.fill")
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

Section("About") {
    HStack {
        Text("Version")
        Spacer()
        Text("\(AppConstants.appVersion) (\(AppConstants.buildNumber))")
            .foregroundColor(.secondary)
    }
    
    HStack {
        Text("Build Date")
        Spacer()
        Text("February 2026")
            .foregroundColor(.secondary)
    }
}

Section("Disclaimer") {
    Text("FIRECalc provides estimates for educational purposes only. Results are based on historical data and assumptions that may not reflect future performance. Always consult with a qualified financial advisor before making investment decisions.")
        .font(.caption)
        .foregroundColor(.secondary)
}
*/

// MARK: - 2. Add Accessibility Labels
// Add these to your interactive elements

/*
// For Tab Bar items in ContentView:
.tabItem {
    Label("Dashboard", systemImage: "chart.pie.fill")
}
.accessibilityLabel("Dashboard")
.accessibilityHint("View your portfolio overview and recent activity")

// For buttons:
Button(action: { showingAddAsset = true }) {
    Label("Add Asset", systemImage: "plus.circle")
}
.accessibilityLabel("Add new asset")
.accessibilityHint("Opens a form to add a new asset to your portfolio")

// For charts:
AllocationChartView(portfolio: portfolioVM.portfolio)
    .accessibilityLabel("Portfolio allocation chart")
    .accessibilityHint("Shows breakdown of your assets by value and percentage")

// For images without labels:
Image(systemName: "chevron.right")
    .accessibilityHidden(true)  // Decorative only
*/

// MARK: - 3. Add Haptic Feedback Helper
// Add this extension to your project

extension UINotificationFeedbackGenerator {
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

extension UIImpactFeedbackGenerator {
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Usage Examples:
/*
// After successfully adding an asset:
portfolioVM.addAsset(newAsset)
UINotificationFeedbackGenerator.success()

// After running a simulation:
await simulationVM.runSimulation(portfolio: portfolioVM.portfolio)
UIImpactFeedbackGenerator.impact(style: .heavy)

// When deleting an asset:
UINotificationFeedbackGenerator.warning()
portfolioVM.deleteAsset(asset)
*/

// MARK: - 4. Add Onboarding View (New File: OnboardingView.swift)

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    
    let pages: [(icon: String, title: String, description: String)] = [
        ("flag.checkered", "Welcome to FIRECalc", "Plan your path to Financial Independence and Early Retirement with powerful tools and insights."),
        ("briefcase.fill", "Track Your Portfolio", "Add your assets across stocks, bonds, real estate, crypto, and more. Get live price updates automatically."),
        ("waveform.path.ecg", "Run Simulations", "Test thousands of market scenarios using Monte Carlo analysis based on 100 years of historical data."),
        ("chart.line.uptrend.xyaxis", "Optimize Your Plan", "Compare withdrawal strategies, analyze sensitivity, and visualize your path to retirement.")
    ]
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(
                        icon: pages[index].icon,
                        title: pages[index].title,
                        description: pages[index].description
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            Button(action: completeOnboarding) {
                HStack {
                    Spacer()
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Skip")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private func completeOnboarding() {
        withAnimation {
            hasCompletedOnboarding = true
        }
        UINotificationFeedbackGenerator.success()
    }
}

struct OnboardingPageView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 100))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - 5. Update ContentView to Show Onboarding
/*
// At the top of ContentView:
@AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false

// In body:
var body: some View {
    if hasCompletedOnboarding {
        // Your existing TabView
        TabView(selection: $selectedTab) {
            // ... existing tabs
        }
    } else {
        OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
    }
}
*/

// MARK: - 6. Add Input Validation Helper
// Add this extension to help validate user inputs

extension View {
    /// Validates numeric input and prevents invalid values
    func validateNumericInput(
        value: Binding<String>,
        min: Double? = nil,
        max: Double? = nil,
        allowDecimal: Bool = true
    ) -> some View {
        self.onChange(of: value.wrappedValue) { oldValue, newValue in
            // Remove non-numeric characters
            let filtered = allowDecimal
                ? newValue.filter { "0123456789.".contains($0) }
                : newValue.filter { "0123456789".contains($0) }
            
            // Ensure only one decimal point
            if filtered.filter({ $0 == "." }).count > 1 {
                value.wrappedValue = oldValue
                return
            }
            
            // Check bounds if specified
            if let numericValue = Double(filtered) {
                if let min = min, numericValue < min {
                    value.wrappedValue = oldValue
                    UINotificationFeedbackGenerator.error()
                    return
                }
                if let max = max, numericValue > max {
                    value.wrappedValue = oldValue
                    UINotificationFeedbackGenerator.error()
                    return
                }
            }
            
            value.wrappedValue = filtered
        }
    }
}

// MARK: - Usage Example:
/*
TextField("Quantity", text: $quantity)
    .keyboardType(.decimalPad)
    .validateNumericInput(
        value: $quantity,
        min: 0.0001,
        max: 1_000_000_000,
        allowDecimal: true
    )
*/

// MARK: - 7. Add App State Monitoring for Background/Foreground
// Add to your main ContentView or App file

/*
import SwiftUI

@main
struct FIRECalcApp: App {
    @StateObject private var portfolioVM = PortfolioViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(portfolioVM)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        print("App became active")
                        Task {
                            await portfolioVM.refreshPricesIfNeeded()
                        }
                    case .inactive:
                        print("App became inactive")
                    case .background:
                        print("App moved to background")
                        portfolioVM.saveAll()  // Save data when backgrounding
                    @unknown default:
                        break
                    }
                }
        }
    }
}
*/

// MARK: - 8. Add Error Recovery
// Add this to handle unexpected errors gracefully

struct ErrorRecoveryView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: retry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - 9. Add Loading View
// Use for long-running operations

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)
                    .tint(.white)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color(.systemGray6))
            .cornerRadius(20)
            .shadow(radius: 10)
        }
    }
}

// MARK: - Usage:
/*
.overlay {
    if viewModel.isLoading {
        LoadingOverlay(message: "Running simulation...")
    }
}
*/

// MARK: - 10. Add Share Sheet for Results
// Allow users to share simulation results

extension View {
    func shareSheet(isPresented: Binding<Bool>, items: [Any]) -> some View {
        self.sheet(isPresented: isPresented) {
            ShareSheet(items: items)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Usage:
/*
@State private var showingShareSheet = false

Button("Share Results") {
    showingShareSheet = true
}
.shareSheet(isPresented: $showingShareSheet, items: [
    "My FIRE simulation shows a \(Int(result.successRate * 100))% success rate!",
    "Check out FIRECalc on the App Store"
])
*/

// MARK: - 11. Add Disclaimer Alert (Show on First Launch)
// Show important disclaimer when user first opens the app

struct DisclaimerView: View {
    @Binding var hasAcknowledged: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Important Disclaimer")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                DisclaimerPoint(text: "This app provides estimates for educational purposes only.")
                DisclaimerPoint(text: "Past performance does not guarantee future results.")
                DisclaimerPoint(text: "Simulations use historical data and assumptions that may not reflect your actual experience.")
                DisclaimerPoint(text: "Always consult a qualified financial advisor before making investment decisions.")
            }
            .padding()
            
            Button(action: acknowledge) {
                HStack {
                    Spacer()
                    Text("I Understand")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding()
        }
        .padding()
    }
    
    private func acknowledge() {
        hasAcknowledged = true
    }
}

struct DisclaimerPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 12. Add App Rating Prompt
// Ask for ratings after user has positive experience

import StoreKit

extension View {
    func requestReviewIfAppropriate() {
        // Request review after user runs their 5th simulation successfully
        // or achieves another milestone
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}

// MARK: - Usage:
/*
// In SimulationResultsView, after showing a good result:
if result.successRate >= 0.85 {
    // User has a good plan, good time to ask for review
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        requestReviewIfAppropriate()
    }
}
*/

// MARK: - Quick Implementation Checklist
/*
 Priority 1 (Must Have):
 ☐ Add Legal section to Settings with Privacy Policy link
 ☐ Add About section with app version
 ☐ Add disclaimer text somewhere visible
 ☐ Add accessibility labels to main buttons/tabs
 
 Priority 2 (Should Have):
 ☐ Add onboarding flow
 ☐ Add haptic feedback to key actions
 ☐ Add input validation
 ☐ Add loading states
 
 Priority 3 (Nice to Have):
 ☐ Add share functionality
 ☐ Add error recovery views
 ☐ Add rating prompt
 ☐ Add app state monitoring
*/
