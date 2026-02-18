//
//  SequenceOfReturnsView.swift
//  FIRECalc
//
//  Visualises sequence-of-returns risk by grouping simulation runs into
//  three cohorts based on how the FIRST five years performed, then
//  overlaying their median balance trajectories.  A prominent "danger zone"
//  annotation highlights the critical early-retirement window.
//

import SwiftUI
import Charts

// MARK: - Model

/// The first-five-year median real return for one simulation run.
private struct RunEarlyReturn: Identifiable {
    let id: Int              // run number
    let earlyReturnMedian: Double
    let yearlyBalances: [Double]
    let success: Bool
}

/// One data point in the cohort-median trajectory chart.
struct CohortDataPoint: Identifiable {
    let id = UUID()
    let year: Int
    let medianBalance: Double
    let cohort: ReturnCohort
}

enum ReturnCohort: String, CaseIterable {
    case poorStart  = "Poor Start (bottom third)"
    case avgStart   = "Average Start (middle third)"
    case goodStart  = "Good Start (top third)"

    var color: Color {
        switch self {
        case .poorStart:  return .red
        case .avgStart:   return .orange
        case .goodStart:  return .green
        }
    }
}

// MARK: - View

struct SequenceOfReturnsView: View {

    let runs: [SimulationRun]
    let initialPortfolioValue: Double
    let timeHorizonYears: Int

    // Pre-computed once in .task
    @State private var cohortPoints: [CohortDataPoint] = []
    @State private var poorSuccessRate: Double = 0
    @State private var avgSuccessRate:  Double = 0
    @State private var goodSuccessRate: Double = 0

    // Number of early-retirement years to classify as the "danger zone"
    private let dangerZoneYears = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Header ────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text("Sequence of Returns Risk")
                    .font(.headline)
                Text("How the order of market returns — not just the average — shapes your retirement outcome. Bad early years are far more damaging than bad late years.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // ── Chart ─────────────────────────────────────────────────────
            if cohortPoints.isEmpty {
                ProgressView("Analysing scenarios…")
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                chart
            }

            // ── Cohort success-rate pills ─────────────────────────────────
            if !cohortPoints.isEmpty {
                successRatePills
            }

            // ── Explanation ───────────────────────────────────────────────
            explanationCard

        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
        .task { await buildCohortData() }
    }

    // MARK: - Chart

