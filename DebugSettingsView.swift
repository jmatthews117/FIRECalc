//
//  DebugSettingsView.swift
//  FIRECalc
//
//  Settings view for controlling debug logging
//

import SwiftUI

struct DebugSettingsView: View {
    @State private var verbosityLevel: DebugLogger.Verbosity = .detailed
    @State private var enabledCategories: Set<DebugLogger.Category> = []
    @State private var showingTestRefresh = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Debug Logging")
                        .font(.headline)
                    Text("Control console output for troubleshooting refresh and API issues.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Verbosity Level")) {
                Picker("Log Level", selection: $verbosityLevel) {
                    Text("Silent").tag(DebugLogger.Verbosity.silent)
                    Text("Errors Only").tag(DebugLogger.Verbosity.errors)
                    Text("Important").tag(DebugLogger.Verbosity.important)
                    Text("Detailed").tag(DebugLogger.Verbosity.detailed)
                    Text("Verbose").tag(DebugLogger.Verbosity.verbose)
                }
                .pickerStyle(.menu)
                .onChange(of: verbosityLevel) { _, newValue in
                    Task {
                        await DebugLogger.shared.setVerbosity(newValue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbosityDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Log Categories")) {
                ForEach(DebugLogger.Category.allCases, id: \.self) { category in
                    Toggle(isOn: Binding(
                        get: { enabledCategories.contains(category) },
                        set: { isEnabled in
                            if isEnabled {
                                enabledCategories.insert(category)
                                Task {
                                    await DebugLogger.shared.enableCategory(category)
                                }
                            } else {
                                enabledCategories.remove(category)
                                Task {
                                    await DebugLogger.shared.disableCategory(category)
                                }
                            }
                        }
                    )) {
                        HStack {
                            Text(category.rawValue)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(categoryDescription(category))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section {
                Button("Enable All Categories") {
                    Task {
                        await DebugLogger.shared.enableAllCategories()
                        enabledCategories = Set(DebugLogger.Category.allCases)
                    }
                }
                
                Button("Disable All Categories", role: .destructive) {
                    Task {
                        await DebugLogger.shared.disableAllCategories()
                        enabledCategories.removeAll()
                    }
                }
            }
            
            Section(header: Text("Quick Actions")) {
                Button {
                    printDiagnosticGuide()
                } label: {
                    Label("Print Diagnostic Guide", systemImage: "doc.text.fill")
                }
                
                Button {
                    showingTestRefresh = true
                } label: {
                    Label("View Example Output", systemImage: "eye.fill")
                }
            }
            
            Section(header: Text("Recommended Settings")) {
                VStack(alignment: .leading, spacing: 12) {
                    RecommendationRow(
                        title: "Normal Use",
                        description: "Minimal logging, errors only",
                        action: {
                            setRecommendedSettings(for: .errors)
                        }
                    )
                    
                    Divider()
                    
                    RecommendationRow(
                        title: "Troubleshooting",
                        description: "Detailed logging for debugging issues",
                        action: {
                            setRecommendedSettings(for: .detailed)
                        }
                    )
                    
                    Divider()
                    
                    RecommendationRow(
                        title: "Development",
                        description: "All logs including API calls",
                        action: {
                            setRecommendedSettings(for: .verbose)
                        }
                    )
                }
            }
        }
        .navigationTitle("Debug Logging")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Load current settings
            verbosityLevel = await DebugLogger.shared.verbosityLevel
            // Initialize with commonly used categories
            enabledCategories = [
                .refresh, .api, .cache, .cooldown, .batch,
                .error, .success, .warning, .performance
            ]
        }
        .sheet(isPresented: $showingTestRefresh) {
            ExampleOutputView()
        }
    }
    
    // MARK: - Helper Methods
    
    private var verbosityDescription: String {
        switch verbosityLevel {
        case .silent:
            return "No console output. Use when you don't need any debug information."
        case .errors:
            return "Only errors are logged. Useful for production or normal use."
        case .important:
            return "Errors, warnings, and major operations. Good for general monitoring."
        case .detailed:
            return "All operations and state changes. Recommended for troubleshooting."
        case .verbose:
            return "Everything including API calls and calculations. For deep debugging."
        }
    }
    
    private func categoryDescription(_ category: DebugLogger.Category) -> String {
        switch category {
        case .refresh: return "Portfolio refresh operations"
        case .api: return "API calls and responses"
        case .cache: return "Cache hits and misses"
        case .pricing: return "Price calculations"
        case .subscription: return "Subscription status"
        case .cooldown: return "Refresh cooldown timing"
        case .batch: return "Batch processing"
        case .error: return "Error messages"
        case .success: return "Success messages"
        case .warning: return "Warning messages"
        case .performance: return "Performance metrics"
        }
    }
    
    private func setRecommendedSettings(for level: DebugLogger.Verbosity) {
        verbosityLevel = level
        
        Task {
            await DebugLogger.shared.setVerbosity(level)
            
            switch level {
            case .silent:
                await DebugLogger.shared.disableAllCategories()
                enabledCategories.removeAll()
                
            case .errors:
                enabledCategories = [.error, .warning]
                await DebugLogger.shared.disableAllCategories()
                await DebugLogger.shared.enableCategory(.error)
                await DebugLogger.shared.enableCategory(.warning)
                
            case .important:
                enabledCategories = [.error, .warning, .success, .refresh, .cooldown]
                await DebugLogger.shared.enableAllCategories()
                await DebugLogger.shared.disableCategory(.api)
                await DebugLogger.shared.disableCategory(.cache)
                await DebugLogger.shared.disableCategory(.pricing)
                
            case .detailed:
                enabledCategories = Set(DebugLogger.Category.allCases)
                enabledCategories.remove(.pricing)
                await DebugLogger.shared.enableAllCategories()
                await DebugLogger.shared.disableCategory(.pricing)
                
            case .verbose:
                enabledCategories = Set(DebugLogger.Category.allCases)
                await DebugLogger.shared.enableAllCategories()
            }
        }
    }
    
    private func printDiagnosticGuide() {
        print("\n" + String(repeating: "=", count: 70))
        print("📘 DIAGNOSTIC GUIDE - How to Use Debug Logging")
        print(String(repeating: "=", count: 70))
        print("")
        print("PROBLEM: Refresh only updates half of assets")
        print("  1. Set verbosity to 'Detailed'")
        print("  2. Enable: Refresh, Batch, Success, Error")
        print("  3. Pull to refresh")
        print("  4. Look for: '📦 Processing batch X/Y'")
        print("  5. Count successful vs failed updates")
        print("")
        print("PROBLEM: Some tickers won't update")
        print("  1. Set verbosity to 'Verbose'")
        print("  2. Enable: API, Cache, Error")
        print("  3. Pull to refresh")
        print("  4. Search console for your ticker symbol")
        print("  5. Check if it says 'from cache' or 'from API'")
        print("")
        print("PROBLEM: Cooldown isn't working correctly")
        print("  1. Set verbosity to 'Detailed'")
        print("  2. Enable: Cooldown, API")
        print("  3. Try to refresh twice")
        print("  4. Look for: '⏳ Next refresh in Xh Ym'")
        print("")
        print("PROBLEM: App uses too many API calls")
        print("  1. Set verbosity to 'Verbose'")
        print("  2. Enable: API, Cache, Performance")
        print("  3. Use app normally for a session")
        print("  4. Count API calls vs cache hits")
        print("")
        print("After troubleshooting, set verbosity back to 'Errors Only' for normal use.")
        print("")
        print(String(repeating: "=", count: 70) + "\n")
    }
}

// MARK: - Supporting Views

struct RecommendationRow: View {
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ExampleOutputView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Example Console Output")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("When you refresh with 'Detailed' verbosity enabled, you'll see:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ExampleLogLine("════════════════════════════════════════")
                        ExampleLogLine("🔄 REFRESH Starting portfolio refresh")
                        ExampleLogLine("🔄 REFRESH Assets to update: 12")
                        ExampleLogLine("🔄 REFRESH Bypass cooldown: true")
                        ExampleLogLine("════════════════════════════════════════")
                        ExampleLogLine("📦 BATCH ────────────────────────────────────────")
                        ExampleLogLine("📦 BATCH Batch 1/3 - Processing 5 assets")
                        ExampleLogLine("✅ SUCCESS [SPY] Updated to $485.50")
                        ExampleLogLine("✅ SUCCESS [AAPL] Updated to $185.50")
                        ExampleLogLine("✅ SUCCESS [MSFT] Updated to $380.20")
                        ExampleLogLine("✅ SUCCESS [GOOGL] Updated to $140.50")
                        ExampleLogLine("✅ SUCCESS [TSLA] Updated to $245.30")
                        ExampleLogLine("📦 BATCH Batch 1/3 complete - ✅ 5 | ❌ 0")
                        ExampleLogLine("📦 BATCH ────────────────────────────────────────")
                        ExampleLogLine("...")
                        ExampleLogLine("════════════════════════════════════════")
                        ExampleLogLine("🔄 REFRESH Refresh complete in 2.34s")
                        ExampleLogLine("🔄 REFRESH Success: 12/12")
                        ExampleLogLine("🔄 REFRESH Failed: 0/12")
                        ExampleLogLine("════════════════════════════════════════")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    Text("If any assets fail, you'll also see a diagnostic report with recommendations.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Example Output")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ExampleLogLine: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.primary)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        DebugSettingsView()
    }
}
