//  grouped_portfolio_view.swift
//  FIcalc
//
//  Portfolio view grouped by asset type with interactive pie chart
//

import SwiftUI
import Charts

enum AssetSortOption: String, CaseIterable, Identifiable {
    case valueHighToLow = "Value: High to Low"
    case valueLowToHigh = "Value: Low to High"
    case nameAZ = "Name: A-Z"
    case nameZA = "Name: Z-A"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .valueHighToLow: return "arrow.down.circle"
        case .valueLowToHigh: return "arrow.up.circle"
        case .nameAZ: return "textformat.abc"
        case .nameZA: return "textformat.abc"
        }
    }
}

struct GroupedPortfolioView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @State private var selectedAssetClass: AssetClass?
    @State private var showingBondCalculator = false
    @State private var selectedAsset: Asset?
    @State private var showDollarGain = false
    @State private var sortOption: AssetSortOption = .valueHighToLow
    @State private var refreshStatus: RefreshStatus?

    @AppStorage(AppConstants.UserDefaultsKeys.expectedAnnualSpend) private var storedAnnualSpend: Double = 0
    @AppStorage(AppConstants.UserDefaultsKeys.withdrawalPercentage) private var storedWithdrawalRate: Double = 0

    /// Gross FIRE target derived from Settings values, or 0 if not configured.
    private var retirementTarget: Double {
        guard storedAnnualSpend > 0 else { return 0 }
        let rate = storedWithdrawalRate > 0 ? storedWithdrawalRate : 0.04
        return storedAnnualSpend / rate
    }
    
    /// Sort assets based on the selected sort option
    private func sortedAssets(_ assets: [Asset]) -> [Asset] {
        switch sortOption {
        case .valueHighToLow:
            return assets.sorted { $0.totalValue > $1.totalValue }
        case .valueLowToHigh:
            return assets.sorted { $0.totalValue < $1.totalValue }
        case .nameAZ:
            return assets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameZA:
            return assets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Refresh cooldown banner (when active)
                if let status = refreshStatus, !status.isAvailable {
                    refreshCooldownBanner(status: status)
                }
                
                // Portfolio Summary
                portfolioSummaryCard
                
                // Interactive Pie Chart
                interactivePieChart
                
                // Gain Display Toggle and Sort Controls
                controlsBar
                
                // Grouped Assets
                if let selected = selectedAssetClass {
                    assetGroupSection(for: selected)
                } else {
                    allAssetGroupsSections
                }
            }
            .padding()
        }
        .refreshable {
            // Use Task.detached to prevent SwiftUI from cancelling the refresh
            await Task.detached { @MainActor in
                await portfolioVM.refreshPrices()
                
                // Update refresh status after attempting refresh
                await loadRefreshStatus()
            }.value
        }
        .task {
            // Load refresh status when view appears
            await loadRefreshStatus()
        }
        .onChange(of: portfolioVM.isUpdatingPrices) { _, isUpdating in
            if !isUpdating {
                // Refresh status after update completes
                Task {
                    await loadRefreshStatus()
                }
            }
        }
        .navigationTitle("Portfolio")
        .toolbar {
            if selectedAssetClass != nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Show All") {
                        withAnimation {
                            selectedAssetClass = nil
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingBondCalculator) {
            BondPricingCalculatorView()
        }
        .sheet(item: $selectedAsset) { asset in
            AssetDetailView(asset: asset, portfolioVM: portfolioVM)
        }
    }
    
    // MARK: - Helper Methods
    
    // Load refresh status from MarketstackService
    private func loadRefreshStatus() async {
        let status = await MarketstackService.shared.getRefreshStatus()
        await MainActor.run {
            refreshStatus = status
        }
    }
    
    // Refresh cooldown banner
    private func refreshCooldownBanner(status: RefreshStatus) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.title3)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Refresh Cooldown Active")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(status.displayText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if case .cooldownActive(let nextDate, _) = status {
                    Text("Available at \(nextDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.15))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Portfolio Summary Card
    
    private var portfolioSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Total Value")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

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
                        
                        Text(portfolioVM.isShowingDailyChange ? "today" : "total")
                            .font(.caption)
                    }
                    .foregroundColor(dailyGain >= 0 ? .green : .red)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            
            // Retirement Progress
            if retirementTarget > 0 {
                HStack {
                    Text("Retirement Progress:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", (portfolioVM.totalValue / retirementTarget) * 100))
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }
            
            Divider()
            
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

            if portfolioVM.hasAssets {
                VStack(alignment: .leading, spacing: 4) {
                    // Show refresh status if cooldown is active
                    if let status = refreshStatus, !status.isAvailable {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text(status.displayText)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    } else {
                        Text("Pull to refresh")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show last update time for assets with live prices
                    if let mostRecentUpdate = portfolioVM.portfolio.assetsWithTickers
                        .compactMap({ $0.lastUpdated })
                        .max() {
                        Text("Updated \(timeAgo(from: mostRecentUpdate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    // Helper to display relative time
    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(seconds / 86400)
            return "\(days)d ago"
        }
    }
    
    // MARK: - Interactive Pie Chart
    
    private var interactivePieChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedAssetClass?.rawValue ?? "Asset Allocation")
                .font(.headline)
            
            Chart(allocationData) { item in
                SectorMark(
                    angle: .value("Value", item.value),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(colorForAssetClass(item.assetClass))
                .opacity(selectedAssetClass == nil || selectedAssetClass == item.assetClass ? 1.0 : 0.3)
            }
            .frame(height: 250)
            .chartAngleSelection(value: $selectedAngle)
            .onChange(of: selectedAngle) { _, newValue in
                if let angle = newValue {
                    handleChartTap(at: angle)
                }
            }
            
            // Interactive Legend (unified with pie chart colors)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(allocationData) { item in
                        Button(action: {
                            toggleAssetClass(item.assetClass)
                        }) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(colorForAssetClass(item.assetClass))
                                    .frame(width: 12, height: 12)
                                
                                Text(item.assetClass.rawValue)
                                    .font(.caption)
                                    .foregroundColor(selectedAssetClass == nil || selectedAssetClass == item.assetClass ? .primary : .secondary)
                                
                                Text(item.percentage.toPercent())
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedAssetClass == item.assetClass ?
                                          colorForAssetClass(item.assetClass).opacity(0.2) :
                                          Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedAssetClass == item.assetClass ?
                                           colorForAssetClass(item.assetClass) :
                                           Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            if let selected = selectedAssetClass {
                HStack {
                    Image(systemName: selected.iconName)
                        .foregroundColor(colorForAssetClass(selected))
                    Text("Showing \(selected.rawValue) only • Tap to show all")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            } else {
                Text("Tap any segment or legend item to filter by asset type")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    // MARK: - Controls Bar (Gain Display + Sort)
    
    private var controlsBar: some View {
        HStack(spacing: 16) {
            // Show gains as toggle
            HStack(spacing: 8) {
                Text("Show gains as")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Text("%")
                        .font(.subheadline)
                        .foregroundColor(showDollarGain ? .secondary : .primary)
                    
                    Toggle("", isOn: $showDollarGain)
                        .labelsHidden()
                    
                    Text("$")
                        .font(.subheadline)
                        .foregroundColor(showDollarGain ? .primary : .secondary)
                }
            }
            
            Spacer()
            
            // Sort menu
            Menu {
                Picker("Sort By", selection: $sortOption) {
                    ForEach(AssetSortOption.allCases) { option in
                        Label(option.rawValue, systemImage: option.iconName)
                            .tag(option)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("Sort")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    @State private var selectedAngle: Double?
    
    private var allocationData: [AllocationChartData] {
        portfolioVM.portfolio.assetAllocation
            .sorted { $0.value > $1.value }
            .map { assetClass, value in
                AllocationChartData(
                    assetClass: assetClass,
                    value: value,
                    percentage: value / portfolioVM.totalValue
                )
            }
    }
    
    private func handleChartTap(at angle: Double) {
        var cumulativeAngle: Double = 0
        let total = portfolioVM.totalValue
        
        for (assetClass, value) in portfolioVM.portfolio.assetAllocation.sorted(by: { $0.value > $1.value }) {
            let percentage = value / total
            let segmentAngle = percentage * 360
            
            if angle >= cumulativeAngle && angle < cumulativeAngle + segmentAngle {
                toggleAssetClass(assetClass)
                return
            }
            
            cumulativeAngle += segmentAngle
        }
    }
    
    private func toggleAssetClass(_ assetClass: AssetClass) {
        withAnimation {
            if selectedAssetClass == assetClass {
                selectedAssetClass = nil
            } else {
                selectedAssetClass = assetClass
            }
        }
    }
    
    private func colorForAssetClass(_ assetClass: AssetClass) -> Color {
        assetClass.color
    }
    
    // MARK: - Asset Group Sections
    
    private var allAssetGroupsSections: some View {
        ForEach(AssetClass.allCases) { assetClass in
            let assetsInClass = portfolioVM.portfolio.assets(for: assetClass)
            
            if !assetsInClass.isEmpty {
                assetGroupSection(for: assetClass)
            }
        }
    }
    
    private func assetGroupSection(for assetClass: AssetClass) -> some View {
        let assetsInClass = sortedAssets(portfolioVM.portfolio.assets(for: assetClass))
        let totalValue = portfolioVM.portfolio.totalValue(for: assetClass)
        let percentage = portfolioVM.totalValue > 0 ? totalValue / portfolioVM.totalValue : 0
        
        return VStack(alignment: .leading, spacing: 12) {
            // Colored Header (unified with pie chart colors)
            HStack {
                Image(systemName: assetClass.iconName)
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(assetClass.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(assetsInClass.count) asset\(assetsInClass.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(totalValue.toCurrency())
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(percentage.toPercent())
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            .background(colorForAssetClass(assetClass))
            .cornerRadius(12)
            
            // Bond Calculator Button
            if assetClass == .bonds || assetClass == .corporateBonds {
                Button(action: { showingBondCalculator = true }) {
                    HStack {
                        Image(systemName: "calculator")
                        Text("Bond Pricing Calculator")
                            .font(.caption)
                    }
                    .foregroundColor(.teal)
                }
                .padding(.horizontal)
            }
            
            // Assets in this class
            VStack(spacing: 0) {
                ForEach(assetsInClass) { asset in
                    Button(action: {
                        selectedAsset = asset
                    }) {
                        AssetRowView2(asset: asset, showDollarGain: showDollarGain)
                    }
                    .buttonStyle(.plain)
                    
                    if asset.id != assetsInClass.last?.id {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .padding(.vertical, 4)
    }
}

struct AllocationChartData: Identifiable {
    let id = UUID()
    let assetClass: AssetClass
    let value: Double
    let percentage: Double
}

// MARK: - Asset Row View

struct AssetRowView2: View {
    let asset: Asset
    let showDollarGain: Bool
    
    var body: some View {
        HStack {
            Image(systemName: asset.assetClass.iconName)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name.isEmpty ? (asset.ticker ?? "Unnamed Asset") : asset.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let ticker = asset.ticker {
                    Text(ticker)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(asset.totalValue.toCurrency())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                // Always show gain/loss if available (not just after refresh)
                if let change = asset.priceChange {
                    HStack(spacing: 2) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        
                        if showDollarGain {
                            // Calculate dollar gain from percentage change
                            let dollarGain = asset.totalValue * change
                            Text(dollarGain.toCurrency())
                                .font(.caption)
                        } else {
                            Text(change.toPercent())
                                .font(.caption)
                        }
                    }
                    .foregroundColor(change >= 0 ? .green : .red)
                } else if asset.hasLiveData {
                    // Show a placeholder if we have live data but no change info yet
                    Text("--")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationView {
        GroupedPortfolioView(portfolioVM: PortfolioViewModel(portfolio: .sample))
    }
}