    private var chart: some View {
        let maxY = (cohortPoints.map(\.medianBalance).max() ?? initialPortfolioValue) * 1.1

        return Chart {

            // ── Danger zone background ────────────────────────────────────
            RectangleMark(
                xStart: .value("Zone Start", 0),
                xEnd:   .value("Zone End",   dangerZoneYears),
                yStart: .value("Bottom", 0),
                yEnd:   .value("Top",    maxY)
            )
            .foregroundStyle(Color.red.opacity(0.06))

            // ── Cohort trajectories ───────────────────────────────────────
            ForEach(cohortPoints) { point in
                LineMark(
                    x: .value("Year",    point.year),
                    y: .value("Balance", point.medianBalance)
                )
                .foregroundStyle(by: .value("Cohort", point.cohort.rawValue))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)
            }

            // ── Starting-value reference line ─────────────────────────────
            RuleMark(y: .value("Start", initialPortfolioValue))
                .foregroundStyle(Color.primary.opacity(0.25))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .annotation(position: .trailing, alignment: .leading) {
                    Text("Start")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

            // ── Danger zone boundary line ─────────────────────────────────
            RuleMark(x: .value("Danger End", dangerZoneYears))
                .foregroundStyle(Color.red.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .chartForegroundStyleScale([
            ReturnCohort.poorStart.rawValue: ReturnCohort.poorStart.color,
            ReturnCohort.avgStart.rawValue:  ReturnCohort.avgStart.color,
            ReturnCohort.goodStart.rawValue: ReturnCohort.goodStart.color,
        ])
        .chartXScale(domain: 0...timeHorizonYears)
        .chartYScale(domain: 0...maxY)
        .chartXAxisLabel("Years into Retirement", alignment: .center)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(shortCurrency(v)).font(.caption2)
                    }
                }
            }
        }
        .frame(height: 240)
        .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let xPos = proxy.position(forX: dangerZoneYears / 2) {
                    Text("⚠︎ Danger Zone")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(.systemBackground).opacity(0.85))
                        .cornerRadius(4)
                        .position(x: xPos + geo[proxy.plotFrame!].minX,
                                  y: geo[proxy.plotFrame!].minY + 16)
                }
            }
        }
    }

    // MARK: - Success-rate pills

    private var successRatePills: some View {
        HStack(spacing: 8) {
            ForEach([
                (ReturnCohort.poorStart, poorSuccessRate),
                (ReturnCohort.avgStart,  avgSuccessRate),
                (ReturnCohort.goodStart, goodSuccessRate),
            ], id: \.0) { cohort, rate in
                VStack(spacing: 2) {
                    Text(cohort == .poorStart ? "Poor Start" :
                         cohort == .avgStart  ? "Avg Start"  : "Good Start")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%%", rate * 100))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppConstants.Colors.successRateColor(for: rate))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(cohort.color.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Explanation card

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Why This Matters", systemImage: "lightbulb")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.orange)

            Text("Even with an identical average return, a retiree who experiences a market crash in year 1 has far less money working for them by year 5 than one whose crash comes in year 25. The shaded region marks the years where sequence risk is highest. Consider keeping 1–2 years of spending in cash or short bonds as a buffer.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.07))
        .cornerRadius(10)
    }

    // MARK: - Data computation

    @MainActor
    private func buildCohortData() async {
        let result = await Task.detached(priority: .userInitiated) {
            Self.compute(runs: self.runs,
                         initialPortfolioValue: self.initialPortfolioValue,
                         timeHorizonYears: self.timeHorizonYears)
        }.value

        cohortPoints    = result.0
        poorSuccessRate = result.1
        avgSuccessRate  = result.2
        goodSuccessRate = result.3
    }

    private static func compute(
        runs: [SimulationRun],
        initialPortfolioValue: Double,
        timeHorizonYears: Int
    ) -> ([CohortDataPoint], Double, Double, Double) {

        guard !runs.isEmpty else { return ([], 0, 0, 0) }

        // ── 1. Score each run by median real return in its first 5 retirement years ──
        let earlyWindow = min(5, timeHorizonYears)

        let scored: [RunEarlyReturn] = runs.map { run in
            // yearlyBalances[0] = starting balance; [1] = end of year 1, etc.
            var earlyReturns: [Double] = []
            let balances = run.yearlyBalances
            for y in 1...earlyWindow {
                guard y < balances.count, balances[y - 1] > 0 else { continue }
                earlyReturns.append((balances[y] - balances[y - 1]) / balances[y - 1])
            }
            let medEarlyReturn = earlyReturns.isEmpty ? 0 :
                earlyReturns.sorted()[earlyReturns.count / 2]
            return RunEarlyReturn(id: run.runNumber,
                                  earlyReturnMedian: medEarlyReturn,
                                  yearlyBalances: run.yearlyBalances,
                                  success: run.success)
        }.sorted { $0.earlyReturnMedian < $1.earlyReturnMedian }

        // ── 2. Split into three equal cohorts ─────────────────────────────
        let n = scored.count
        let third = n / 3
        let poor = Array(scored[0..<third])
        let avg  = Array(scored[third..<(2 * third)])
        let good = Array(scored[(2 * third)...])

        // ── 3. Build median trajectory for each cohort ────────────────────
        func medianTrajectory(group: [RunEarlyReturn], cohort: ReturnCohort) -> [CohortDataPoint] {
            guard !group.isEmpty else { return [] }
            var points: [CohortDataPoint] = []
            for year in 0...timeHorizonYears {
                let balancesThisYear = group.compactMap { run -> Double? in
                    guard year < run.yearlyBalances.count else { return nil }
                    return run.yearlyBalances[year]
                }.sorted()
                guard !balancesThisYear.isEmpty else { continue }
                let med = balancesThisYear[balancesThisYear.count / 2]
                points.append(CohortDataPoint(year: year, medianBalance: med, cohort: cohort))
            }
            return points
        }

        var allPoints: [CohortDataPoint] = []
        allPoints += medianTrajectory(group: poor, cohort: .poorStart)
        allPoints += medianTrajectory(group: avg,  cohort: .avgStart)
        allPoints += medianTrajectory(group: good, cohort: .goodStart)

        // ── 4. Success rates per cohort ───────────────────────────────────
        func successRate(_ group: [RunEarlyReturn]) -> Double {
            guard !group.isEmpty else { return 0 }
            return Double(group.filter(\.success).count) / Double(group.count)
        }

        return (allPoints,
                successRate(poor),
                successRate(avg),
                successRate(Array(good)))
    }

    // MARK: - Formatting

    private func shortCurrency(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        if value >= 1_000     { return String(format: "$%.0fK", value / 1_000) }
        return String(format: "$%.0f", value)
    }
}

#Preview {
    ScrollView {
        SequenceOfReturnsView(
            runs: SimulationResult.sample.allSimulationRuns,
            initialPortfolioValue: 1_000_000,
            timeHorizonYears: 30
        )
        .padding()
    }
}
