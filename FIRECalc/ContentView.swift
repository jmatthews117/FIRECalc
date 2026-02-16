//
//  ContentView.swift
//  FIRECalc
//
//  Main app structure with edit/delete asset capabilities
//

import SwiftUI

struct ContentView: View {
    @StateObject private var portfolioVM = PortfolioViewModel()
    @StateObject private var simulationVM = SimulationViewModel()
    @StateObject private var benefitManager = DefinedBenefitManager()
    
    var body: some View {
        TabView {
            // Dashboard Tab
            DashboardTabView(portfolioVM: portfolioVM, simulationVM: simulationVM, benefitManager: benefitManager)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie.fill")
                }
            
            // Portfolio Tab
            PortfolioTabView(portfolioVM: portfolioVM)
                .tabItem {
                    Label("Portfolio", systemImage: "briefcase.fill")
                }
            
            // Simulations Tab
            SimulationsTab(portfolioVM: portfolioVM, simulationVM: simulationVM)
                .tabItem {
                    Label("Simulations", systemImage: "waveform.path.ecg")
                }
            
            // Tools Tab
            ToolsTabView(portfolioVM: portfolioVM, simulationVM: simulationVM, benefitManager: benefitManager)
                .tabItem {
                    Label("Tools", systemImage: "wrench.and.screwdriver.fill")
                }
            
            // Settings Tab
            SettingsTabView(portfolioVM: portfolioVM, benefitManager: benefitManager)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// MARK: - Dashboard Tab

struct DashboardTabView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @ObservedObject var simulationVM: SimulationViewModel
    @ObservedObject var benefitManager: DefinedBenefitManager
    @State private var showingSimulationSetup = false
    @State private var showingResults = false

    // @AppStorage gives SwiftUI a live dependency on these UserDefaults keys,
    // so the dashboard re-renders automatically whenever Settings writes new values.
    @AppStorage("current_age") private var storedCurrentAge: Int = 0
    @AppStorage("annual_savings") private var storedAnnualSavings: Double = 0
    @AppStorage("expected_annual_spend") private var storedAnnualSpend: Double = 0
    @AppStorage("withdrawal_percentage") private var storedWithdrawalRate: Double = 0
    @AppStorage("retirement_target") private var storedRetirementTarget: Double = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    portfolioOverviewCard
                    
                    if grossRetirementTarget > 0 && portfolioVM.hasAssets {
                        retirementProgressCard
                    }
                    
                    if portfolioVM.hasAssets {
                        AllocationChartView(portfolio: portfolioVM.portfolio)
                    }
                    
                    quickActionsCard
                    
                    if simulationVM.hasResult {
                        latestResultsCard
                    }
                }
                .padding()
            }
            .refreshable {
                await portfolioVM.refreshPrices()
            }
            .navigationTitle("Dashboard")
            .sheet(isPresented: $showingSimulationSetup) {
                SimulationSetupView(
                    portfolioVM: portfolioVM,
                    simulationVM: simulationVM,
                    showingResults: $showingResults
                )
            }
            .sheet(isPresented: $showingResults) {
                if let result = simulationVM.currentResult {
                    SimulationResultsView(result: result)
                }
            }
        }
    }
    
    private var portfolioOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Portfolio Value")
                    .font(.headline)
                
                Spacer()
                
                if portfolioVM.isUpdatingPrices {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Text(portfolioVM.totalValue.toCurrency())
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            HStack {
                Label("\(portfolioVM.portfolio.assets.count) Assets", systemImage: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if portfolioVM.hasAssets {
                    Text("Pull to refresh")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    // MARK: - FIRE Helpers (backed by @AppStorage for live reactivity)

    private var savedCurrentAge: Int? {
        storedCurrentAge > 0 ? storedCurrentAge : nil
    }

    private var savedAnnualSavings: Double {
        storedAnnualSavings
    }

    private var savedWithdrawalRate: Double {
        storedWithdrawalRate > 0 ? storedWithdrawalRate : 0.04
    }

    private var savedAnnualSpend: Double {
        storedAnnualSpend
    }

    /// Gross FIRE target (spend ÷ withdrawal rate), before any benefit reduction.
    private var grossRetirementTarget: Double {
        guard storedAnnualSpend > 0 else {
            // Fall back to the legacy key written by older Settings versions.
            return storedRetirementTarget
        }
        return storedAnnualSpend / savedWithdrawalRate
    }

    // MARK: - FIRE Projection (mirrors SettingsView.fireProjection exactly)

    struct FIREProjection {
        let years: Int
        let target: Double

        var yearsLabel: String {
            years == 1 ? "1 year" : "\(years) years"
        }
    }

    /// Reduces the gross FIRE target by the capitalised value of all benefit
    /// plans that are already active at `age`.
    private func effectiveTarget(grossTarget: Double, age: Int) -> Double {
        let activeBenefitIncome = benefitManager.plans
            .filter { age >= $0.startAge }
            .reduce(0.0) { $0 + $1.annualBenefit }
        return max(0, grossTarget - activeBenefitIncome / savedWithdrawalRate)
    }

    /// Projects how many years until the current portfolio (plus annual savings,
    /// compounded at the portfolio's weighted expected return) reaches the FIRE
    /// target, accounting for guaranteed income streams that reduce the required
    /// portfolio once they begin.  Mirrors SettingsView.fireProjection.
    private var fireProjection: FIREProjection? {
        let gross = grossRetirementTarget
        guard gross > 0, portfolioVM.hasAssets else { return nil }
        guard let startAge = savedCurrentAge else { return nil }

        let currentValue = portfolioVM.totalValue
        let annualReturn = portfolioVM.portfolio.weightedExpectedReturn
        let savings = savedAnnualSavings

        // Year-0 check: benefits that are already active may already cover everything.
        let initialEffective = effectiveTarget(grossTarget: gross, age: startAge)
        if currentValue >= initialEffective {
            return FIREProjection(years: 0, target: initialEffective)
        }

        var value = currentValue
        for year in 1...100 {
            value = value * (1 + annualReturn) + savings
            let age = startAge + year
            let target = effectiveTarget(grossTarget: gross, age: age)
            if value >= target {
                return FIREProjection(years: year, target: target)
            }
        }
        return nil
    }

    // MARK: - Retirement Progress Card

    private var retirementProgressCard: some View {
        let gross = grossRetirementTarget
        // Use the benefit-adjusted target at the projected FIRE age for the
        // progress bar, so it matches what Settings shows as the portfolio goal.
        let displayTarget = fireProjection?.target ?? gross
        let progress = displayTarget > 0
            ? min(1.0, max(0.0, portfolioVM.totalValue / displayTarget))
            : 0.0

        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "flag.checkered")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Projected FIRE Timeline")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            if let projection = fireProjection {
                // Years-to-FIRE + Retirement Age row (mirrors Settings layout)
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

                    if let age = savedCurrentAge {
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

                // Three-column detail row (mirrors Settings layout)
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

                    VStack(alignment: .center, spacing: 2) {
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

                // Benefit-reduction note (mirrors Settings layout)
                if !benefitManager.plans.isEmpty, savedAnnualSpend > 0 {
                    let reduction = gross - projection.target
                    if reduction > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "building.columns.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text("Guaranteed income reduces your target by \(reduction.toCurrency())")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
            } else {
                Text(portfolioVM.hasAssets
                     ? "Set your age and annual spending in Settings to see your FIRE timeline."
                     : "Add assets and configure Settings to see your projected FIRE timeline.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Progress bar — always shown when there is a gross target
            if gross > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(Int(progress * 100))% funded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Goal: \(displayTarget.toCurrency())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange.opacity(0.2))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange)
                                .frame(width: geo.size.width * progress, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .cornerRadius(AppConstants.UI.cornerRadius)
    }
    
    private var quickActionsCard: some View {
        VStack(spacing: 12) {
            Button(action: { showingSimulationSetup = true }) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Run Simulation")
                            .font(.headline)
                        
                        if let result = simulationVM.currentResult {
                            HStack(spacing: 6) {
                                Text(String(format: "%.0f%%", result.successRate * 100))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(simulationVM.successRateColor)
                                
                                Text("success")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Monte Carlo Analysis")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(AppConstants.UI.cornerRadius)
            }
            .buttonStyle(.plain)
            .disabled(!portfolioVM.hasAssets)
            
            NavigationLink(destination: PerformanceTrackingView(portfolioVM: portfolioVM)) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("Track Performance")
                            .font(.headline)
                        Text("Historical snapshots")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(AppConstants.UI.cornerRadius)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var latestResultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest Simulation")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingResults = true }) {
                    Text("View Details")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if let result = simulationVM.currentResult {
                VStack(spacing: 8) {
                    HStack {
                        Text("Success Rate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(String(format: "%.0f%%", result.successRate * 100))
                            .font(.title2)
                            .bold()
                            .foregroundColor(simulationVM.successRateColor)
                    }
                    
                    ProgressView(value: result.successRate)
                        .tint(simulationVM.successRateColor)
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Median Balance")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(result.medianFinalBalance.toCurrency())
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Time Horizon")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(result.parameters.timeHorizonYears) years")
                                .font(.headline)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
}

// MARK: - Portfolio Tab

struct PortfolioTabView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @State private var showingAddAsset = false
    @State private var showingQuickAdd = false
    @State private var showingBulkUpload = false
    
    var body: some View {
        NavigationView {
            GroupedPortfolioView(portfolioVM: portfolioVM)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddAsset = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                Text("Add Asset")
                            }
                            .font(.headline)
                        }
                    }
                }
                .sheet(isPresented: $showingAddAsset) {
                    AddAssetView(portfolioVM: portfolioVM)
                }
        }
    }
}

// MARK: - Simulations Tab

struct SimulationsTab: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @ObservedObject var simulationVM: SimulationViewModel
    @State private var showingSetup = false
    @State private var showingResults = false
    @State private var showingManualReturns = false
    @State private var showingHistoryResult = false
    @State private var selectedHistoryResult: SimulationResult?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Portfolio Summary
                    portfolioSummaryCard
                    
                    // Custom Returns Card
                    customReturnsCard
                    
                    // Latest Results
                    if let result = simulationVM.currentResult {
                        latestResultCard(result: result)
                    }
                    
                    // Run Simulation Button
                    runSimulationButton
                    
                    // Simulation History
                    simulationHistoryCard
                }
                .padding()
            }
            .navigationTitle("Simulations")
            .sheet(isPresented: $showingSetup) {
                SimulationSetupView(
                    portfolioVM: portfolioVM,
                    simulationVM: simulationVM,
                    showingResults: $showingResults
                )
            }
            .sheet(isPresented: $showingResults) {
                if let result = simulationVM.currentResult {
                    SimulationResultsView(result: result)
                }
            }
            .sheet(isPresented: $showingManualReturns) {
                ManualReturnsView(
                    simulationVM: simulationVM,
                    portfolioVM: portfolioVM
                )
            }
        }
    }
    
    private var portfolioSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Portfolio Value")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(portfolioVM.totalValue.toCurrency())
                .font(.system(size: 36, weight: .bold, design: .rounded))
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Expected Return")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(portfolioVM.portfolio.weightedExpectedReturn.toPercent())
                        .font(.headline)
                        .foregroundColor(.green)
                    if simulationVM.useCustomReturns {
                        Text("Custom")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    } else {
                        Text("Historical")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Volatility")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(portfolioVM.portfolio.weightedVolatility.toPercent())
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private var customReturnsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.blue)
                Text("Return Assumptions")
                    .font(.headline)
                
                Spacer()
                
                Button(simulationVM.useCustomReturns ? "Edit" : "Customize") {
                    showingManualReturns = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            Text(simulationVM.useCustomReturns ? "Using custom return assumptions" : "Using historical bootstrap (1926-2024)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private func latestResultCard(result: SimulationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest Results")
                    .font(.headline)
                
                Spacer()
                
                Button("View Full") {
                    showingResults = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            HStack {
                Text("Success Rate")
                Spacer()
                Text(String(format: "%.0f%%", result.successRate * 100))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(simulationVM.successRateColor)
            }
            
            ProgressView(value: result.successRate)
                .tint(simulationVM.successRateColor)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Median Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.medianFinalBalance.toCurrency())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Time Horizon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(result.parameters.timeHorizonYears) years")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            
            Text("Run on \(result.runDate.formatted())")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private var runSimulationButton: some View {
        Button(action: { showingSetup = true }) {
            HStack {
                Spacer()
                if simulationVM.isSimulating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text("Running...")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "play.fill")
                    Text("Run New Simulation")
                        .fontWeight(.semibold)
                }
                Spacer()
            }
            .padding()
            .background(portfolioVM.hasAssets && !simulationVM.isSimulating ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!portfolioVM.hasAssets || simulationVM.isSimulating)
    }
    
    private var simulationHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Simulation History")
                .font(.headline)

            if simulationVM.simulationHistory.isEmpty {
                Text("No simulations yet. Run your first simulation to see results.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(simulationVM.simulationHistory.prefix(5), id: \.id) { result in
                    Button {
                        selectedHistoryResult = result
                        showingHistoryResult = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.runDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("\(result.parameters.timeHorizonYears) yr horizon • \(result.parameters.numberOfRuns) runs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(String(format: "%.0f%%", result.successRate * 100))
                                .font(.headline)
                                .foregroundColor(successColor(for: result.successRate))

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    if result.id != simulationVM.simulationHistory.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
        .sheet(isPresented: $showingHistoryResult) {
            if let result = selectedHistoryResult {
                SimulationResultsView(result: result)
            }
        }
    }

    private func successColor(for rate: Double) -> Color {
        if rate >= 0.9 { return .green }
        if rate >= 0.75 { return .orange }
        return .red
    }
}

// MARK: - Tools Tab

struct ToolsTabView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @ObservedObject var simulationVM: SimulationViewModel
    @ObservedObject var benefitManager: DefinedBenefitManager
    @StateObject private var fireCalcVM = FIRECalculatorViewModel()

    var body: some View {
        NavigationView {
            List {
                Section("Analysis Tools") {
                    NavigationLink(destination: FIRECalculatorView(portfolioVM: portfolioVM, benefitManager: benefitManager, viewModel: fireCalcVM)) {
                        HStack {
                            Image(systemName: "flag.checkered")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            VStack(alignment: .leading) {
                                Text("FIRE Calculator")
                                    .font(.headline)
                                Text("Calculate your retirement date")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    NavigationLink(destination: HistoricalReturnsView()) {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            VStack(alignment: .leading) {
                                Text("Historical Returns")
                                    .font(.headline)
                                Text("View asset class data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    NavigationLink(destination: WithdrawalConfigurationView(
                        config: $simulationVM.withdrawalConfiguration,
                        portfolioValue: portfolioVM.totalValue
                    )) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.purple)
                                .frame(width: 30)
                            VStack(alignment: .leading) {
                                Text("Withdrawal Strategies")
                                    .font(.headline)
                                Text("Compare approaches")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tools")
        }
    }
}

// MARK: - Settings Tab

struct SettingsTabView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @ObservedObject var benefitManager: DefinedBenefitManager

    var body: some View {
        NavigationView {
            SettingsView(portfolioVM: portfolioVM, benefitManager: benefitManager)
        }
    }
}

// MARK: - Asset Detail View with Edit

struct AssetDetailView: View {
    let asset: Asset
    @ObservedObject var portfolioVM: PortfolioViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: asset.assetClass.iconName)
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(asset.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if let ticker = asset.ticker {
                                Text(ticker)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total Value")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(asset.totalValue.toCurrency())
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section("Details") {
                HStack {
                    Text("Asset Class")
                    Spacer()
                    Text(asset.assetClass.rawValue)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Quantity")
                    Spacer()
                    Text(asset.quantity.toDecimal())
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Price per Unit")
                    Spacer()
                    Text(asset.unitValue.toPreciseCurrency())
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Purchase Date")
                    Spacer()
                    Text(asset.purchaseDate.shortFormatted())
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Expected Performance") {
                HStack {
                    Text("Expected Return")
                    Spacer()
                    Text(asset.expectedReturn.toPercent())
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Volatility")
                    Spacer()
                    Text(asset.volatility.toPercent())
                        .foregroundColor(.orange)
                }
            }
            
            if asset.hasLiveData {
                Section("Live Data") {
                    if let price = asset.currentPrice {
                        HStack {
                            Text("Current Price")
                            Spacer()
                            Text(price.toPreciseCurrency())
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if let change = asset.priceChange {
                        HStack {
                            Text("Today's Change")
                            Spacer()
                            Text(change.toPercent())
                                .foregroundColor(change >= 0 ? .green : .red)
                        }
                    }
                    
                    if let updated = asset.lastUpdated {
                        HStack {
                            Text("Last Updated")
                            Spacer()
                            Text(updated.formatted())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section {
                Button(action: { showingEditSheet = true }) {
                    HStack {
                        Spacer()
                        Image(systemName: "pencil")
                        Text("Edit Asset")
                        Spacer()
                    }
                    .foregroundColor(.blue)
                }
                
                Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                    HStack {
                        Spacer()
                        Text("Delete Asset")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Asset Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            EditAssetView(asset: asset, portfolioVM: portfolioVM)
        }
        .confirmationDialog("Delete Asset", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteAsset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(asset.name)?")
        }
    }
    
    private func deleteAsset() {
        portfolioVM.deleteAsset(asset)
        dismiss()
    }
}

// MARK: - Edit Asset View

struct EditAssetView: View {
    let asset: Asset
    @ObservedObject var portfolioVM: PortfolioViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var assetClass: AssetClass
    @State private var ticker: String
    @State private var quantity: String
    @State private var unitValue: String
    
    init(asset: Asset, portfolioVM: PortfolioViewModel) {
        self.asset = asset
        self.portfolioVM = portfolioVM
        self._name = State(initialValue: asset.name)
        self._assetClass = State(initialValue: asset.assetClass)
        self._ticker = State(initialValue: asset.ticker ?? "")
        self._quantity = State(initialValue: String(asset.quantity))
        self._unitValue = State(initialValue: String(asset.unitValue))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Asset Details") {
                    TextField("Name", text: $name)
                    
                    Picker("Asset Class", selection: $assetClass) {
                        ForEach(AssetClass.allCases) { ac in
                            Text(ac.rawValue).tag(ac)
                        }
                    }
                    
                    if assetClass.supportsTicker {
                        TextField("Ticker (Optional)", text: $ticker)
                            .textInputAutocapitalization(.characters)
                    }
                }
                
                Section("Value") {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)
                    
                    TextField("Price per Unit", text: $unitValue)
                        .keyboardType(.decimalPad)
                    
                    if let qty = Double(quantity), let price = Double(unitValue) {
                        HStack {
                            Text("Total Value")
                            Spacer()
                            Text((qty * price).toCurrency())
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Edit Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && Double(quantity) != nil && Double(unitValue) != nil
    }
    
    private func saveChanges() {
        var updatedAsset = asset
        updatedAsset.name = name
        updatedAsset.assetClass = assetClass
        updatedAsset.ticker = ticker.isEmpty ? nil : ticker
        updatedAsset.quantity = Double(quantity) ?? asset.quantity
        updatedAsset.unitValue = Double(unitValue) ?? asset.unitValue
        
        portfolioVM.updateAsset(updatedAsset)
        dismiss()
    }
}

#Preview {
    ContentView()
}

