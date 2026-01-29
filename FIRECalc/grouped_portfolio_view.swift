//
//  grouped_portfolio_view.swift
//  FIRECalc
//
//  NEW FILE - Portfolio view grouped by asset type with interactive pie chart
//

import SwiftUI
import Charts

struct GroupedPortfolioView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @State private var selectedAssetClass: AssetClass?
    @State private var showingBondCalculator = false
    
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
                ToolbarItem(placement: .navigationBarTrailing) {
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
                .foregroundStyle(by: .value("Class", item.assetClass.rawValue))
                .opacity(selectedAssetClass == nil || selectedAssetClass == item.assetClass ? 1.0 : 0.3)
            }
            .frame(height: 250)
            .chartLegend(position: .bottom, spacing: 8)
            .chartAngleSelection(value: $selectedAngle)
            .onChange(of: selectedAngle) { _, newValue in
                if let angle = newValue {
                    selectAssetClass(at: angle)
                }
            }
            
            if let selected = selectedAssetClass {
                HStack {
                    Image(systemName: selected.iconName)
                        .foregroundColor(.blue)
                    Text("Showing \(selected.rawValue) • Tap chart again to show all")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            } else {
                Text("Tap any segment to filter by asset type")
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
    
    private func selectAssetClass(at angle: Double) {
        var cumulativeAngle: Double = 0
        let total = portfolioVM.totalValue
        
        for (assetClass, value) in portfolioVM.portfolio.assetAllocation.sorted(by: { $0.value > $1.value }) {
            let percentage = value / total
            let segmentAngle = percentage * 360
            
            if angle >= cumulativeAngle && angle < cumulativeAngle + segmentAngle {
                withAnimation {
                    if selectedAssetClass == assetClass {
                        selectedAssetClass = nil
                    } else {
                        selectedAssetClass = assetClass
                    }
                }
                return
            }
            
            cumulativeAngle += segmentAngle
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
            HStack {
                Image(systemName: assetClass.iconName)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(assetClass.rawValue)
                        .font(.headline)
                    Text("\(assetsInClass.count) asset\(assetsInClass.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(totalValue.toCurrency())
                        .font(.headline)
                    Text(percentage.toPercent())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if assetClass == .bonds {
                Button(action: { showingBondCalculator = true }) {
                    HStack {
                        Image(systemName: "calculator")
                        Text("Bond Pricing Calculator")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            Divider()
            
            ForEach(assetsInClass) { asset in
                AssetRowView(asset: asset)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct AllocationChartData: Identifiable {
    let id = UUID()
    let assetClass: AssetClass
    let value: Double
    let percentage: Double
}

#Preview {
    NavigationView {
        GroupedPortfolioView(portfolioVM: PortfolioViewModel(portfolio: .sample))
    }
}
