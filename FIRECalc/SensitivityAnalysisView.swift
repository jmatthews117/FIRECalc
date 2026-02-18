//
//  SensitivityAnalysisView.swift
//  FIRECalc
//
//  Shows how the FIRE date shifts as spending or savings rate changes —
//  a sensitivity / "what-if" grid for retirement planning.
//

import SwiftUI
import Charts

// MARK: - Data Model

private struct SensitivityPoint: Identifiable {
    let id = UUID()
    let xValue: Double      // the variable being swept (spending or savings)
    let years: Int?         // nil if not achievable within 100 years
    let retirementAge: Int?
}

// MARK: - Main View

struct SensitivityAnalysisView: View {

    @ObservedObject var portfolioVM: PortfolioViewModel

    // Settings-backed values (mirroring DashboardTabView)
    @AppStorage("current_age")           private var storedCurrentAge: Int    = 0
    @AppStorage("annual_savings")        private var storedAnnualSavings: Double = 0
    @AppStorage("expected_annual_spend") private var storedAnnualSpend: Double  = 0
    @AppStorage("withdrawal_percentage") private var storedWithdrawalRate: Double = 0

    enum SweepVariable: String, CaseIterable, Identifiable {
        case spending = "Annual Spending"
        case savings  = "Annual Savings"
        var id: String { rawValue }
    }

