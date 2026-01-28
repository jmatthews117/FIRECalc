//
//  SettingsView.swift
//  FIRECalc
//
//  App settings and retirement planning configuration
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Simulation defaults
    @State private var defaultRuns: Double = 10000
    @State private var defaultTimeHorizon: Double = 30
    @State private var defaultInflation: Double = 0.02
    @State private var useHistoricalBootstrap: Bool = true
    @State private var autoRefreshPrices: Bool = false
    
    // Retirement planning
    @State private var retirementDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 365 * 20) // 20 years from now
    @State private var hasRetirementDate: Bool = false
    @State private var retirementTarget: String = "1000000"
    @State private var annualFixedIncome: String = "0"
    
    @State private var showingResetConfirmation = false
    @State private var showingExportSheet = false
    
    private let persistence = PersistenceService.shared
    
    var body: some View {
        NavigationView {
            Form {
                // Retirement Planning Section
                Section {
                    Toggle("Set Retirement Date", isOn: $hasRetirementDate)
                    
                    if hasRetirementDate {
                        DatePicker(
                            "Target Date",
                            selection: $retirementDate,
                            in: Date()...,
                            displayedComponents: [.date]
                        )
                        
                        HStack {
                            Text("Years Away")
                                .foregroundColor(.secondary)
                            Spacer()
                            let years = Calendar.current.dateComponents([.year], from: Date(), to: retirementDate).year ?? 0
                            Text("\(years) years")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Retirement Target")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Target Amount", text: $retirementTarget)
                            .keyboardType(.decimalPad)
                        
                        if let value = Double(retirementTarget) {
                            Text("Goal: \(value.toCurrency())")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Annual Fixed Income")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Social Security, Pensions, etc.", text: $annualFixedIncome)
                            .keyboardType(.decimalPad)
                        
                        if let value = Double(annualFixedIncome), value > 0 {
                            Text("\(value.toCurrency()) per year")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Text("Include Social Security, pensions, annuities, and other guaranteed income")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Retirement Planning")
                } footer: {
                    Text("Set your retirement goals to see progress on the dashboard")
                }
                
                // Live Price Info
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            Text("Yahoo Finance Integrated")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Text("Live stock prices from Yahoo Finance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("No API key required! Get real-time prices for all stocks, ETFs, crypto, and more.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                } header: {
                    Text("Live Price Updates")
                }
                
                // Simulation Defaults
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Simulation Runs")
                            Spacer()
                            Text("\(Int(defaultRuns))")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $defaultRuns, in: 1000...50000, step: 1000)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Time Horizon")
                            Spacer()
                            Text("\(Int(defaultTimeHorizon)) years")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $defaultTimeHorizon, in: 5...50, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Inflation Rate")
                            Spacer()
                            Text(String(format: "%.1f%%", defaultInflation * 100))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $defaultInflation, in: 0...0.10, step: 0.005)
                    }
                    
                    Toggle("Use Historical Bootstrap", isOn: $useHistoricalBootstrap)
                    
                    Toggle("Auto-Refresh Prices", isOn: $autoRefreshPrices)
                } header: {
                    Text("Simulation Defaults")
                } footer: {
                    Text("These settings will be used as defaults when running new simulations")
                }
                
                // Asset Allocation Guidelines
                Section {
                    NavigationLink(destination: AllocationGuidelinesView()) {
                        HStack {
                            Image(systemName: "chart.pie.fill")
                                .foregroundColor(.blue)
                            Text("Asset Allocation Guidelines")
                        }
                    }
                    
                    NavigationLink(destination: HistoricalReturnsView()) {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                                .foregroundColor(.purple)
                            Text("Historical Returns Data")
                        }
                    }
                } header: {
                    Text("Resources")
                }
                
                // Data Management
                Section {
                    Button(action: { showingExportSheet = true }) {
                        Label("Export Portfolio", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive, action: { showingResetConfirmation = true }) {
                        Label("Reset All Data", systemImage: "trash")
                    }
                } header: {
                    Text("Data Management")
                }
                
                // App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(AppConstants.appVersion) (\(AppConstants.buildNumber))")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://finance.yahoo.com")!) {
                        HStack {
                            Text("Yahoo Finance")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
            .confirmationDialog("Reset All Data", isPresented: $showingResetConfirmation) {
                Button("Reset Everything", role: .destructive) {
                    resetAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all portfolios, simulations, and settings. This cannot be undone.")
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportView()
            }
        }
    }
    
    // MARK: - Functions
    
    private func loadSettings() {
        let settings = persistence.loadSettings()
        defaultRuns = Double(settings.defaultSimulationRuns)
        defaultTimeHorizon = Double(settings.defaultTimeHorizon)
        defaultInflation = settings.defaultInflationRate
        useHistoricalBootstrap = settings.useHistoricalBootstrap
        autoRefreshPrices = settings.autoRefreshPrices
        
        // Load retirement settings
        if let dateTimestamp = UserDefaults.standard.object(forKey: "retirement_date") as? TimeInterval {
            retirementDate = Date(timeIntervalSince1970: dateTimestamp)
            hasRetirementDate = true
        }
        
        let savedTarget = UserDefaults.standard.double(forKey: "retirement_target")
        if savedTarget > 0 {
            retirementTarget = String(savedTarget)
        }
        
        let savedIncome = UserDefaults.standard.double(forKey: "fixed_income")
        if savedIncome > 0 {
            annualFixedIncome = String(savedIncome)
        }
    }
    
    private func saveSettings() {
        persistence.saveSettings(
            defaultRuns: Int(defaultRuns),
            defaultTimeHorizon: Int(defaultTimeHorizon),
            defaultInflation: defaultInflation,
            useBootstrap: useHistoricalBootstrap,
            autoRefresh: autoRefreshPrices
        )
        
        // Save retirement settings
        if hasRetirementDate {
            UserDefaults.standard.set(retirementDate.timeIntervalSince1970, forKey: "retirement_date")
        } else {
            UserDefaults.standard.removeObject(forKey: "retirement_date")
        }
        
        if let target = Double(retirementTarget) {
            UserDefaults.standard.set(target, forKey: "retirement_target")
        }
        
        if let income = Double(annualFixedIncome) {
            UserDefaults.standard.set(income, forKey: "fixed_income")
        }
    }
    
    private func resetAllData() {
        try? persistence.deletePortfolio()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Reset to defaults
        defaultRuns = 10000
        defaultTimeHorizon = 30
        defaultInflation = 0.02
        useHistoricalBootstrap = true
        autoRefreshPrices = false
        hasRetirementDate = false
        retirementTarget = "1000000"
        annualFixedIncome = "0"
    }
}

