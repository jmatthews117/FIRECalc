//
//  HistoricalReturnsView.swift
//  FIRECalc
//
//  View historical return statistics for each asset class
//

import SwiftUI
import Charts

struct HistoricalReturnsView: View {
    @State private var selectedAssetClass: AssetClass = .stocks
    @State private var historicalData: HistoricalData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Asset Class Picker
                assetClassPicker
                
                if isLoading {
                    ProgressView("Loading historical data...")
                        .padding()
                } else if let error = errorMessage {
                    errorView(error)
                } else if let data = historicalData {
                    // Summary Statistics Card
                    statisticsCard(for: selectedAssetClass, data: data)
                    
                    // Distribution Chart
                    distributionChart(for: selectedAssetClass, data: data)
                    
                    // Year-by-Year Returns
                    yearlyReturnsChart(for: selectedAssetClass, data: data)
                    
                    // Best/Worst Years
                    extremesCard(for: selectedAssetClass, data: data)
                }
            }
            .padding()
        }
        .navigationTitle("Historical Returns")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadData)
    }
    
    // MARK: - Asset Class Picker
    
    private var assetClassPicker: some View {
        Picker("Asset Class", selection: $selectedAssetClass) {
            ForEach(AssetClass.allCases) { assetClass in
                HStack {
                    Image(systemName: assetClass.iconName)
                    Text(assetClass.rawValue)
                }
                .tag(assetClass)
            }
        }
        .pickerStyle(.menu)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    // MARK: - Statistics Card
    
    private func statisticsCard(for assetClass: AssetClass, data: HistoricalData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: assetClass.iconName)
                    .font(.title2)
                    .foregroundColor(.blue)
                Text(assetClass.rawValue)
                    .font(.headline)
            }
            
            if let summary = data.summary(for: assetClass) {
                VStack(spacing: 12) {
                    StatisticRow(
                        label: "Average Annual Return",
                        value: summary.mean.toPercent(),
                        color: summary.mean >= 0 ? .green : .red,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                    
                    Divider()
                    
                    StatisticRow(
                        label: "Median Return",
                        value: summary.median.toPercent(),
                        color: .blue,
                        icon: "chart.bar.fill"
                    )
                    
                    Divider()
                    
                    StatisticRow(
                        label: "Standard Deviation (Volatility)",
                        value: summary.standardDeviation.toPercent(),
                        color: .orange,
                        icon: "waveform.path.ecg"
                    )
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.red)
                                Text("Worst Year")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(summary.min.toPercent())
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack {
                                Text("Best Year")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.green)
                            }
                            Text(summary.max.toPercent())
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("No historical data available for this asset class")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Interpretation
            if let summary = data.summary(for: assetClass) {
                Text(interpretation(for: summary))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    // MARK: - Distribution Chart
    
    private func distributionChart(for assetClass: AssetClass, data: HistoricalData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Return Distribution")
                .font(.headline)
            
            let returns = data.returns(for: assetClass)
            let buckets = createHistogramBuckets(returns: returns)
            
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Return", bucket.label),
                    y: .value("Frequency", bucket.count)
                )
                .foregroundStyle(.blue.gradient)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption2)
                        }
                    }
                }
            }
            
            Text("Shows how often different return levels occurred historically")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    // MARK: - Yearly Returns Chart
    
    private func yearlyReturnsChart(for assetClass: AssetClass, data: HistoricalData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Year-by-Year Returns")
                .font(.headline)
            
            let returns = data.returns(for: assetClass)
            let metadata = data.metadata
            
            Chart {
                ForEach(Array(returns.enumerated()), id: \.offset) { index, returnValue in
                    let year = metadata.startYear + index
                    
                    BarMark(
                        x: .value("Year", year),
                        y: .value("Return", returnValue)
                    )
                    .foregroundStyle(returnValue >= 0 ? Color.green.gradient : Color.red.gradient)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let returnVal = value.as(Double.self) {
                            Text(String(format: "%.0f%%", returnVal * 100))
                        }
                    }
                }
            }
            
            Text("\(metadata.endYear - metadata.startYear + 1) years of data (\(metadata.startYear)-\(metadata.endYear))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    // MARK: - Extremes Card
    
    private func extremesCard(for assetClass: AssetClass, data: HistoricalData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notable Periods")
                .font(.headline)
            
            let returns = data.returns(for: assetClass)
            let metadata = data.metadata
            
            // Find best consecutive years
            if let bestStreak = findBestStreak(returns: returns) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.green)
                        Text("Best \(bestStreak.length)-Year Period")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text("\(metadata.startYear + bestStreak.startIndex) - \(metadata.startYear + bestStreak.startIndex + bestStreak.length - 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Average: \(bestStreak.avgReturn.toPercent()) per year")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Find worst consecutive years
            if let worstStreak = findWorstStreak(returns: returns) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .foregroundColor(.red)
                        Text("Worst \(worstStreak.length)-Year Period")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text("\(metadata.startYear + worstStreak.startIndex) - \(metadata.startYear + worstStreak.startIndex + worstStreak.length - 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Average: \(worstStreak.avgReturn.toPercent()) per year")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error Loading Data")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    
    private func loadData() {
        Task {
            do {
                let data = try HistoricalDataService.shared.loadHistoricalData()
                await MainActor.run {
                    historicalData = data
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func interpretation(for summary: ReturnSummary) -> String {
        let mean = summary.mean
        let stdDev = summary.standardDeviation
        
        if stdDev > 0.30 {
            return "Very high volatility. Expect large swings in value year-to-year. Two-thirds of years typically fall between \((mean - stdDev).toPercent()) and \((mean + stdDev).toPercent())."
        } else if stdDev > 0.15 {
            return "High volatility. Returns vary significantly. Two-thirds of years typically fall between \((mean - stdDev).toPercent()) and \((mean + stdDev).toPercent())."
        } else if stdDev > 0.08 {
            return "Moderate volatility. Returns are fairly consistent. Two-thirds of years typically fall between \((mean - stdDev).toPercent()) and \((mean + stdDev).toPercent())."
        } else {
            return "Low volatility. Returns are relatively stable. Two-thirds of years typically fall between \((mean - stdDev).toPercent()) and \((mean + stdDev).toPercent())."
        }
    }
    
    private func createHistogramBuckets(returns: [Double]) -> [HistogramBucket] {
        guard !returns.isEmpty else { return [] }
        
        let bucketCount = 10
        let minReturn = returns.min() ?? 0
        let maxReturn = returns.max() ?? 0
        let range = maxReturn - minReturn
        let bucketSize = range / Double(bucketCount)
        
        var buckets: [HistogramBucket] = []
        
        for i in 0..<bucketCount {
            let lowerBound = minReturn + Double(i) * bucketSize
            let upperBound = lowerBound + bucketSize
            
            let count = returns.filter { $0 >= lowerBound && $0 < upperBound }.count
            
            let label = String(format: "%.0f%%", lowerBound * 100)
            buckets.append(HistogramBucket(label: label, count: count))
        }
        
        return buckets
    }
    
    private func findBestStreak(returns: [Double], length: Int = 5) -> Streak? {
        guard returns.count >= length else { return nil }
        
        var bestAvg: Double = -.infinity
        var bestStart = 0
        
        for i in 0...(returns.count - length) {
            let slice = Array(returns[i..<(i + length)])
            let avg = slice.reduce(0, +) / Double(length)
            
            if avg > bestAvg {
                bestAvg = avg
                bestStart = i
            }
        }
        
        return Streak(startIndex: bestStart, length: length, avgReturn: bestAvg)
    }
    
    private func findWorstStreak(returns: [Double], length: Int = 5) -> Streak? {
        guard returns.count >= length else { return nil }
        
        var worstAvg: Double = .infinity
        var worstStart = 0
        
        for i in 0...(returns.count - length) {
            let slice = Array(returns[i..<(i + length)])
            let avg = slice.reduce(0, +) / Double(length)
            
            if avg < worstAvg {
                worstAvg = avg
                worstStart = i
            }
        }
        
        return Streak(startIndex: worstStart, length: length, avgReturn: worstAvg)
    }
}

// MARK: - Supporting Views

struct StatisticRow: View {
    let label: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct Streak {
    let startIndex: Int
    let length: Int
    let avgReturn: Double
}

#Preview {
    NavigationView {
        HistoricalReturnsView()
    }
}