    @State private var sweepVariable: SweepVariable = .spending

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !portfolioVM.hasAssets || baselineSpend == 0 || baselineAge == nil {
                    requirementsCard
                } else {
                    inputSummaryCard
                    sweepPickerCard
                    chartCard
                    tableCard
                }
            }
            .padding()
        }
        .navigationTitle("Sensitivity Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Baseline Helpers

    private var baselineAge: Int? {
        storedCurrentAge > 0 ? storedCurrentAge : nil
    }

    private var baselineSpend: Double { storedAnnualSpend }

    private var baselineSavings: Double { storedAnnualSavings }

    private var withdrawalRate: Double {
        storedWithdrawalRate > 0 ? storedWithdrawalRate : 0.04
    }

    private var annualReturn: Double {
        portfolioVM.portfolio.weightedExpectedReturn
    }

    // MARK: - Requirements Card

    private var requirementsCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("Setup required")
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                requirementRow(met: portfolioVM.hasAssets,   text: "Add assets to your portfolio")
                requirementRow(met: baselineAge != nil,      text: "Set your current age in Settings")
                requirementRow(met: baselineSpend > 0,       text: "Set your expected annual spend in Settings")
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }

    private func requirementRow(met: Bool, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundColor(met ? .green : .secondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(met ? .primary : .secondary)
        }
    }

    // MARK: - Input Summary Card

    private var inputSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Your Baseline")
                    .font(.headline)
            }
            HStack(spacing: 0) {
                summaryTile(label: "Portfolio",    value: portfolioVM.totalValue.toCurrency(),          color: .blue)
                summaryTile(label: "Spend/yr",     value: baselineSpend.toCurrency(),                    color: .orange)
                summaryTile(label: "Savings/yr",   value: baselineSavings.toCurrency(),                  color: .green)
                summaryTile(label: "Return",        value: annualReturn.toPercent(),                      color: .purple)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }

    private func summaryTile(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sweep Picker Card

    private var sweepPickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text("What to vary")
                    .font(.headline)
            }
            Picker("Sweep variable", selection: $sweepVariable) {
                ForEach(SweepVariable.allCases) { v in
                    Text(v.rawValue).tag(v)
                }
            }
            .pickerStyle(.segmented)

            Text(sweepVariable == .spending
                 ? "See how your retirement date shifts as annual spending changes."
                 : "See how your retirement date shifts as your annual savings rate changes.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Years to FIRE")
                    .font(.headline)
                Spacer()
                // Baseline dot legend
                HStack(spacing: 4) {
                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                    Text("baseline").font(.caption2).foregroundColor(.secondary)
                }
            }

            let points = sweepPoints.filter { $0.years != nil }
            let allPoints = sweepPoints

            if points.isEmpty {
                Text("No achievable FIRE dates in range — try adjusting your settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                let xMin = allPoints.map(\.xValue).min() ?? 0
                let xMax = allPoints.map(\.xValue).max() ?? 1

                Chart {
                    ForEach(points) { pt in
                        LineMark(
                            x: .value(sweepVariable.rawValue, pt.xValue),
                            y: .value("Years to FIRE", pt.years ?? 0)
                        )
                        .foregroundStyle(Color.orange.gradient)
                        .interpolationMethod(.catmullRom)
                    }
                    ForEach(points) { pt in
                        PointMark(
                            x: .value(sweepVariable.rawValue, pt.xValue),
                            y: .value("Years to FIRE", pt.years ?? 0)
                        )
                        .foregroundStyle(isBaseline(pt) ? Color.orange : Color.orange.opacity(0.4))
                        .symbolSize(isBaseline(pt) ? 80 : 30)
                    }
                    // Baseline rule line
                    if let baseline = baselineX {
                        RuleMark(x: .value("Baseline", baseline))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                }
                .chartXScale(domain: xMin...xMax)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { val in
                        AxisValueLabel {
                            if let d = val.as(Double.self) {
                                Text(compactCurrency(d))
                                    .font(.caption2)
                            }
                        }
                        AxisTick()
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { val in
                        AxisValueLabel {
                            if let i = val.as(Int.self) {
                                Text("\(i)yr").font(.caption2)
                            }
                        }
                        AxisTick()
                        AxisGridLine()
                    }
                }
                .frame(height: 220)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }

    // MARK: - Table Card

    private var tableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tablecells")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Full Breakdown")
                    .font(.headline)
            }

            // Header
            HStack {
                Text(sweepVariable == .spending ? "Spend/yr" : "Savings/yr")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Years")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 60, alignment: .trailing)
                Text("Retire Age")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 80, alignment: .trailing)
            }
            .foregroundColor(.secondary)

            Divider()

            ForEach(sweepPoints) { pt in
                let isBase = isBaseline(pt)
                HStack {
                    HStack(spacing: 4) {
                        if isBase {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        Text(compactCurrency(pt.xValue))
                            .font(.subheadline)
                            .fontWeight(isBase ? .bold : .regular)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Group {
                        if let y = pt.years {
                            Text(y == 0 ? "Now" : "\(y)")
                        } else {
                            Text(">100")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(isBase ? .bold : .regular)
                    .frame(width: 60, alignment: .trailing)

                    Group {
                        if let age = pt.retirementAge {
                            Text("\(age)")
                                .foregroundColor(ageColor(age))
                        } else {
                            Text("—")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(isBase ? .bold : .regular)
                    .frame(width: 80, alignment: .trailing)
                }
                .padding(.vertical, 3)
                .background(isBase ? Color.orange.opacity(0.08) : Color.clear)
                .cornerRadius(6)

                if pt.id != sweepPoints.last?.id {
                    Divider()
                }
            }

            // Legend
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                Text("Your current baseline")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }

    // MARK: - Data Generation

    /// The X-axis value that corresponds to the user's current settings.
    private var baselineX: Double? {
        switch sweepVariable {
        case .spending: return baselineSpend > 0 ? baselineSpend : nil
        case .savings:  return baselineSavings
        }
    }

    /// Generate ~11 evenly-spaced sweep points centred on the baseline.
    private var sweepPoints: [SensitivityPoint] {
        guard let age = baselineAge else { return [] }
        let currentValue = portfolioVM.totalValue

        // Build the range around the baseline
        let baseline: Double
        let step: Double
        switch sweepVariable {
        case .spending:
            baseline = baselineSpend > 0 ? baselineSpend : 50_000
            step = max(1_000, (baseline * 0.10).rounded(-3))    // ±10% of baseline per step
        case .savings:
            baseline = baselineSavings
            step = max(1_000, (max(baseline, 10_000) * 0.20).rounded(-3))
        }

        // 11 points: baseline ±5 steps
        let values: [Double] = (-5...5).map { i in
            max(0, baseline + Double(i) * step)
        }

        return values.map { xVal in
            let spend:   Double
            let savings: Double
            switch sweepVariable {
            case .spending:  spend = xVal;        savings = baselineSavings
            case .savings:   spend = baselineSpend; savings = xVal
            }

            guard spend > 0 else {
                return SensitivityPoint(xValue: xVal, years: 0, retirementAge: age)
            }

            let target = spend / withdrawalRate
            if currentValue >= target {
                return SensitivityPoint(xValue: xVal, years: 0, retirementAge: age)
            }

            var value = currentValue
            for yr in 1...100 {
                value = value * (1 + annualReturn) + savings
                if value >= target {
                    return SensitivityPoint(xValue: xVal, years: yr, retirementAge: age + yr)
                }
            }
            return SensitivityPoint(xValue: xVal, years: nil, retirementAge: nil)
        }
    }

    private func isBaseline(_ pt: SensitivityPoint) -> Bool {
        guard let bx = baselineX else { return false }
        return abs(pt.xValue - bx) < 0.01
    }

    // MARK: - Formatting Helpers

    private func compactCurrency(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "$%.0fK", value / 1_000)
        }
        return value.toCurrency()
    }

    private func ageColor(_ age: Int) -> Color {
        switch age {
        case ..<40: return .green
        case 40..<50: return .blue
        case 50..<60: return .orange
        default: return .red
        }
    }
}

// MARK: - Double rounding helper (rounds to nearest N)

private extension Double {
    func rounded(_ places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self / divisor).rounded() * divisor
    }
}

#Preview {
    NavigationView {
        SensitivityAnalysisView(portfolioVM: PortfolioViewModel())
    }
}
