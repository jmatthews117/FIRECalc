//  grouped_portfolio_view.swift
//  FIRECalc
//
//  Portfolio view grouped by asset type with interactive pie chart
//

import SwiftUI
import Charts

struct GroupedPortfolioView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @State private var selectedAssetClass: AssetClass?
    @State private var showingBondCalculator = false
    @State private var selectedAsset: Asset?
    @State private var showingAssetDetail = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Portfolio Summary
                portfolioSummaryCard
                
                // Interactive Pie Chart
                interactivePieChart
                
                // Grouped Assets
                if let selected = selectedAssetClass {
                    assetGroupSection(for: selected)
                } else {
                    allAssetGroupsSections
                }
            }
            .padding()
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
        .sheet(isPresented: $showingAssetDetail) {
            if let asset = selectedAsset {
                AssetDetailView(asset: asset, portfolioVM: portfolioVM)
            }
        }
    }
    
    // MARK: - Portfolio Summary Card
    
    private var portfolioSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total Value")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(portfolioVM.totalValue.toCurrency())
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            // Retirement Progress
            if portfolioVM.targetRetirementValue > 0 {
                HStack {
                    Text("Retirement Progress:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", (portfolioVM.totalValue / portfolioVM.targetRetirementValue) * 100))
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
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
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
        switch assetClass {
        case .stocks: return .blue
        case .bonds: return .green
        case .reits: return .purple
        case .realEstate: return .orange
        case .preciousMetals: return .yellow.opacity(0.8)
        case .crypto: return .pink
        case .cash: return .gray
        case .other: return .brown
        }
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
        let assetsInClass = portfolioVM.portfolio.assets(for: assetClass)
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
            if assetClass == .bonds {
                Button(action: { showingBondCalculator = true }) {
                    HStack {
                        Image(systemName: "calculator")
                        Text("Bond Pricing Calculator")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
            
            // Assets in this class
            VStack(spacing: 0) {
                ForEach(assetsInClass) { asset in
                    Button(action: {
                        selectedAsset = asset
                        showingAssetDetail = true
                    }) {
                        AssetRowView2(asset: asset)
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
                
                if let change = asset.priceChange {
                    HStack(spacing: 2) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text(change.toPercent())
                            .font(.caption)
                    }
                    .foregroundColor(change >= 0 ? .green : .red)
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

