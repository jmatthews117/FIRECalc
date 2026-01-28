//
//  PerformanceTrackingView.swift
//  FIRECalc
//
//  Track portfolio performance over time
//

import SwiftUI
import Charts

struct PerformanceTrackingView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @State private var snapshots: [PerformanceSnapshot] = []
    @State private var showingAddSnapshot = false
    
    private let persistence = PersistenceService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current vs Initial
                if let firstSnapshot = snapshots.first {
                    comparisonCard(initial: firstSnapshot)
                }
                
                // Performance Chart
                if snapshots.count >= 2 {
                    performanceChart
                } else {
                    emptyChartState
                }
                
                // Snapshot History
                snapshotHistoryCard
                
                // Add Snapshot Button
                addSnapshotButton
            }
            .padding()
        }
        .navigationTitle("Performance Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadSnapshots)
        .alert("Snapshot Saved", isPresented: $showingAddSnapshot) {
            Button("OK") {}
        } message: {
            Text("Portfolio snapshot saved at \(portfolioVM.totalValue.toCurrency())")
        }
    }
    
    // MARK: - Comparison Card
    
    private func comparisonCard(initial: PerformanceSnapshot) -> some View {
        let currentValue = portfolioVM.totalValue
        let initialValue = initial.totalValue
        let change = currentValue - initialValue
        let changePercent = initialValue > 0 ? (change / initialValue) : 0
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Performance Summary")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Initial Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(initialValue.toCurrency())
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(initial.date.shortFormatted())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("Current Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currentValue.toCurrency())
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Today")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Change")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(change.toCurrency())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(change >= 0 ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Percent Change")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(changePercent.toPercent())
                    }
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(change >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    // MARK: - Performance Chart
    
    private var performanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Value Over Time")
                .font(.headline)
            
            Chart {
                ForEach(snapshots) { snapshot in
                    LineMark(
                        x: .value("Date", snapshot.date),
                        y: .value("Value", snapshot.totalValue)
                    )
                    .foregroundStyle(.blue.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    PointMark(
                        x: .value("Date", snapshot.date),
                        y: .value("Value", snapshot.totalValue)
                    )
                    .foregroundStyle(.blue)
                }
                
                // Current value (if different from last snapshot)
                if let lastSnapshot = snapshots.last,
                   abs(lastSnapshot.totalValue - portfolioVM.totalValue) > 1 {
                    PointMark(
                        x: .value("Date", Date()),
                        y: .value("Value", portfolioVM.totalValue)
                    )
                    .foregroundStyle(.green)
                    .symbolSize(100)
                }
            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let balance = value.as(Double.self) {
                            Text(formatChartValue(balance))
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
    
    private var emptyChartState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Not Enough Data")
                .font(.headline)
            
            Text("Take at least 2 snapshots to see your performance chart")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    // MARK: - Snapshot History Card
    
    private var snapshotHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Snapshot History")
                .font(.headline)
            
            if snapshots.isEmpty {
                Text("No snapshots yet. Take your first snapshot to start tracking!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(snapshots.reversed()) { snapshot in
                    SnapshotRow(snapshot: snapshot)
                    
                    if snapshot.id != snapshots.first?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    // MARK: - Add Snapshot Button
    
    private var addSnapshotButton: some View {
        Button(action: takeSnapshot) {
            HStack {
                Spacer()
                Image(systemName: "camera.fill")
                Text("Take Snapshot")
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(AppConstants.UI.cornerRadius)
        }
    }
    
    // MARK: - Actions
    
    private func loadSnapshots() {
        snapshots = (try? persistence.loadSnapshots()) ?? []
    }
    
    private func takeSnapshot() {
        let snapshot = PerformanceSnapshot(
            portfolioId: portfolioVM.portfolio.id,
            totalValue: portfolioVM.totalValue,
            allocation: portfolioVM.portfolio.assetAllocation,
            assets: portfolioVM.portfolio.assets
        )
        
        do {
            try persistence.saveSnapshot(snapshot)
            snapshots.append(snapshot)
            showingAddSnapshot = true
        } catch {
            print("Failed to save snapshot: \(error)")
        }
    }
    
    private func formatChartValue(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        } else if value >= 1000 {
            return String(format: "$%.0fK", value / 1000)
        } else {
            return String(format: "$%.0f", value)
        }
    }
}

// MARK: - Snapshot Row

struct SnapshotRow: View {
    let snapshot: PerformanceSnapshot
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.date.formatted())
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(snapshot.assets.count) assets")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(snapshot.totalValue.toCurrency())
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        PerformanceTrackingView(portfolioVM: PortfolioViewModel(portfolio: .sample))
    }
}
