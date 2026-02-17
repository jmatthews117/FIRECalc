//
//  RuinYearDistributionView.swift
//  FIRECalc
//
//  Shows WHEN failed simulation runs ran out of money — a histogram of
//  "ruin year" across all failing scenarios, plus key statistics.
//  Knowing *when* plans typically fail is far more actionable than a
//  single probability-of-ruin figure.
//

import SwiftUI
import Charts

// MARK: - Model

private struct RuinBucket: Identifiable {
    let id = UUID()
    let yearLabel: String   // e.g. "Year 18"
    let midYear: Int        // for x-axis positioning
    let count: Int          // number of failed runs in this bucket
    let fraction: Double    // count / totalFailed
}

// MARK: - View

struct RuinYearDistributionView: View {

    let runs: [SimulationRun]
    let timeHorizonYears: Int

    // Pre-computed in .task
    @State private var buckets:        [RuinBucket] = []
    @State private var medianRuinYear: Int?         = nil
    @State private var earlyRuinCount: Int          = 0   // ≤ first half of horizon
    @State private var lateRuinCount:  Int          = 0   // > first half
    @State private var totalFailed:    Int          = 0

    private let bucketSize = 5   // group into 5-year bands

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Header ────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text("When Do Plans Fail?")
                    .font(.headline)
                Text("Ruin year distribution across the \(totalFailed.formatted()) scenarios where the portfolio ran out of money.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if buckets.isEmpty && totalFailed == 0 {
                // All runs succeeded
                noFailuresView
            } else if buckets.isEmpty {
                ProgressView("Analysing failures…")
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                // ── Histogram ─────────────────────────────────────────────
                chart

                // ── Key statistics ────────────────────────────────────────
                statsRow

                // ── Insight text ──────────────────────────────────────────
                insightCard
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
        .task { await buildBuckets() }
    }

    // MARK: - No-failure state

    private var noFailuresView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("No Failures Recorded")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Every simulated scenario lasted the full \(timeHorizonYears)-year horizon. Your plan is very resilient — but consider stress-testing with a longer time horizon or higher withdrawal rate.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - Histogram chart

    private var chart: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Year Band", bucket.midYear),
                y: .value("Failed Runs", bucket.count),
                width: .fixed(barWidth)
            )
            .foregroundStyle(barColor(for: bucket.midYear).gradient)
            .cornerRadius(4)

            // Annotate bars that hold ≥ 10 % of total failures
            if bucket.fraction >= 0.10 {
                BarMark(
                    x: .value("Year Band", bucket.midYear),
                    y: .value("Failed Runs", bucket.count),
                    width: .fixed(barWidth)
                )
                .annotation(position: .top, alignment: .center) {
                    Text("\(Int(bucket.fraction * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .foregroundStyle(.clear)
            }
        }
        .chartXAxis {
            AxisMarks(values: buckets.map(\.midYear)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let y = value.as(Int.self) {
                        Text("Yr \(y)")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let c = value.as(Int.self) {
                        Text("\(c)").font(.caption2)
                    }
                }
            }
        }
        .chartXAxisLabel("Year Portfolio Ran Out", alignment: .center)
        .chartYAxisLabel("Number of Scenarios")
        .frame(height: 200)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {

            statCell(
                value: totalFailed.formatted(),
                label: "Failed runs",
                color: .red
            )

            Divider().frame(height: 44)

            statCell(
                value: medianRuinYear.map { "Year \($0)" } ?? "—",
                label: "Median ruin year",
                color: .orange
            )

            Divider().frame(height: 44)

            statCell(
                value: "\(Int(Double(earlyRuinCount) / Double(max(1, totalFailed)) * 100))%",
                label: "Fail in first half",
                color: .purple
            )
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Insight card

    private var insightCard: some View {
        let earlyFraction = Double(earlyRuinCount) / Double(max(1, totalFailed))

        let text: String
        if earlyFraction > 0.5 {
            text = "More than half of all failures happen in the first \(timeHorizonYears / 2) years. This is the classic sequence-of-returns trap: early drawdowns shrink the portfolio before it has a chance to recover. Consider a larger emergency buffer or a more conservative withdrawal rate in the early years."
        } else if let medYear = medianRuinYear, medYear > timeHorizonYears / 2 {
            text = "Most failures occur in the second half of the horizon (around year \(medYear)). This suggests your early-year buffer is adequate but long-lived inflation or longevity risk is the bigger threat. A COLA-linked income stream or delayed Social Security could help."
        } else {
            text = "Failures are spread across the full horizon. Consider a dynamic withdrawal strategy that automatically reduces spending in down-market years — the Guardrails method is well-suited to this pattern."
        }

        return VStack(alignment: .leading, spacing: 8) {
            Label("Insight", systemImage: "chart.bar.doc.horizontal")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.blue.opacity(0.07))
        .cornerRadius(10)
    }

    // MARK: - Data computation

    @MainActor
    private func buildBuckets() async {
        let (b, med, early, late, total) = await Task.detached(priority: .userInitiated) {
            Self.compute(runs: self.runs,
                         timeHorizonYears: self.timeHorizonYears,
                         bucketSize: self.bucketSize)
        }.value

        buckets        = b
        medianRuinYear = med
        earlyRuinCount = early
        lateRuinCount  = late
        totalFailed    = total
    }

    private static func compute(
        runs: [SimulationRun],
        timeHorizonYears: Int,
        bucketSize: Int
    ) -> ([RuinBucket], Int?, Int, Int, Int) {

        let failedRuns = runs.filter { !$0.success }
        guard !failedRuns.isEmpty else { return ([], nil, 0, 0, 0) }

        let ruinYears = failedRuns.map(\.yearsLasted).sorted()
        let total = ruinYears.count
        let halfHorizon = timeHorizonYears / 2

        let medianRuinYear = ruinYears[total / 2]
        let earlyRuinCount = ruinYears.filter { $0 <= halfHorizon }.count
        let lateRuinCount  = total - earlyRuinCount

        // Build 5-year buckets
        var buckets: [RuinBucket] = []
        var low = 1
        while low <= timeHorizonYears {
            let high = min(low + bucketSize - 1, timeHorizonYears)
            let midYear = (low + high) / 2
            let count = ruinYears.filter { $0 >= low && $0 <= high }.count
            if count > 0 {
                buckets.append(RuinBucket(
                    yearLabel: "Yr \(low)–\(high)",
                    midYear: midYear,
                    count: count,
                    fraction: Double(count) / Double(total)
                ))
            }
            low += bucketSize
        }

        return (buckets, medianRuinYear, earlyRuinCount, lateRuinCount, total)
    }

    // MARK: - Styling helpers

    private var barWidth: CGFloat {
        // Slightly narrower than one bucket width; looks good for 5-yr bands
        24
    }

    private func barColor(for year: Int) -> Color {
        let fraction = Double(year) / Double(timeHorizonYears)
        // Red for early failures, orange for mid, yellow-green for late
        if fraction < 0.33 { return .red }
        if fraction < 0.66 { return .orange }
        return .yellow
    }
}

#Preview {
    ScrollView {
        RuinYearDistributionView(
            runs: SimulationResult.sample.allSimulationRuns,
            timeHorizonYears: 30
        )
        .padding()
    }
}
