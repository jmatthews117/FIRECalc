//
//  SettingsView.swift
//  FIcalc
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
    @State private var currentAge: String = ""
    @State private var annualSavings: String = ""
    @State private var expectedAnnualSpend: String = "40000"
    @State private var withdrawalPercentage: Double = 0.04
    @State private var expectedReturn: Double = 0.07
    @State private var inflationRate: Double = 0.025

    @State private var showingResetConfirmation = false
    @State private var showingExportSheet = false
    @State private var showingDisclaimer = false
    
    private let persistence = PersistenceService.shared
    
    var body: some View {
        Form {
                // Retirement Planning Section
                Section {
                    // Current Age
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Age")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("e.g. 35", text: $currentAge)
                            .keyboardType(.numberPad)
                            .onChange(of: currentAge) { _, newValue in
                                currentAge = newValue.filter { $0.isNumber }
                            }

                        if let age = Int(currentAge) {
                            Text("Used to determine when fixed income sources begin")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            let ssPlans = benefitManager.plans.filter { $0.startAge > age }
                            if !ssPlans.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(ssPlans) { plan in
                                        let yearsUntil = plan.startAge - age
                                        HStack(spacing: 4) {
                                            Image(systemName: plan.type.iconName)
                                                .font(.caption)
                                                .foregroundColor(.green)
                                            Text("\(plan.name) starts in \(yearsUntil) yr\(yearsUntil == 1 ? "" : "s") (age \(plan.startAge))")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Annual Savings Contribution
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Annual Savings Contribution")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0", text: $annualSavings)
                                .keyboardType(.numberPad)
                                .onChange(of: annualSavings) { _, newValue in
                                    annualSavings = formatNumberInput(newValue)
                                }
                        }

                        if let savings = parseFormattedNumber(annualSavings), savings > 0 {
                            Text("\(formatCurrency(savings)) added to portfolio each year before retirement")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    // Expected Annual Spending
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expected Annual Spending in Retirement")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0", text: $expectedAnnualSpend)
                                .keyboardType(.numberPad)
                                .onChange(of: expectedAnnualSpend) { _, newValue in
                                    expectedAnnualSpend = formatNumberInput(newValue)
                                }
                        }

                        if let value = parseFormattedNumber(expectedAnnualSpend) {
                            Text("Goal: \(formatCurrency(value)) per year")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    // Safe Withdrawal Rate
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Safe Withdrawal Rate")
                            Spacer()
                            Text(String(format: "%.1f%%", withdrawalPercentage * 100))
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $withdrawalPercentage, in: 0.025...0.06, step: 0.005)

                        if let spend = parseFormattedNumber(expectedAnnualSpend) {
                            let target = spend / withdrawalPercentage
                            Text("Retirement Goal: \(formatCurrency(target))")
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        Text("The 4% rule suggests you can safely withdraw 4% of your portfolio annually")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Expected Return Slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Expected Annual Return")
                            Spacer()
                            Text(expectedReturn.toPercent())
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $expectedReturn, in: 0...0.15, step: 0.005)
                        
                        HStack {
                            Text("Used for FIRE timeline projections. Default uses your portfolio's weighted return (\(portfolioVM.portfolio.weightedExpectedReturn.toPercent()))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button {
                                resetToPortfolioReturn()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    // Inflation Rate Slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Inflation Rate")
                            Spacer()
                            Text(inflationRate.toPercent())
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $inflationRate, in: 0...0.05, step: 0.005)

                        Text("Adjusts annual savings contributions over time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Projected FIRE Timeline
                    if let projection = fireProjection {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "flag.checkered")
                                    .foregroundColor(.orange)
                                Text("Projected FIRE Timeline")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }

                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Years to FIRE")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(projection.yearsLabel)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                }

                                Spacer()

                                if let age = Int(currentAge) {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Retirement Age")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(age + projection.years)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Current Portfolio")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(portfolioVM.totalValue.toCurrency())
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Expected Return")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(portfolioVM.portfolio.weightedExpectedReturn.toPercent())
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Portfolio Target")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(projection.target.toCurrency())
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                            }

                            // Show benefit reduction note when guaranteed income
                            // is lowering the required portfolio.
                            if !benefitManager.plans.isEmpty,
                               let spend = parseFormattedNumber(expectedAnnualSpend),
                               spend > 0 {
                                let grossTarget = spend / withdrawalPercentage
                                let reduction = grossTarget - projection.target
                                if reduction > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "building.columns.fill")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                        Text("Guaranteed income reduces your target by \(formatCurrency(reduction))")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(10)
                    }

                    // Social Security & Pensions
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
                    Text("FIRE timeline is projected using your portfolio's current weighted expected return and annual savings, compounded until your portfolio reaches your retirement goal.")
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
                    
                    Button(action: { clearSimulationHistory() }) {
                        HStack {
                            Label("Clear Simulation History", systemImage: "clock.arrow.circlepath")
                            Spacer()
                            if let historyCount = try? persistence.loadSimulationHistory().count, historyCount > 0 {
                                Text("\(historyCount) saved")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button(role: .destructive, action: { showingResetConfirmation = true }) {
                        Label("Reset All Data", systemImage: "trash")
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Simulation history is automatically limited to 20 results to conserve storage. Clearing history frees up disk space but doesn't affect your current result.")
                }
                
                // App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(AppConstants.appVersion) (\(AppConstants.buildNumber))")
                            .foregroundColor(.secondary)
                    }
                    Button {
                        showingDisclaimer = true
                    } label: {
                        Label("Legal Disclaimer", systemImage: "exclamationmark.shield")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .onAppear {
                loadSettings()
            }
            .onChange(of: defaultRuns) { _, _ in saveSettings() }
            .onChange(of: defaultTimeHorizon) { _, _ in saveSettings() }
            .onChange(of: defaultInflation) { _, _ in saveSettings() }
            .onChange(of: useHistoricalBootstrap) { _, _ in saveSettings() }
            .onChange(of: currentAge) { _, _ in saveSettings() }
            .onChange(of: annualSavings) { _, _ in saveSettings() }
            .onChange(of: expectedAnnualSpend) { _, _ in saveSettings() }
            .onChange(of: withdrawalPercentage) { _, _ in saveSettings() }
            .onChange(of: expectedReturn) { _, _ in saveSettings() }
            .onChange(of: inflationRate) { _, _ in saveSettings() }
            
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
            .sheet(isPresented: $showingDisclaimer) {
                LegalDisclaimerView()
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

    // MARK: - FIRE Projection

    struct FIREProjection {
        let years: Int
        let target: Double

        var yearsLabel: String {
            years == 1 ? "1 year" : "\(years) years"
        }
    }

    /// Projects how many years until the current portfolio (plus annual savings,
    /// compounded at the expected return rate) reaches the FIRE target,
    /// accounting for guaranteed income streams that reduce the required portfolio
    /// once they begin.
    private var fireProjection: FIREProjection? {
        guard let spend = parseFormattedNumber(expectedAnnualSpend),
              spend > 0 else { return nil }

        let grossTarget = spend / withdrawalPercentage
        let currentValue = portfolioVM.totalValue
        let annualReturn = expectedReturn > 0 ? expectedReturn : portfolioVM.portfolio.weightedExpectedReturn
        let savings = parseFormattedNumber(annualSavings) ?? 0
        let startAge = Int(currentAge) ?? 0

        // Check year 0 — benefits already active might already cover everything,
        // even with a zero or empty portfolio.
        let initialEffectiveTarget = effectiveTarget(
            grossTarget: grossTarget,
            age: startAge,
            withdrawalRate: withdrawalPercentage
        )
        if currentValue >= initialEffectiveTarget {
            return FIREProjection(years: 0, target: initialEffectiveTarget)
        }

        // Allow annualReturn == 0 so pure-savings or pure-benefit scenarios still
        // converge (a future benefit kicking in drops the target to 0).
        var value = currentValue
        for year in 1...100 {
            value = value * (1 + annualReturn) + savings

            let age = startAge + year
            let target = effectiveTarget(
                grossTarget: grossTarget,
                age: age,
                withdrawalRate: withdrawalPercentage
            )

            if value >= target {
                return FIREProjection(years: year, target: target)
            }
        }

        return nil
    }

    /// Reduces the gross FIRE target by the capitalised value of all benefit
    /// plans that are active at the given age.
    private func effectiveTarget(grossTarget: Double, age: Int, withdrawalRate: Double) -> Double {
        let activeBenefitIncome = benefitManager.plans
            .filter { age >= $0.startAge }
            .reduce(0.0) { $0 + $1.annualBenefit }
        return max(0, grossTarget - activeBenefitIncome / withdrawalRate)
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
    
    private func resetToPortfolioReturn() {
        expectedReturn = portfolioVM.portfolio.weightedExpectedReturn
        saveSettings()
    }
    
    private func loadSettings() {
        let settings = persistence.loadSettings()
        defaultRuns = Double(settings.defaultSimulationRuns)
        defaultTimeHorizon = Double(settings.defaultTimeHorizon)
        defaultInflation = settings.defaultInflationRate
        useHistoricalBootstrap = settings.useHistoricalBootstrap
        
        // Load retirement settings
        let savedAge = UserDefaults.standard.integer(forKey: AppConstants.UserDefaultsKeys.currentAge)
        if savedAge > 0 {
            currentAge = String(savedAge)
        }

        let savedSavings = UserDefaults.standard.double(forKey: AppConstants.UserDefaultsKeys.annualSavings)
        if savedSavings > 0 {
            annualSavings = formatNumber(Int(savedSavings))
        }
        
        let savedSpend = UserDefaults.standard.double(forKey: AppConstants.UserDefaultsKeys.expectedAnnualSpend)
        if savedSpend > 0 {
            expectedAnnualSpend = formatNumber(Int(savedSpend))
        }
        
        let savedWithdrawalPct = UserDefaults.standard.double(forKey: AppConstants.UserDefaultsKeys.withdrawalPercentage)
        if savedWithdrawalPct > 0 {
            withdrawalPercentage = savedWithdrawalPct
        }

        let savedReturn = UserDefaults.standard.double(forKey: AppConstants.UserDefaultsKeys.expectedReturn)
        if savedReturn > 0 {
            expectedReturn = savedReturn
        } else {
            // Default to portfolio weighted return if not set
            expectedReturn = portfolioVM.portfolio.weightedExpectedReturn
        }

        let savedInflation = UserDefaults.standard.double(forKey: AppConstants.UserDefaultsKeys.inflationRate)
        if savedInflation > 0 {
            inflationRate = savedInflation
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
        if let age = Int(currentAge), age > 0 {
            UserDefaults.standard.set(age, forKey: AppConstants.UserDefaultsKeys.currentAge)
        } else {
            UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.currentAge)
        }

        let savingsValue = parseFormattedNumber(annualSavings) ?? 0
        UserDefaults.standard.set(savingsValue, forKey: AppConstants.UserDefaultsKeys.annualSavings)

        if let spend = parseFormattedNumber(expectedAnnualSpend) {
            UserDefaults.standard.set(spend, forKey: AppConstants.UserDefaultsKeys.expectedAnnualSpend)

            let target = spend / withdrawalPercentage
            UserDefaults.standard.set(target, forKey: AppConstants.UserDefaultsKeys.retirementTarget)
        }
        
        UserDefaults.standard.set(withdrawalPercentage, forKey: AppConstants.UserDefaultsKeys.withdrawalPercentage)
        UserDefaults.standard.set(expectedReturn, forKey: AppConstants.UserDefaultsKeys.expectedReturn)
        UserDefaults.standard.set(inflationRate, forKey: AppConstants.UserDefaultsKeys.inflationRate)
    }
    
    private func clearSimulationHistory() {
        // Delete the simulation history file
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppConstants.Storage.simulationHistoryFileName)
        
        try? FileManager.default.removeItem(at: fileURL)
        
        print("✅ Simulation history cleared")
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
        currentAge = ""
        annualSavings = ""
        expectedAnnualSpend = "40000"
        withdrawalPercentage = 0.04
        expectedReturn = 0.07
        inflationRate = 0.025
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

// MARK: - Legal Disclaimer View

struct LegalDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Important Notice").font(.headline)
                    Text("This app and its contents are provided for informational and educational purposes only. Nothing in this app constitutes financial, investment, tax, accounting, or legal advice.")
                    Text("No Professional Advice").font(.subheadline).fontWeight(.semibold)
                    Text("All calculations, simulations, and projections are estimates based on user-provided inputs and assumptions. They are not guarantees of future results. Past performance is not indicative of future returns.")
                    Text("No Fiduciary Relationship").font(.subheadline).fontWeight(.semibold)
                    Text("Use of this app does not create a fiduciary or advisory relationship. You should consult a qualified financial professional before making decisions.")
                    Text("Assumptions and Data").font(.subheadline).fontWeight(.semibold)
                    Text("Results depend on assumptions that may be inaccurate or change over time, including market returns, inflation, taxes, and personal circumstances. Data may be delayed or contain errors.")
                    Text("Limitation of Liability").font(.subheadline).fontWeight(.semibold)
                    Text("To the maximum extent permitted by law, the developer and contributors disclaim all liability for any loss or damage arising from the use of or reliance on this app. You use the app at your own risk.")
                    Text("No Endorsements").font(.subheadline).fontWeight(.semibold)
                    Text("References to third-party data providers or links are provided for convenience and do not constitute endorsement or warranty.")
                    Text("By using this app, you acknowledge and agree to these terms.")
                }
                .padding()
            }
            .navigationTitle("Legal Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView(portfolioVM: PortfolioViewModel(), benefitManager: DefinedBenefitManager())
}
#Preview {
    LegalDisclaimerView()
}

