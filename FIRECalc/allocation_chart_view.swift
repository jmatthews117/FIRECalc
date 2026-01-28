//
//  AllocationChartView.swift
//  FIRECalc
//
//  Asset allocation pie chart
//

import SwiftUI
import Charts

struct AllocationChartView: View {
    let portfolio: Portfolio
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Asset Allocation")
                .font(.headline)
            
            if portfolio.assets.isEmpty {
                emptyState
            } else {
                HStack(spacing: 20) {
                    // Pie Chart
                    Chart(allocationData) { item in
                        SectorMark(
                            angle: .value("Value", item.value),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("Class", item.assetClass.rawValue))
                        .opacity(0.8)
                    }
                    .frame(height: 200)
                    .chartLegend(position: .trailing, spacing: 8)
                    
                    Spacer()
                }
                
                // Detailed breakdown
                VStack(spacing: 8) {
                    ForEach(allocationData) { item in
                        AllocationRow(
                            assetClass: item.assetClass,
                            value: item.value,
                            percentage: item.percentage,
                            totalValue: portfolio.totalValue
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No assets to display")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    private var allocationData: [AllocationData] {
        portfolio.assetAllocation
            .sorted { $0.value > $1.value }
            .map { assetClass, value in
                AllocationData(
                    assetClass: assetClass,
                    value: value,
                    percentage: value / portfolio.totalValue
                )
            }
    }
}

struct AllocationData: Identifiable {
    let id = UUID()
    let assetClass: AssetClass
    let value: Double
    let percentage: Double
}

struct AllocationRow: View {
    let assetClass: AssetClass
    let value: Double
    let percentage: Double
    let totalValue: Double
    
    var body: some View {
        HStack {
            Image(systemName: assetClass.iconName)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(assetClass.rawValue)
                .font(.subheadline)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(value.toCurrency())
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(percentage.toPercent())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AllocationChartView(portfolio: .sample)
        .padding()
}
