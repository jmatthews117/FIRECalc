//
//  StrategyComparisonView.swift
//  FIRECalc
//
//  Runs all four WithdrawalStrategy options with the same portfolio and
//  base parameters, then presents the results side-by-side so the user
//  can see exactly how strategy choice affects success rate, median
//  balance and annual income.
//

import SwiftUI
import Charts

// MARK: - Result model

struct StrategyComparisonResult: Identifiable {
    let id = UUID()
    let strategy: WithdrawalStrategy
    let successRate: Double
    let medianFinalBalance: Double
    let averageAnnualWithdrawal: Double
    let probabilityOfRuin: Double
    let yearlyMedians: [Double]   // median balance, year 0…N
}

// MARK: - View

struct StrategyComparisonView: View {

    /// The already-completed result that launched us: used to seed parameters
    /// and to provide the "current strategy" baseline.
    let baseResult: SimulationResult
    let portfolio: Portfolio

    // MARK: State

    @State private var comparisonResults: [StrategyComparisonResult] = []
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var selectedMetric: ComparisonMetric = .successRate

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Header ────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text("Strategy Comparison")
                    .font(.headline)
                Text("Same portfolio, same time horizon — four different withdrawal strategies. Which one fits your retirement best?")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // ── Metric picker ─────────────────────────────────────────────
            Picker("Metric", selection: $selectedMetric) {
                ForEach(ComparisonMetric.allCases) { metric in
                    Text(metric.label).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            // ── Content ───────────────────────────────────────────────────
            if isRunning {
                runningState
            } else if let err = errorMessage {
                errorState(err)
            } else if comparisonResults.isEmpty {
                idleState
            } else {
                resultsContent
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }

    // MARK: - States

    private var runningState: some View {
        VStack(spacing: 12) {
            ProgressView("Running \(WithdrawalStrategy.allCases.count) strategies…")
                .frame(maxWidth: .infinity)
            Text("Each strategy runs \(AppConstants.Simulation.quickSimulationRuns.formatted()) scenarios. This takes a few seconds.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            runButton
        }
        .padding(.vertical, 12)
    }

    private var idleState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 44))
                .foregroundColor(.blue)
            Text("Compare all four withdrawal strategies against your portfolio with a single tap.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            runButton
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private var runButton: some View {
        Button(action: runComparison) {
            Label("Run Comparison", systemImage: "play.fill")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(10)
        }
    }

    // MARK: - Results content

    @ViewBuilder
    private var resultsContent: some View {
        // 1. Bar chart for the selected metric
        metricChart

        // 2. Comparison table
        comparisonTable

        // 3. Trajectory chart (median balance over time, all strategies)
        trajectoryChart

        // 4. Recommendation
        recommendationCard

        // Re-run button
        HStack {
            Spacer()
            Button("Re-run Comparison", action: runComparison)
                .font(.caption)
                .foregroundColor(.blue)
        }
    }

    // MARK: - Bar chart

    private var metricChart: some View {
        let sorted = comparisonResults.sorted {
            selectedMetric.value(for: $0) > selectedMetric.value(for: $1)
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text(selectedMetric.label)
                .font(.subheadline)
                .fontWeight(.semibold)

            Chart(sorted) { item in
                BarMark(
                    x: .value("Value", selectedMetric.value(for: item)),
                    y: .value("Strategy", item.strategy.shortName)
                )
                .foregroundStyle(barColor(for: item, metric: selectedMetric).gradient)
                .cornerRadius(4)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(selectedMetric.format(selectedMetric.value(for: item)))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.leading, 4)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let name = value.as(String.self) {
                            Text(name)
                                .font(.caption2)
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .frame(height: CGFloat(comparisonResults.count) * 54)
        }
    }

    // MARK: - Comparison table

    private var comparisonTable: some View {
        VStack(spacing: 0) {

            // Table header
            HStack {
                Text("Strategy")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Success")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .frame(width: 56, alignment: .trailing)
                Text("Median")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .frame(width: 72, alignment: .trailing)
                Text("Annual $")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))

            Divider()

            // Rows
            ForEach(comparisonResults.sorted { $0.successRate > $1.successRate }) { item in
                tableRow(item)
                Divider()
            }
        }
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private func tableRow(_ item: StrategyComparisonResult) -> some View {
        let isCurrent = item.strategy == baseResult.parameters.withdrawalConfig.strategy

        return HStack {
            HStack(spacing: 6) {
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                Text(item.strategy.shortName)
                    .font(.caption)
                    .fontWeight(isCurrent ? .semibold : .regular)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(String(format: "%.0f%%", item.successRate * 100))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppConstants.Colors.successRateColor(for: item.successRate))
                .frame(width: 56, alignment: .trailing)

            Text(shortCurrency(item.medianFinalBalance))
                .font(.caption)
                .frame(width: 72, alignment: .trailing)

            Text(shortCurrency(item.averageAnnualWithdrawal))
                .font(.caption)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isCurrent ? Color.blue.opacity(0.05) : Color.clear)
    }

    // MARK: - Trajectory chart

    private var trajectoryChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Median Portfolio Balance Over Time")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text("All values in today's dollars (inflation-adjusted)")
                .font(.caption2)
                .foregroundColor(.secondary)

            let maxY = comparisonResults
                .flatMap(\.yearlyMedians)
                .max() ?? baseResult.parameters.initialPortfolioValue
            let years = baseResult.parameters.timeHorizonYears

            Chart {
                // Zero reference line
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.red.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1))

                ForEach(comparisonResults) { item in
                    ForEach(Array(item.yearlyMedians.enumerated()), id: \.offset) { (year, balance) in
                        LineMark(
                            x: .value("Year", year),
                            y: .value("Balance", balance)
                        )
                        .foregroundStyle(by: .value("Strategy", item.strategy.shortName))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartXScale(domain: 0...years)
            .chartYScale(domain: 0...(maxY * 1.1))
            .chartXAxisLabel("Year", alignment: .center)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(shortCurrency(v)).font(.caption2)
                        }
                    }
                }
            }
            .chartLegend(position: .bottom, alignment: .leading, spacing: 6)
            .frame(height: 220)
        }
    }

    // MARK: - Recommendation card

    private var recommendationCard: some View {
        let best = comparisonResults.max { $0.successRate < $1.successRate }
        let mostIncome = comparisonResults.max { $0.averageAnnualWithdrawal < $1.averageAnnualWithdrawal }
        let current = comparisonResults.first {
            $0.strategy == baseResult.parameters.withdrawalConfig.strategy
        }

        return VStack(alignment: .leading, spacing: 8) {
            Label("Takeaway", systemImage: "star")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.purple)

            if let best, let current {
                if best.strategy == current.strategy {
                    Text("Your current strategy (\(current.strategy.shortName)) has the highest success rate of all four options — a great choice for this portfolio.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("**\(best.strategy.shortName)** achieves the highest success rate (\(String(format: "%.0f%%", best.successRate * 100))) — \(String(format: "%.0f", (best.successRate - current.successRate) * 100)) points above your current strategy. It does this by reducing withdrawals in poor market years, preserving capital when you need it most.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let top = mostIncome, top.strategy != best?.strategy {
                Text("For the highest annual income, **\(top.strategy.shortName)** delivers \(shortCurrency(top.averageAnnualWithdrawal))/yr on average — but at a lower success rate of \(String(format: "%.0f%%", top.successRate * 100)).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.07))
        .cornerRadius(10)
    }

    // MARK: - Run logic

    private func runComparison() {
        isRunning = true
        errorMessage = nil
        comparisonResults = []

        Task {
            do {
                let results = try await performComparison()
                comparisonResults = results
            } catch {
                errorMessage = error.localizedDescription
            }
            isRunning = false
        }
    }

    private func performComparison() async throws -> [StrategyComparisonResult] {
        let engine = MonteCarloEngine()
        let historicalData = try HistoricalDataService.shared.loadHistoricalData()

        var results: [StrategyComparisonResult] = []

        for strategy in WithdrawalStrategy.allCases {
            // Build a config for this strategy using the baseline withdrawal rate.
            var config = WithdrawalConfiguration(
                strategy: strategy,
                withdrawalRate: baseResult.parameters.withdrawalConfig.withdrawalRate,
                annualAmount: baseResult.parameters.withdrawalConfig.annualAmount,
                adjustForInflation: baseResult.parameters.withdrawalConfig.adjustForInflation,
                inflationRate: baseResult.parameters.inflationRate,
                fixedIncomeReal: baseResult.parameters.withdrawalConfig.fixedIncomeReal,
                fixedIncomeNominal: baseResult.parameters.withdrawalConfig.fixedIncomeNominal,
                upperGuardrail: strategy == .guardrails ? (baseResult.parameters.withdrawalConfig.upperGuardrail ?? 0.05 * 1.25) : nil,
                lowerGuardrail: strategy == .guardrails ? (baseResult.parameters.withdrawalConfig.lowerGuardrail ?? 0.05 * 0.80) : nil,
                guardrailAdjustmentMagnitude: strategy == .guardrails ? (baseResult.parameters.withdrawalConfig.guardrailAdjustmentMagnitude ?? 0.10) : nil
            )

            // Fixed dollar: default to the implied dollar withdrawal from the base rate
            if strategy == .fixedDollar && config.annualAmount == nil {
                config.annualAmount = baseResult.parameters.initialPortfolioValue
                    * baseResult.parameters.withdrawalConfig.withdrawalRate
            }

            var params = baseResult.parameters
            params.withdrawalConfig = config
            // Use a quick run count so the comparison finishes promptly
            params.numberOfRuns = AppConstants.Simulation.quickSimulationRuns

            let simResult = try await engine.runSimulation(
                portfolio: portfolio,
                parameters: params,
                historicalData: historicalData
            )

            // Extract year-by-year medians (all years are retirement years)
            let medians: [Double] = simResult.yearlyBalances
                .sorted { $0.year < $1.year }
                .map(\.medianBalance)

            results.append(StrategyComparisonResult(
                strategy: strategy,
                successRate: simResult.successRate,
                medianFinalBalance: simResult.medianFinalBalance,
                averageAnnualWithdrawal: simResult.averageAnnualWithdrawal,
                probabilityOfRuin: simResult.probabilityOfRuin,
                yearlyMedians: medians
            ))
        }

        return results
    }

    // MARK: - Styling helpers

    private func barColor(for item: StrategyComparisonResult, metric: ComparisonMetric) -> Color {
        switch metric {
        case .successRate:
            return AppConstants.Colors.successRateColor(for: item.successRate)
        case .medianBalance:
            return item.strategy == baseResult.parameters.withdrawalConfig.strategy ? .blue : .teal
        case .annualIncome:
            return item.strategy == baseResult.parameters.withdrawalConfig.strategy ? .green : .teal
        }
    }

    private func shortCurrency(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        if value >= 1_000     { return String(format: "$%.0fK", value / 1_000) }
        return String(format: "$%.0f", value)
    }
}

// MARK: - Comparison metric

enum ComparisonMetric: String, CaseIterable, Identifiable {
    case successRate  = "success"
    case medianBalance = "balance"
    case annualIncome  = "income"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .successRate:   return "Success Rate"
        case .medianBalance: return "Median Balance"
        case .annualIncome:  return "Annual Income"
        }
    }

    func value(for item: StrategyComparisonResult) -> Double {
        switch self {
        case .successRate:   return item.successRate
        case .medianBalance: return item.medianFinalBalance
        case .annualIncome:  return item.averageAnnualWithdrawal
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .successRate:
            return String(format: "%.0f%%", value * 100)
        case .medianBalance, .annualIncome:
            if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
            if value >= 1_000     { return String(format: "$%.0fK", value / 1_000) }
            return String(format: "$%.0f", value)
        }
    }
}

// MARK: - WithdrawalStrategy short names

private extension WithdrawalStrategy {
    var shortName: String {
        switch self {
        case .fixedPercentage:   return "4% Rule"
        case .dynamicPercentage: return "Dynamic %"
        case .guardrails:        return "Guardrails"
        case .fixedDollar:       return "Fixed $"
        }
    }
}

#Preview {
    ScrollView {
        StrategyComparisonView(
            baseResult: .sample,
            portfolio: Portfolio(name: "Preview Portfolio")
        )
        .padding()
    }
}
