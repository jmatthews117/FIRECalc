//
//  ContentView.swift
//  FIRECalc
//
//  Main app entry point with tab bar navigation
//

import SwiftUI

struct ContentView: View {
    @StateObject private var portfolioVM = PortfolioViewModel()
    @StateObject private var simulationVM = SimulationViewModel()
    
    var body: some View {
        TabView {
            // Dashboard Tab
            DashboardTabView(portfolioVM: portfolioVM, simulationVM: simulationVM)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie.fill")
                }
            
            // Portfolio Tab
            PortfolioTabView(portfolioVM: portfolioVM)
                .tabItem {
                    Label("Portfolio", systemImage: "briefcase.fill")
                }
            
            // Tools Tab
            ToolsTabView(portfolioVM: portfolioVM, simulationVM: simulationVM)
                .tabItem {
                    Label("Tools", systemImage: "wrench.and.screwdriver.fill")
                }
            
            // Settings Tab
            SettingsTabView()
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
    @State private var showingSimulationSetup = false
    @State private var showingResults = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Portfolio Overview Card
                    portfolioOverviewCard
                    
                    // Retirement Progress Card (if retirement date is set)
                    if let retirementDate = portfolioVM.targetRetirementDate {
                        retirementProgressCard(targetDate: retirementDate)
                    }
                    
                    // Asset Allocation Chart (if has assets)
                    if portfolioVM.hasAssets {
                        AllocationChartView(portfolio: portfolioVM.portfolio)
                    }
                    
                    // Quick Actions
                    quickActionsCard
                    
                    // Latest Simulation Results (if available)
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
    
    // MARK: - Portfolio Overview Card
    
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
    
    // MARK: - Retirement Progress Card
    
    private func retirementProgressCard(targetDate: Date) -> some View {
        let yearsToRetirement = Calendar.current.dateComponents([.year], from: Date(), to: targetDate).year ?? 0
        let progress = min(1.0, max(0.0, portfolioVM.retirementProgress))
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flag.checkered")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Retirement Progress")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Target: \(portfolioVM.targetRetirementValue.toCurrency())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(yearsToRetirement) years to go")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                ProgressView(value: progress)
                    .tint(.orange)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    // MARK: - Quick Actions Card
    
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
                            // Show last result preview
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
    
    // MARK: - Latest Results Card
    
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Portfolio Summary
                    portfolioSummaryCard
                    
                    // Asset Allocation
                    if portfolioVM.hasAssets {
                        AllocationChartView(portfolio: portfolioVM.portfolio)
                    }
                    
                    // Assets List
                    if portfolioVM.hasAssets {
                        assetsListCard
                    } else {
                        emptyStateCard
                    }
                }
                .padding()
            }
            .refreshable {
                await portfolioVM.refreshPrices()
            }
            .navigationTitle("Portfolio")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingQuickAdd = true }) {
                            Label("Quick Add Ticker", systemImage: "bolt.fill")
                        }
                        
                        Button(action: { showingAddAsset = true }) {
                            Label("Add Custom Asset", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddAsset) {
                AddAssetView(portfolioVM: portfolioVM)
            }
            .sheet(isPresented: $showingQuickAdd) {
                QuickAddTickerView(portfolioVM: portfolioVM)
            }
        }
    }
    
    private var portfolioSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total Value")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(portfolioVM.totalValue.toCurrency())
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expected Return")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(portfolioVM.portfolio.weightedExpectedReturn.toPercent())
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
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
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    private var assetsListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Assets")
                .font(.headline)
            
            ForEach(portfolioVM.portfolio.assets) { asset in
                NavigationLink(destination: AssetDetailView(asset: asset, portfolioVM: portfolioVM)) {
                    AssetRowView(asset: asset)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Assets Yet")
                .font(.title2)
                .bold()
            
            Text("Add your first asset to start building your portfolio")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { showingAddAsset = true }) {
                Label("Add Your First Asset", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(AppConstants.UI.cornerRadius)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 40)
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
}

// MARK: - Tools Tab

struct ToolsTabView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @ObservedObject var simulationVM: SimulationViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section("Analysis Tools") {
                    NavigationLink(destination: FIRECalculatorView()) {
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
                        config: .constant(WithdrawalConfiguration()),
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
                
                Section("Income Planning") {
                    NavigationLink(destination: DefinedBenefitPlansView()) {
                        HStack {
                            Image(systemName: "building.columns")
                                .foregroundColor(.green)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text("Social Security & Pensions")
                                    .font(.headline)
                                Text("Manage fixed income")
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
    var body: some View {
        NavigationView {
            SettingsView()
        }
    }
}

// MARK: - Asset Detail View

struct AssetDetailView: View {
    let asset: Asset
    @ObservedObject var portfolioVM: PortfolioViewModel
    @Environment(\.dismiss) private var dismiss
    
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
                Button(role: .destructive, action: deleteAsset) {
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
    }
    
    private func deleteAsset() {
        portfolioVM.deleteAsset(asset)
        dismiss()
    }
}

#Preview {
    ContentView()
}
