//  simulation_results_view.swift
//  FIRECalc
//
//  FIXED - Proper histogram scaling and bucketing
//

import SwiftUI
import Charts

struct SimulationResultsView: View {
    let result: SimulationResult
    @Environment(\.dismiss) private var dismiss
    @State private var showHistogramFullScreen = false
    @State private var showSpaghettiFullScreen = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Success Rate Card
                    successRateCard
                    
                    // How It Works
                    howItWorksCard
                    
                    // Key Metrics
                    keyMetricsGrid
                    
                    // Ending Balance Distribution
                    endingBalanceHistogram
                        .onTapGesture { showHistogramFullScreen = true }
                    
                    // Spaghetti Chart of All Paths
                    spaghettiChartSection
                        .onTapGesture { showSpaghettiFullScreen = true }
                    
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
        .fullScreenCover(isPresented: $showHistogramFullScreen) {
            NavigationView {
                ScrollView { endingBalanceHistogram }
                    .navigationTitle("Ending Balance Distribution")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showHistogramFullScreen = false } } }
            }
        }
        .fullScreenCover(isPresented: $showSpaghettiFullScreen) {
            NavigationView {
                ScrollView { spaghettiChartSection }
                    .navigationTitle("All Simulated Paths")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showSpaghettiFullScreen = false } } }
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
    
    // MARK: - How It Works Card
    
    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("How This Simulation Works")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ExplanationRow(
                    icon: "repeat",
                    text: "Ran \(result.parameters.numberOfRuns.formatted()) different scenarios"
                )
                
                ExplanationRow(
                    icon: "calendar",
                    text: "Each scenario covers \(result.parameters.timeHorizonYears) years of retirement"
                )
                
                ExplanationRow(
                    icon: "chart.bar.fill",
                    text: "Used historical market data (1926-2024) to model realistic returns"
                )
                
                ExplanationRow(
                    icon: "arrow.down.circle",
                    text: "Applied \(result.parameters.withdrawalConfig.strategy.rawValue) withdrawal strategy"
                )
                
                ExplanationRow(
                    icon: "percent",
                    text: "Started with \(result.parameters.withdrawalConfig.withdrawalRate.toPercent()) withdrawal rate"
                )
            }
            
            Text("Each scenario uses real historical returns (adjusted for inflation) and preserves correlations between asset classes to simulate realistic market conditions.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
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
                title: "Failure Rate",
                value: String(format: "%.0f%%", result.probabilityOfRuin * 100),
                subtitle: "Ran out of money",
                icon: "exclamationmark.triangle",
                color: .red
            )
        }
    }
    
    // MARK: - Ending Balance Histogram (FIXED)
    
    private var endingBalanceHistogram: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ending Balance Distribution")
                .font(.headline)
            
            Text("Shows the final portfolio value after \(result.parameters.timeHorizonYears) years across all \(result.parameters.numberOfRuns.formatted()) scenarios")
                .font(.caption)
                .foregroundColor(.secondary)
            
            let buckets = createImprovedHistogramBuckets()
            
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Balance", bucket.midpoint),
                    y: .value("Count", bucket.count)
                )
                .foregroundStyle(bucket.isPositive ? Color.blue.gradient : Color.red.gradient)
            }
            .frame(height: 250)
            .chartXAxis {
                AxisMarks(position: .bottom, values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let balance = value.as(Double.self) {
                            Text(formatChartValue(balance))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let count = value.as(Int.self) {
                            Text("\(count)")
                                .font(.caption2)
                        }
                    }
                }
            }
            
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 12)
                    Text("Money Remaining")
                        .font(.caption)
                }
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 20, height: 12)
                    Text("Ran Out")
                        .font(.caption)
                }
            }
            .padding(.top, 4)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("10th Percentile")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.percentile10.toCurrency())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Median")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.percentile50.toCurrency())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("90th Percentile")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.percentile90.toCurrency())
                        .font(.subheadline)
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
    
    private var spaghettiChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Simulated Paths")
                .font(.headline)
            
            Text("Each line shows one scenario's portfolio balance over time")
                .font(.caption)
                .foregroundColor(.secondary)
            
            let series: [SpaghettiChartView.PathSeries] = result.allSimulationRuns.enumerated().map { (idx, run) in
                SpaghettiChartView.PathSeries(id: idx, values: run.yearlyBalances)
            }
            
            SpaghettiChartView(
                series: series,
                lineOpacity: 0.08,
                maxPathsToDraw: 600,
                yLabel: "Balance",
                xLabel: "Years"
            )
            .frame(height: 260)
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
    
    // FIXED: Improved histogram bucketing algorithm
    private func createImprovedHistogramBuckets() -> [ImprovedHistogramBucket] {
        let sortedBalances = result.finalBalanceDistribution.sorted()
        
        guard !sortedBalances.isEmpty else { return [] }
        
        let minBalance = sortedBalances.first ?? 0
        let maxBalance = sortedBalances.last ?? 0
        
        // Use 20 buckets for better resolution
        let bucketCount = 20
        
        // Calculate range and bucket size
        let range = maxBalance - minBalance
        let bucketSize = range / Double(bucketCount)
        
        var buckets: [ImprovedHistogramBucket] = []
        
        // Ensure bucket size is reasonable (at least $1)
        let effectiveBucketSize = max(bucketSize, 1.0)
        
        for i in 0..<bucketCount {
            let lowerBound = minBalance + Double(i) * effectiveBucketSize
            let upperBound = lowerBound + effectiveBucketSize
            
            // Count values in this bucket (inclusive lower, exclusive upper for all but last)
            let count = sortedBalances.filter { balance in
                if i == bucketCount - 1 {
                    // Last bucket includes upper bound
                    return balance >= lowerBound && balance <= upperBound
                } else {
                    return balance >= lowerBound && balance < upperBound
                }
            }.count
            
            // Only include buckets with data
            if count > 0 {
                let midpoint = lowerBound + effectiveBucketSize / 2
                buckets.append(ImprovedHistogramBucket(
                    lowerBound: lowerBound,
                    upperBound: upperBound,
                    midpoint: midpoint,
                    count: count,
                    isPositive: midpoint > 0
                ))
            }
        }
        
        return buckets
    }
    
    private func formatChartValue(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        } else if value >= 1000 {
            return String(format: "$%.0fK", value / 1000)
        } else if value >= 0 {
            return String(format: "$%.0f", value)
        } else if value <= -1_000_000 {
            return String(format: "-$%.1fM", abs(value) / 1_000_000)
        } else if value <= -1000 {
            return String(format: "-$%.0fK", abs(value) / 1000)
        } else {
            return String(format: "-$%.0f", abs(value))
        }
    }
}

// MARK: - Supporting Views

struct ExplanationRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}

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

// FIXED: Improved histogram bucket structure
struct ImprovedHistogramBucket: Identifiable {
    let id = UUID()
    let lowerBound: Double
    let upperBound: Double
    let midpoint: Double
    let count: Int
    let isPositive: Bool
}

#Preview {
    SimulationResultsView(result: .sample)
}

