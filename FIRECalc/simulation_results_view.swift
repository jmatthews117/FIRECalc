//
//  simulation_results_view.swift
//  FIRECalc
//
//  MODIFIED - Added spaghetti chart and 10th-90th percentile bands
//

import SwiftUI
import Charts

struct SimulationResultsView: View {
    let result: SimulationResult
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChartType: ChartType = .spaghetti
    @State private var showAllPaths: Bool = false
    
    enum ChartType: String, CaseIterable {
        case spaghetti = "Spaghetti"
        case percentiles = "Percentiles"
        case distribution = "Distribution"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Success Rate Card
                    successRateCard
                    
                    // Key Metrics
                    keyMetricsGrid
                    
                    // Chart Type Picker
                    Picker("Chart Type", selection: $selectedChartType) {
                        ForEach(ChartType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Charts
                    switch selectedChartType {
                    case .spaghetti:
                        spaghettiChart
                    case .percentiles:
                        percentilesChart
                    case .distribution:
                        distributionChart
                    }
                    
                    // Detailed Statistics
                    detailedStats
                }
                .padding()
            }
            .navigationTitle("Simulation Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Success Rate Card
    
    private var successRateCard: some View {
        VStack(spacing: 16) {
            Text("Success Rate")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(String(format: "%.0f%%", result.successRate * 100))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(successRateColor)
            
            Text("Money lasted full \(result.parameters.timeHorizonYears) years")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ProgressView(value: result.successRate)
                .tint(successRateColor)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            Text(successInterpretation)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(successRateColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Key Metrics Grid
    
    private var keyMetricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(
                title: "Median Balance",
                value: result.medianFinalBalance.toCurrency(),
                subtitle: "After \(result.parameters.timeHorizonYears) years",
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )
            
            MetricCard(
                title: "Total Withdrawn",
                value: result.totalWithdrawn.toCurrency(),
                subtitle: "Over retirement",
                icon: "arrow.down.circle",
                color: .orange
            )
            
            MetricCard(
                title: "Annual Withdrawal",
                value: result.averageAnnualWithdrawal.toCurrency(),
                subtitle: "Average per year",
                icon: "dollarsign.circle",
                color: .green
            )
            
            MetricCard(
                title: "Max Drawdown",
                value: String(format: "%.0f%%", result.maxDrawdown * 100),
                subtitle: "Worst decline",
                icon: "chart.line.downtrend.xyaxis",
                color: .red
            )
        }
    }
    
    // MARK: - Spaghetti Chart
    
    private var spaghettiChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All Simulation Paths")
                    .font(.headline)
                
                Spacer()
                
                Toggle("Show All", isOn: $showAllPaths)
                    .toggleStyle(.button)
                    .controlSize(.small)
            }
            
            Text(showAllPaths ? "Showing all \(result.allSimulationRuns.count) paths" : "Showing 100 sample paths")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Chart {
                // Draw all individual paths
                let pathsToShow = showAllPaths ? result.allSimulationRuns : Array(result.allSimulationRuns.prefix(100))
                
                ForEach(pathsToShow, id: \.runNumber) { run in
                    ForEach(Array(run.yearlyBalances.enumerated()), id: \.offset) { index, balance in
                        if index < run.yearlyBalances.count - 1 {
                            LineMark(
                                x: .value("Year", index),
                                y: .value("Balance", balance)
                            )
                            .foregroundStyle(.blue.opacity(showAllPaths ? 0.05 : 0.15))
                            .lineStyle(StrokeStyle(lineWidth: showAllPaths ? 0.5 : 1))
                            .interpolationMethod(.linear)
                        }
                    }
                }
                
                // Median line (highlighted)
                ForEach(result.yearlyBalances) { projection in
                    LineMark(
                        x: .value("Year", projection.year),
                        y: .value("Balance", projection.medianBalance)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
            }
            .frame(height: 300)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let balance = value.as(Double.self) {
                            Text(formatChartValue(balance))
                        }
                    }
                }
            }
            
