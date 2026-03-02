//
//  DashboardView.swift
//  FIRECalc
//
//  Main dashboard screen with pull-to-refresh
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var portfolioVM = PortfolioViewModel()
    @StateObject private var simulationVM = SimulationViewModel()
    @StateObject private var benefitManager = DefinedBenefitManager()
    @StateObject private var fireCalcVM = FIRECalculatorViewModel()
    @State private var showingAddAsset = false
    @State private var showingSimulationSetup = false
    @State private var showingResults = false
    @State private var showingQuickAdd = false
    @State private var showDollarGain = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Portfolio Overview Card
                    portfolioOverviewCard
                    
                    // Retirement Progress Card (if target is set)
                    if savedRetirementTarget > 0 && portfolioVM.hasAssets {
                        retirementProgressCard
                    }
                    
                    // Asset Allocation Chart (if has assets)
                    if portfolioVM.hasAssets {
                        AllocationChartView(portfolio: portfolioVM.portfolio)
                    }
                    
                    // Quick Actions
                    quickActionsCard
                    
                    // Asset List or Empty State
                    if portfolioVM.hasAssets {
                        assetListCard
                    } else {
                        emptyStateCard
                    }
                    
                    // Latest Simulation Results (if available)
                    if simulationVM.hasResult {
                        latestResultsCard
                    }
                }
                .padding()
            }
            .refreshable {
                // Use Task.detached to prevent SwiftUI from cancelling the refresh
                await Task.detached { @MainActor in
                    await portfolioVM.refreshPrices()
                }.value
            }
            .navigationTitle("FIRECalc")
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
            .sheet(isPresented: $showingSimulationSetup) {
                SimulationSetupView(
                    portfolioVM: portfolioVM,
                    simulationVM: simulationVM,
                    benefitManager: benefitManager,
                    showingResults: $showingResults
                )
            }
            .sheet(isPresented: $showingResults) {
                if let result = simulationVM.currentResult {
                    SimulationResultsView(result: result)
                }
            }
            .alert("Error", isPresented: .constant(portfolioVM.errorMessage != nil)) {
                Button("OK") { portfolioVM.errorMessage = nil }
            } message: {
                if let error = portfolioVM.errorMessage {
                    Text(error)
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
            
            // Daily gain/loss display (toggleable)
            if let dailyGain = portfolioVM.dailyGain, 
               let dailyGainPct = portfolioVM.dailyGainPercentage {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDollarGain.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: dailyGain >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        if showDollarGain {
                            Text(dailyGain.toCurrency())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        } else {
                            Text(dailyGainPct.toPercent())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Text("today")
                            .font(.caption)
                    }
                    .foregroundColor(dailyGain >= 0 ? .green : .red)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            
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
    
    // MARK: - FIRE Helpers (reads persisted settings)

    private var savedCurrentAge: Int? {
        let age = UserDefaults.standard.integer(forKey: "current_age")
        return age > 0 ? age : nil
    }

    private var savedAnnualSavings: Double {
        UserDefaults.standard.double(forKey: "annual_savings")
    }

    private var savedRetirementTarget: Double {
        UserDefaults.standard.double(forKey: "retirement_target")
    }

    /// Years until portfolio (grown at weighted expected return + annual savings) hits the target.
    private var yearsToFIRE: Int? {
        let target = savedRetirementTarget
        guard target > 0, portfolioVM.hasAssets else { return nil }
        let annualReturn = portfolioVM.portfolio.weightedExpectedReturn
        guard annualReturn > 0 else { return nil }
        let currentValue = portfolioVM.totalValue
        
        // Load inflation rate from UserDefaults
        let inflationRate = UserDefaults.standard.double(forKey: "inflation_rate")
        let inflation = inflationRate > 0 ? inflationRate : 0.025
        
        if currentValue >= target { return 0 }
        var value = currentValue
        for year in 1...100 {
            // Apply inflation adjustment to savings (year - 1 for correct indexing)
            let inflationAdjustedSavings = savedAnnualSavings * pow(1 + inflation, Double(year - 1))
            value = value * (1 + annualReturn) + inflationAdjustedSavings
            if value >= target { return year }
        }
        return nil
    }

    // MARK: - Retirement Progress Card

    private var retirementProgressCard: some View {
        let target = savedRetirementTarget
        let progress = target > 0 ? min(1.0, max(0.0, portfolioVM.totalValue / target)) : 0

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
                        Text("Goal: \(target.toCurrency())")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let years = yearsToFIRE {
                            if years == 0 {
                                Text("Already funded! 🎉")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("~\(years) yr\(years == 1 ? "" : "s") to FIRE")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if let age = savedCurrentAge {
                                    Text("Retire at age ~\(age + years)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
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
                                
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(result.medianFinalBalance.toCurrency())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("median")
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
            
            NavigationLink(destination: FIRECalculatorView(portfolioVM: portfolioVM, benefitManager: benefitManager, viewModel: fireCalcVM)) {
                HStack {
                    Image(systemName: "flag.checkered")
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("FIRE Calculator")
                            .font(.headline)
                        Text("Calculate retirement date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(AppConstants.UI.cornerRadius)
            }
            .buttonStyle(.plain)
            
            Button(action: { showingAddAsset = true }) {
                HStack {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("Add Asset")
                            .font(.headline)
                        Text("Build your portfolio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(AppConstants.UI.cornerRadius)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Asset List Card
    
    private var assetListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Assets")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: AssetListView(portfolioVM: portfolioVM)) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            ForEach(portfolioVM.portfolio.assets.prefix(3)) { asset in
                AssetRowView(asset: asset)
            }
            
            if portfolioVM.portfolio.assets.count > 3 {
                Text("+ \(portfolioVM.portfolio.assets.count - 3) more")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    // MARK: - Empty State Card
    
    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Assets Yet")
                .font(.title2)
                .bold()
            
            Text("Add your first asset to start planning your FIRE journey")
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

// MARK: - Asset Row View

struct AssetRowView: View {
    let asset: Asset
    
    var body: some View {
        HStack {
            Image(systemName: asset.assetClass.iconName)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(asset.assetClass.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(asset.totalValue.toCurrency())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if let change = asset.priceChange {
                    Text(change.toPercent())
                        .font(.caption)
                        .foregroundColor(change >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    DashboardView()
}