// MARK: - Allocation Guidelines View

struct AllocationGuidelinesView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Traditional Age-Based Rule")
                        .font(.headline)
                    
                    Text("Bond % = Your Age")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Text("Example: At age 35, hold 35% bonds and 65% stocks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Classic Allocation")
            }
            
            Section {
                AllocationExample(
                    title: "Aggressive (Age 20-35)",
                    stocks: 90,
                    bonds: 10,
                    description: "Maximum growth potential"
                )
                
                AllocationExample(
                    title: "Moderate (Age 35-50)",
                    stocks: 70,
                    bonds: 30,
                    description: "Balance growth and stability"
                )
                
                AllocationExample(
                    title: "Conservative (Age 50-65)",
                    stocks: 50,
                    bonds: 50,
                    description: "Preserve capital, moderate growth"
                )
                
                AllocationExample(
                    title: "Retirement (Age 65+)",
                    stocks: 30,
                    bonds: 70,
                    description: "Income and capital preservation"
                )
            } header: {
                Text("Sample Allocations by Age")
            }
            
            Section {
                Text("• Higher stock allocation = Higher expected returns but more volatility")
                Text("• Higher bond allocation = Lower returns but more stability")
                Text("• Consider your risk tolerance and time horizon")
                Text("• Rebalance annually to maintain target allocation")
            } header: {
                Text("Guidelines")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .navigationTitle("Allocation Guidelines")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AllocationExample: View {
    let title: String
    let stocks: Int
    let bonds: Int
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: CGFloat(stocks) * 2)
                
                Rectangle()
                    .fill(Color.green)
                    .frame(width: CGFloat(bonds) * 2)
            }
            .frame(height: 20)
            .cornerRadius(4)
            
            HStack {
                Label("\(stocks)% Stocks", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Label("\(bonds)% Bonds", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Export View

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exportData: String = "Preparing export..."
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(exportData)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Export Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: exportData) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .onAppear {
                prepareExport()
            }
        }
    }
    
    private func prepareExport() {
        do {
            if let portfolio = try PersistenceService.shared.loadPortfolio() {
                let data = try PersistenceService.shared.exportPortfolioAsJSON(portfolio)
                exportData = String(data: data, encoding: .utf8) ?? "Export failed"
            } else {
                exportData = "No portfolio to export"
            }
        } catch {
            exportData = "Export failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    SettingsView()
}
