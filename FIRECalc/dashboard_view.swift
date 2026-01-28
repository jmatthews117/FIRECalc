//
//  DashboardView.swift
//  FIRECalc
//
//  Main dashboard screen
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var portfolioVM = PortfolioViewModel()
    @StateObject private var simulationVM = SimulationViewModel()
    @State private var showingAddAsset = false
    @State private var showingSimulationSetup = false
    @State private var showingResults = false
    @State private var showingSettings = false
    @State private var showingQuickAdd = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Portfolio Overview Card
                    portfolioOverviewCard
                    
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
            .navigationTitle("FIRECalc")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
                
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
                    showingResults: $showingResults
                )
            }
            .sheet(isPresented: $showingResults) {
                if let result = simulationVM.currentResult {
                    SimulationResultsView(result: result)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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
            
            HStack {
                Label("\(portfolioVM.portfolio.assets.count) Assets", systemImage: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if portfolioVM.hasAssets {
                    Button(action: { Task { await portfolioVM.refreshPrices() } }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
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