            HStack(spacing: 16) {
                Label("Individual Paths", systemImage: "line.diagonal")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Label("Median", systemImage: "line.diagonal")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    // MARK: - Percentiles Chart
    
    private var percentilesChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("10th-90th Percentile Range")
                .font(.headline)
            
            Chart {
                // 10th-90th percentile band
                ForEach(result.yearlyBalances) { projection in
                    AreaMark(
                        x: .value("Year", projection.year),
                        yStart: .value("10th", projection.percentile10Balance),
                        yEnd: .value("90th", projection.percentile90Balance)
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                }
                
                // 10th percentile line
                ForEach(result.yearlyBalances) { projection in
                    LineMark(
                        x: .value("Year", projection.year),
                        y: .value("10th", projection.percentile10Balance)
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                }
                
                // Median line
                ForEach(result.yearlyBalances) { projection in
                    LineMark(
                        x: .value("Year", projection.year),
                        y: .value("Median", projection.medianBalance)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
                
                // 90th percentile line
                ForEach(result.yearlyBalances) { projection in
                    LineMark(
                        x: .value("Year", projection.year),
                        y: .value("90th", projection.percentile90Balance)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
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
            
            HStack(spacing: 16) {
                Label("10th Percentile", systemImage: "square.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Label("Median", systemImage: "square.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Label("90th Percentile", systemImage: "square.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    // MARK: - Distribution Chart
    
    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Final Balance Distribution")
                .font(.headline)
            
            let buckets = createHistogramBuckets()
            
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Balance", bucket.label),
                    y: .value("Count", bucket.count)
                )
                .foregroundStyle(.blue.gradient)
            }
            .frame(height: 200)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("10th %ile")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.percentile10.toCurrency())
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Median")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.percentile50.toCurrency())
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("90th %ile")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.percentile90.toCurrency())
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    // MARK: - Detailed Stats
    
    private var detailedStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detailed Statistics")
                .font(.headline)
            
            StatRow(label: "Success Rate", value: String(format: "%.1f%%", result.successRate * 100))
            StatRow(label: "Probability of Ruin", value: String(format: "%.1f%%", result.probabilityOfRuin * 100))
            
            Divider()
            
            StatRow(label: "Mean Final Balance", value: result.meanFinalBalance.toCurrency())
            StatRow(label: "Median Final Balance", value: result.medianFinalBalance.toCurrency())
            
            Divider()
            
            StatRow(label: "10th Percentile", value: result.percentile10.toCurrency())
            StatRow(label: "25th Percentile", value: result.percentile25.toCurrency())
            StatRow(label: "75th Percentile", value: result.percentile75.toCurrency())
            StatRow(label: "90th Percentile", value: result.percentile90.toCurrency())
            
            Divider()
            
            StatRow(label: "Withdrawal Strategy", value: result.parameters.withdrawalConfig.strategy.rawValue)
            StatRow(label: "Withdrawal Rate", value: result.parameters.withdrawalConfig.withdrawalRate.toPercent())
            StatRow(label: "Simulation Runs", value: "\(result.parameters.numberOfRuns)")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    // MARK: - Helper Properties & Functions
    
    private var successRateColor: Color {
        if result.successRate >= 0.9 {
            return .green
        } else if result.successRate >= 0.75 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var successInterpretation: String {
        if result.successRate >= 0.95 {
            return "Excellent! Very high confidence your retirement plan will succeed."
        } else if result.successRate >= 0.85 {
            return "Good. Strong likelihood of success with some risk of shortfall."
        } else if result.successRate >= 0.75 {
            return "Moderate. Consider increasing savings or reducing withdrawal rate."
        } else {
            return "Concerning. High risk of running out of money. Review your plan."
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
    
    private func createHistogramBuckets() -> [HistogramBucket] {
        let sortedBalances = result.finalBalanceDistribution.sorted()
        let bucketCount = 10
        let bucketSize = sortedBalances.count / bucketCount
        
        var buckets: [HistogramBucket] = []
        
        for i in 0..<bucketCount {
            let start = i * bucketSize
            let end = min((i + 1) * bucketSize, sortedBalances.count)
            let bucketBalances = Array(sortedBalances[start..<end])
            
            if !bucketBalances.isEmpty {
                let avgBalance = bucketBalances.reduce(0, +) / Double(bucketBalances.count)
                buckets.append(HistogramBucket(
                    label: formatChartValue(avgBalance),
                    count: bucketBalances.count
                ))
            }
        }
        
        return buckets
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

struct HistogramBucket: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

#Preview {
    SimulationResultsView(result: .sample)
}
