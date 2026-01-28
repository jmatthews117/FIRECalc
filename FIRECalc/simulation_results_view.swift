//
//  SimulationResultsView.swift
//  FIRECalc
//
//  Display Monte Carlo simulation results with charts
//

import SwiftUI
import Charts

struct SimulationResultsView: View {
    let result: SimulationResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Success Rate Card
                    successRateCard
                    
                    // Key Metrics
                    keyMetricsGrid
                    
                    // Projection Chart
                    projectionChart
                    
                    // Distribution Chart
                    distributionChart
                    
                    // Detailed Statistics
                    detailedStats
                }
                .padding()
            }
            .navigationTitle("Simulation Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
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
        .cornerRadius(AppConstants.UI.cornerRadius)
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
    
    // MARK: - Projection Chart
    
    private var projectionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Balance Projection")
                .font(.headline)
            
            Chart {
                // 10th percentile area
                ForEach(result.yearlyBalances) { projection in
                    AreaMark(
                        x: .value("Year", projection.year),
                        yStart: .value("Low", projection.percentile10Balance),
                        yEnd: .value("High", projection.percentile90Balance)
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                }
                
                // Median line
                ForEach(result.yearlyBalances) { projection in
                    LineMark(
                        x: .value("Year", projection.year),
                        y: .value("Balance", projection.medianBalance)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))
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
                Label("Median", systemImage: "line.diagonal")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Label("10th-90th Percentile", systemImage: "square.fill")
                    .font(.caption)
                    .foregroundColor(.blue.opacity(0.5))
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
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
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
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
            
            StatRow(label: "25th Percentile", value: result.percentile25.toCurrency())
            StatRow(label: "75th Percentile", value: result.percentile75.toCurrency())
            
            Divider()
            
            StatRow(label: "Withdrawal Strategy", value: result.parameters.withdrawalConfig.strategy.rawValue)
            StatRow(label: "Withdrawal Rate", value: result.parameters.withdrawalConfig.withdrawalRate.toPercent())
            StatRow(label: "Inflation Rate", value: result.parameters.inflationRate.toPercent())
            StatRow(label: "Simulation Runs", value: "\(result.parameters.numberOfRuns)")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    // MARK: - Helper Views & Functions
    
    private var successRateColor: Color {
        if result.successRate >= 0.9 {
            return AppConstants.Colors.success
        } else if result.successRate >= 0.75 {
            return AppConstants.Colors.warning
        } else {
            return AppConstants.Colors.danger
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
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
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
