//
//  SettingsView.swift
//  FIRECalc
//
//  App settings and retirement planning configuration
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var portfolioVM: PortfolioViewModel
    @ObservedObject var benefitManager: DefinedBenefitManager

    // Simulation defaults
    @State private var defaultRuns: Double = 10000
    @State private var defaultTimeHorizon: Double = 30
    @State private var defaultInflation: Double = 0.02
    @State private var useHistoricalBootstrap: Bool = true
    
    // Retirement planning
    @State private var retirementDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 365 * 20)
    @State private var hasRetirementDate: Bool = false
    @State private var expectedAnnualSpend: String = "40000"
    @State private var withdrawalPercentage: Double = 0.04

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
                        Text("Expected Annual Spending")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Annual spending in retirement", text: $expectedAnnualSpend)
                            .keyboardType(.numberPad)
                            .onChange(of: expectedAnnualSpend) { _, newValue in
                                expectedAnnualSpend = formatNumberInput(newValue)
                            }
                        
                        if let value = parseFormattedNumber(expectedAnnualSpend) {
                            Text("Goal: \(formatCurrency(value)) per year")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Safe Withdrawal Rate")
                            Spacer()
                            Text(String(format: "%.1f%%", withdrawalPercentage * 100))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $withdrawalPercentage, in: 0.025...0.06, step: 0.005)
                        
                        if let spend = parseFormattedNumber(expectedAnnualSpend) {
                            let targetPortfolio = spend / withdrawalPercentage
                            Text("Retirement Goal: \(formatCurrency(targetPortfolio))")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Text("The 4% rule suggests you can safely withdraw 4% of your portfolio annually")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink(destination: DefinedBenefitPlansView(manager: benefitManager)) {
                        HStack {
                            Image(systemName: "building.columns.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Social Security & Pensions")
                                Text("Manage fixed income sources")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(fixedIncomeSummary)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Retirement Planning")
                } footer: {
                    Text("Your retirement goal is automatically calculated as: Expected Annual Spending ÷ Safe Withdrawal Rate")
                }
                
                // Simulation Defaults
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Simulation Runs")
                            Spacer()
                            Text(formatNumber(Int(defaultRuns)))
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
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            //.toolbar { }  <-- Removed Done button toolbar item
            
            .onAppear {
                loadSettings()
            }
            .onChange(of: defaultRuns) { _, _ in saveSettings() }
            .onChange(of: defaultTimeHorizon) { _, _ in saveSettings() }
            .onChange(of: defaultInflation) { _, _ in saveSettings() }
            .onChange(of: useHistoricalBootstrap) { _, _ in saveSettings() }
            .onChange(of: hasRetirementDate) { _, _ in saveSettings() }
            .onChange(of: retirementDate) { _, _ in saveSettings() }
            .onChange(of: expectedAnnualSpend) { _, _ in saveSettings() }
            .onChange(of: withdrawalPercentage) { _, _ in saveSettings() }
            
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
    
    // MARK: - Computed Properties

    private var fixedIncomeSummary: String {
        let total = benefitManager.plans.reduce(0) { $0 + $1.annualBenefit }
        if total > 0 {
            return formatCurrency(total) + "/yr"
        }
        return benefitManager.plans.isEmpty ? "None added" : "$0"
    }

    // MARK: - Number Formatting Functions
    
    private func formatNumberInput(_ input: String) -> String {
        // Remove all non-digit characters
        let digitsOnly = input.filter { $0.isNumber }
        
        // Convert to number and format with commas
        if let number = Int(digitsOnly) {
            return formatNumber(number)
        }
        return digitsOnly
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }
    
    private func parseFormattedNumber(_ formatted: String) -> Double? {
        let digitsOnly = formatted.filter { $0.isNumber }
        return Double(digitsOnly)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
    
    // MARK: - Settings Functions
    
    private func loadSettings() {
        let settings = persistence.loadSettings()
        defaultRuns = Double(settings.defaultSimulationRuns)
        defaultTimeHorizon = Double(settings.defaultTimeHorizon)
        defaultInflation = settings.defaultInflationRate
        useHistoricalBootstrap = settings.useHistoricalBootstrap
        
        // Load retirement settings
        if let dateTimestamp = UserDefaults.standard.object(forKey: "retirement_date") as? TimeInterval {
            retirementDate = Date(timeIntervalSince1970: dateTimestamp)
            hasRetirementDate = true
        }
        
        let savedSpend = UserDefaults.standard.double(forKey: "expected_annual_spend")
        if savedSpend > 0 {
            expectedAnnualSpend = formatNumber(Int(savedSpend))
        }
        
        let savedWithdrawalPct = UserDefaults.standard.double(forKey: "withdrawal_percentage")
        if savedWithdrawalPct > 0 {
            withdrawalPercentage = savedWithdrawalPct
        }
    }
    
    private func saveSettings() {
        persistence.saveSettings(
            defaultRuns: Int(defaultRuns),
            defaultTimeHorizon: Int(defaultTimeHorizon),
            defaultInflation: defaultInflation,
            useBootstrap: useHistoricalBootstrap,
            autoRefresh: nil
        )
        
        // Save retirement settings
        if hasRetirementDate {
            UserDefaults.standard.set(retirementDate.timeIntervalSince1970, forKey: "retirement_date")
        } else {
            UserDefaults.standard.removeObject(forKey: "retirement_date")
        }
        
        if let spend = parseFormattedNumber(expectedAnnualSpend) {
            UserDefaults.standard.set(spend, forKey: "expected_annual_spend")
            
            // Calculate and save retirement target
            let target = spend / withdrawalPercentage
            UserDefaults.standard.set(target, forKey: "retirement_target")
        }
        
        UserDefaults.standard.set(withdrawalPercentage, forKey: "withdrawal_percentage")
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
        hasRetirementDate = false
        expectedAnnualSpend = "40000"
        withdrawalPercentage = 0.04
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
    SettingsView(portfolioVM: PortfolioViewModel(), benefitManager: DefinedBenefitManager())
}
