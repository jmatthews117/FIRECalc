//
//  FIRECalculatorView.swift
//  FIRECalc
//
//  Calculate when you can retire based on income, savings rate, and expenses
//

import SwiftUI
import Charts

// MARK: - FIRE Calculator View Model

/// Holds all mutable FIRE calculator state so it survives NavigationLink
/// pushes and pops without being reset to defaults on every appearance.
class FIRECalculatorViewModel: ObservableObject {
    @Published var currentAge: Int = 35
    @Published var currentSavings: String = ""
    @Published var expectedReturn: Double = 0.07
    @Published var withdrawalRate: Double = 0.04
    @Published var inflationRate: Double = 0.025
    @Published var calculationResult: FIREResult?

    /// The annual savings contribution, kept in sync with the shared
    /// `"annual_savings"` UserDefaults key that Settings also reads/writes.
    @Published var annualSavingsContribution: String = "" {
        didSet {
            let value = Double(annualSavingsContribution) ?? 0
            UserDefaults.standard.set(value, forKey: "annual_savings")
        }
    }

    /// Annual retirement expenses, kept in sync with the shared
    /// `"expected_annual_spend"` UserDefaults key that Settings also reads/writes.
    @Published var annualExpenses: String = "" {
        didSet {
            let value = Double(annualExpenses) ?? 0
            UserDefaults.standard.set(value, forKey: "expected_annual_spend")
        }
    }

    init() {
        let savedSavings = UserDefaults.standard.double(forKey: "annual_savings")
        if savedSavings > 0 {
            annualSavingsContribution = String(format: "%.0f", savedSavings)
        }

        let savedExpenses = UserDefaults.standard.double(forKey: "expected_annual_spend")
        if savedExpenses > 0 {
            annualExpenses = String(format: "%.0f", savedExpenses)
        }
    }

    /// Call this to pull the latest values from UserDefaults (e.g. when the
    /// view appears after the user may have changed them in Settings).
    func syncFromUserDefaults() {
        let savedSavings = UserDefaults.standard.double(forKey: "annual_savings")
        let currentSavingsContribution = Double(annualSavingsContribution) ?? 0
        if savedSavings != currentSavingsContribution {
            annualSavingsContribution = savedSavings > 0 ? String(format: "%.0f", savedSavings) : ""
        }

        let savedExpenses = UserDefaults.standard.double(forKey: "expected_annual_spend")
        let currentExpenses = Double(annualExpenses) ?? 0
        if savedExpenses != currentExpenses {
            annualExpenses = savedExpenses > 0 ? String(format: "%.0f", savedExpenses) : ""
        }
    }
}

struct FIRECalculatorView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @ObservedObject var benefitManager: DefinedBenefitManager
    @ObservedObject var viewModel: FIRECalculatorViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // Projected FIRE Timeline summary
                    FIRETimelineCard(portfolioVM: portfolioVM, benefitManager: benefitManager)

                    // Input Section
                    inputSection

                    // Guaranteed income from pensions / Social Security
                    benefitIncomeCard

                    // Calculate Button
                    calculateButton
                        .id("calculateButton")

                    // Results Section
                    if let result = viewModel.calculationResult {
                        resultsSection(result: result)
                        pathwayChart(result: result)
                        milestonesSection(result: result)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.calculationResult?.fireYear) { _, newValue in
                if newValue != nil {
                    withAnimation {
                        proxy.scrollTo("calculateButton", anchor: .top)
                    }
                }
            }
        }
        .navigationTitle("FIRE Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneButton()
        .onAppear {
            // Always sync the current savings from the live portfolio value
            // so changes made outside this view (price refreshes, new assets,
            // edits, deletions) are reflected every time the view appears.
            if portfolioVM.totalValue > 0 {
                let raw = String(format: "%.0f", portfolioVM.totalValue)
                let nf = NumberFormatter()
                nf.numberStyle = .decimal
                nf.groupingSeparator = ","
                nf.maximumFractionDigits = 0
                viewModel.currentSavings = nf.string(from: NSNumber(value: Double(raw) ?? 0)) ?? raw
            }
            // Pull in any change the user may have made in Settings since
            // the last time this view was on screen.
            viewModel.syncFromUserDefaults()
        }
        // Keep current savings in sync while the view is visible — e.g. if a
        // price refresh completes or the user edits an asset in another tab.
        .onChange(of: portfolioVM.totalValue) { _, newValue in
            if newValue > 0 {
                let raw = String(format: "%.0f", newValue)
                let nf = NumberFormatter()
                nf.numberStyle = .decimal
                nf.groupingSeparator = ","
                nf.maximumFractionDigits = 0
                viewModel.currentSavings = nf.string(from: NSNumber(value: Double(raw) ?? 0)) ?? raw
            }
        }
        // Recalculate automatically whenever benefit plans change so the
        // results never show a stale projection.
        .onChange(of: benefitManager.plans) {
            if viewModel.calculationResult != nil { calculate() }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Information")
                .font(.headline)

            VStack(spacing: 16) {
                // Age
                HStack {
                    Text("Current Age")
                    Spacer()
                    TextField("Age", value: $viewModel.currentAge, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                // Current Savings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Savings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0", text: $viewModel.currentSavings)
                            .keyboardType(.decimalPad)
                            .onChange(of: viewModel.currentSavings) { oldValue, newValue in
                                let cleaned = newValue.replacingOccurrences(of: ",", with: "")
                                if let number = Double(cleaned) {
                                    let formatter = NumberFormatter()
                                    formatter.numberStyle = .decimal
                                    formatter.groupingSeparator = ","
                                    formatter.maximumFractionDigits = 2
                                    viewModel.currentSavings = formatter.string(from: NSNumber(value: number)) ?? cleaned
                                } else {
                                    viewModel.currentSavings = cleaned
                                }
                            }
                    }
                }

                // Annual Savings Contribution
                VStack(alignment: .leading, spacing: 8) {
                    Text("Annual Savings Contribution")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0", text: $viewModel.annualSavingsContribution)
                            .keyboardType(.decimalPad)
                            .onChange(of: viewModel.annualSavingsContribution) { oldValue, newValue in
                                let cleaned = newValue.replacingOccurrences(of: ",", with: "")
                                if let number = Double(cleaned) {
                                    let formatter = NumberFormatter()
                                    formatter.numberStyle = .decimal
                                    formatter.groupingSeparator = ","
                                    formatter.maximumFractionDigits = 2
                                    viewModel.annualSavingsContribution = formatter.string(from: NSNumber(value: number)) ?? cleaned
                                } else {
                                    viewModel.annualSavingsContribution = cleaned
                                }
                            }
                    }
                    Text("Amount you add to your portfolio each year")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Annual Expenses
                VStack(alignment: .leading, spacing: 8) {
                    Text("Annual Expenses in Retirement")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0", text: $viewModel.annualExpenses)
                            .keyboardType(.decimalPad)
                            .onChange(of: viewModel.annualExpenses) { oldValue, newValue in
                                let cleaned = newValue.replacingOccurrences(of: ",", with: "")
                                if let number = Double(cleaned) {
                                    let formatter = NumberFormatter()
                                    formatter.numberStyle = .decimal
                                    formatter.groupingSeparator = ","
                                    formatter.maximumFractionDigits = 2
                                    viewModel.annualExpenses = formatter.string(from: NSNumber(value: number)) ?? cleaned
                                } else {
                                    viewModel.annualExpenses = cleaned
                                }
                            }
                    }
                }

                Divider()

                // Advanced Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Assumptions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Expected Return")
                            Spacer()
                            Text(viewModel.expectedReturn.toPercent())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $viewModel.expectedReturn, in: 0...0.15, step: 0.005)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Withdrawal Rate")
                            Spacer()
                            Text(viewModel.withdrawalRate.toPercent())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $viewModel.withdrawalRate, in: 0.025...0.06, step: 0.005)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Inflation Rate")
                            Spacer()
                            Text(viewModel.inflationRate.toPercent())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $viewModel.inflationRate, in: 0...0.05, step: 0.005)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }

    // MARK: - Benefit Income Card

    @ViewBuilder
    private var benefitIncomeCard: some View {
        if !benefitManager.plans.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "building.columns")
                        .foregroundColor(.blue)
                    Text("Guaranteed Income")
                        .font(.headline)
                    Spacer()
                }

                ForEach(benefitManager.plans) { plan in
                    HStack {
                        Image(systemName: plan.type.iconName)
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.name)
                                .font(.subheadline)
                            Text("Starts age \(plan.startAge)\(plan.inflationAdjusted ? " · COLA" : "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(plan.annualBenefit.toCurrency() + "/yr")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }

                Divider()

                HStack {
                    Text("Total Benefit Income")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(benefitManager.plans.reduce(0, { $0 + $1.annualBenefit }).toCurrency() + "/yr")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                Text("These income streams reduce the portfolio size you need to hit FIRE.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(AppConstants.UI.cornerRadius)
        }
    }

    // MARK: - Calculate Button

    private var calculateButton: some View {
        Button(action: calculate) {
            HStack {
                Spacer()
                Image(systemName: "calculator")
                Text("Calculate FIRE Date")
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(AppConstants.UI.cornerRadius)
        }
        .disabled(!isValid)
    }

    // MARK: - Results Section

    private func resultsSection(result: FIREResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your FIRE Journey")
                .font(.headline)

            // FIRE Date
            VStack(spacing: 8) {
                Text("You Can Retire At")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Age \(result.fireAge)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)

                Text("In \(result.yearsToFIRE) years (\(result.fireYear))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)

            // Guaranteed income breakdown (only shown when plans exist)
            if result.benefitIncomeAtFIRE > 0 {
                incomeBreakdownCard(result: result)
            }

            Divider()

            // Key Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                MetricCard(
                    title: "FIRE Number",
                    value: result.effectiveFireNumber.toCurrency(),
                    subtitle: result.benefitIncomeAtFIRE > 0
                        ? "Portfolio target\n(after guaranteed income)"
                        : "Target portfolio",
                    icon: "target",
                    color: .blue
                )

                MetricCard(
                    title: result.benefitIncomeAtFIRE > 0 ? "Portfolio Draw" : "Annual Expenses",
                    value: result.benefitIncomeAtFIRE > 0
                        ? result.portfolioWithdrawalAtFIRE.toCurrency()
                        : result.annualExpenses.toCurrency(),
                    subtitle: result.benefitIncomeAtFIRE > 0
                        ? "From portfolio per year"
                        : "Total per year",
                    icon: "arrow.down.circle",
                    color: .green
                )

                MetricCard(
                    title: "Annual Savings",
                    value: result.annualSavings.toCurrency(),
                    subtitle: "Per year",
                    icon: "banknote",
                    color: .teal
                )

                MetricCard(
                    title: "Total Saved",
                    value: result.totalContributions.toCurrency(),
                    subtitle: "Your contributions",
                    icon: "dollarsign.circle",
                    color: .purple
                )

                MetricCard(
                    title: "Investment Gains",
                    value: result.investmentGains.toCurrency(),
                    subtitle: "Market returns",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange
                )

                if result.benefitIncomeAtFIRE > 0 {
                    MetricCard(
                        title: "Gross FIRE Number",
                        value: result.grossFireNumber.toCurrency(),
                        subtitle: "Without guaranteed income",
                        icon: "number.circle",
                        color: .gray
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }

    // MARK: - Income Breakdown Card

    @ViewBuilder
    private func incomeBreakdownCard(result: FIREResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("How Your Expenses Are Covered at \(result.fireAge)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            // Expense bar showing portfolio vs. guaranteed income split
            let totalExpenses = result.annualExpenses
            let benefitFraction = min(1.0, result.benefitIncomeAtFIRE / totalExpenses)
            let portfolioFraction = 1.0 - benefitFraction

            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * portfolioFraction)
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geo.size.width * benefitFraction)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 14)

            HStack {
                Label(
                    "\(result.portfolioWithdrawalAtFIRE.toCurrency())/yr from portfolio",
                    systemImage: "chart.bar"
                )
                .font(.caption)
                .foregroundColor(.blue)

                Spacer()

                Label(
                    "\(result.benefitIncomeAtFIRE.toCurrency())/yr guaranteed",
                    systemImage: "building.columns"
                )
                .font(.caption)
                .foregroundColor(.green)
            }

            if result.fullyFundedByBenefits {
                Text("🎉 Your guaranteed income fully covers your expenses — no portfolio withdrawal needed!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 2)
            } else {
                Text("Guaranteed income covers \(Int(benefitFraction * 100))% of expenses, reducing the portfolio you need to build.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(Color.green.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Pathway Chart

    private func pathwayChart(result: FIREResult) -> some View {
        // X axis = age, starting at the user's current age.
        let startAge = result.yearlyProjections.first?.age ?? viewModel.currentAge
        let endAge   = result.yearlyProjections.last?.age  ?? result.fireAge
        let xCeiling = endAge + max(2, (endAge - startAge) / 10)

        // Y axis = portfolio value ($), starting at $0 so the exponential
        // shape of compound growth is fully visible from the origin.
        let maxPortfolioValue = result.yearlyProjections.map(\.portfolioValue).max() ?? 0
        let yCeiling = max(result.grossFireNumber, maxPortfolioValue) * 1.1

        return VStack(alignment: .leading, spacing: 12) {
            Text("Path to FIRE")
                .font(.headline)

            Chart {
                // Smooth portfolio growth curve — X = age, Y = $ value.
                // Compound growth produces the classic upward-accelerating
                // (exponential) shape when time runs left-to-right.
                ForEach(result.yearlyProjections, id: \.year) { projection in
                    LineMark(
                        x: .value("Age", projection.age),
                        y: .value("Portfolio Value", projection.portfolioValue)
                    )
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.catmullRom)
                }

                // Area fill beneath the curve for visual depth.
                ForEach(result.yearlyProjections, id: \.year) { projection in
                    AreaMark(
                        x: .value("Age", projection.age),
                        yStart: .value("$0", 0),
                        yEnd: .value("Portfolio Value", projection.portfolioValue)
                    )
                    .foregroundStyle(Color.blue.opacity(0.12))
                    .interpolationMethod(.catmullRom)
                }

                // Flat horizontal green FIRE target line — zero slope, sits at
                // the constant effective FIRE number across all ages.
                RuleMark(y: .value("FIRE Target", result.effectiveFireNumber))
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                // Faint grey reference at the gross (no-benefit) target.
                if result.benefitIncomeAtFIRE > 0,
                   result.grossFireNumber > result.effectiveFireNumber {
                    RuleMark(y: .value("Gross FIRE Target", result.grossFireNumber))
                        .foregroundStyle(Color.gray.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                // Vertical dashed marker at the FIRE age crossover point.
                RuleMark(x: .value("FIRE Age", result.fireAge))
                    .foregroundStyle(Color.green.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .center) {
                        Text("Age \(result.fireAge)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemBackground).opacity(0.9))
                            .cornerRadius(4)
                    }
            }
            .chartXScale(domain: startAge...xCeiling)
            .chartYScale(domain: 0...yCeiling)
            .frame(height: 260)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let age = value.as(Int.self) {
                            Text("\(age)")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxisLabel("Age", alignment: .center)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatChartValue(amount))
                                .font(.caption2)
                        }
                    }
                }
            }

            // Labels for the two horizontal rules (cleaner than in-chart annotations).
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(result.effectiveFireNumber.toCurrency())
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        Text(result.benefitIncomeAtFIRE > 0 ? "FIRE target (adjusted)" : "FIRE target")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    if result.benefitIncomeAtFIRE > 0,
                       result.grossFireNumber > result.effectiveFireNumber {
                        HStack(spacing: 4) {
                            Text(result.grossFireNumber.toCurrency())
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text("without benefits")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.top, 2)

            // Legend
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 20, height: 3)
                    Text("Portfolio Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green)
                        .frame(width: 20, height: 3)
                    Text(result.benefitIncomeAtFIRE > 0 ? "FIRE Target (adjusted)" : "FIRE Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if result.benefitIncomeAtFIRE > 0,
                   result.grossFireNumber > result.effectiveFireNumber {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.6))
                            .frame(width: 20, height: 3)
                        Text("Gross Target")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }

    // MARK: - Milestones Section

    private func milestonesSection(result: FIREResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Milestones")
                .font(.headline)

            ForEach(result.milestones, id: \.percentage) { milestone in
                MilestoneRow(milestone: milestone)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }

    // MARK: - Helpers

    private var isValid: Bool {
        !viewModel.currentSavings.isEmpty &&
        !viewModel.annualExpenses.isEmpty &&
        Double(viewModel.currentSavings.replacingOccurrences(of: ",", with: "")) != nil &&
        Double(viewModel.annualExpenses.replacingOccurrences(of: ",", with: "")) != nil
    }

    private func calculate() {
        guard let savings = Double(viewModel.currentSavings.replacingOccurrences(of: ",", with: "")),
              let expenses = Double(viewModel.annualExpenses.replacingOccurrences(of: ",", with: "")) else { return }

        let annualContribution = Double(viewModel.annualSavingsContribution.replacingOccurrences(of: ",", with: "")) ?? 0

        let calculator = FIRECalculator()
        viewModel.calculationResult = calculator.calculate(
            currentAge: viewModel.currentAge,
            currentSavings: savings,
            annualSavings: annualContribution,
            annualExpenses: expenses,
            expectedReturn: viewModel.expectedReturn,
            withdrawalRate: viewModel.withdrawalRate,
            inflationRate: viewModel.inflationRate,
            benefitPlans: benefitManager.plans
        )
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

// MARK: - FIRE Calculator Engine

struct FIRECalculator {
    func calculate(
        currentAge: Int,
        currentSavings: Double,
        annualSavings: Double,
        annualExpenses: Double,
        expectedReturn: Double,
        withdrawalRate: Double,
        inflationRate: Double,
        benefitPlans: [DefinedBenefitPlan] = []
    ) -> FIREResult {

        // The GROSS FIRE number — what the portfolio would need to fund ALL
        // expenses with zero guaranteed income.
        let grossFireNumber = annualExpenses / withdrawalRate

        // Project year by year until we reach the *effective* (benefit-adjusted)
        // target for the current age.
        //
        // Logic: each benefit plan that is active at a given age reduces the
        // portfolio burden by (benefit / withdrawalRate) — the capitalised value
        // of that perpetual income stream.  FIRE is achieved when:
        //
        //   portfolio >= grossFireNumber − Σ(activeBenefits) / withdrawalRate
        //
        // This means a $20k/yr pension kicking in at 55 drops the target by
        // $20k / 0.04 = $500k from age 55 onward.  If the portfolio is already
        // ≥ the reduced target, FIRE is declared even if it's still below the
        // gross number.

        var yearlyProjections: [FIREPathProjection] = []
        var balance = currentSavings
        var age = currentAge
        var year = 0
        var totalContributions = currentSavings

        let initialTarget = effectiveFireTarget(
            grossTarget: grossFireNumber,
            age: age,
            benefitPlans: benefitPlans,
            withdrawalRate: withdrawalRate
        )
        yearlyProjections.append(FIREPathProjection(
            year: year,
            age: age,
            portfolioValue: balance,
            contributions: currentSavings,
            investmentGains: 0,
            effectiveTarget: initialTarget
        ))

        // Check if FIRE is already achieved at the current age (e.g. a benefit
        // that has already started fully covers expenses).
        guard balance < initialTarget else {
            // Already at FIRE — skip the accumulation loop entirely.
            let benefitIncomeAtFIRE = benefitPlans
                .filter { age >= $0.startAge }
                .reduce(0.0) { $0 + $1.annualBenefit }
            let milestones = calculateMilestones(
                grossFireNumber: grossFireNumber,
                projections: yearlyProjections,
                currentAge: currentAge,
                benefitPlans: benefitPlans,
                withdrawalRate: withdrawalRate
            )
            return FIREResult(
                fireAge: age,
                yearsToFIRE: 0,
                fireYear: Calendar.current.component(.year, from: Date()),
                grossFireNumber: grossFireNumber,
                effectiveFireNumber: initialTarget,
                benefitIncomeAtFIRE: benefitIncomeAtFIRE,
                annualSavings: annualSavings,
                annualExpenses: annualExpenses,
                withdrawalRate: withdrawalRate,
                totalContributions: totalContributions,
                investmentGains: 0,
                yearlyProjections: yearlyProjections,
                milestones: milestones
            )
        }

        while year < 50 { // Cap at 50 years
            year += 1
            age += 1

            // Contributions grow with inflation each year.
            let inflationAdjustedSavings = annualSavings * pow(1 + inflationRate, Double(year))
            totalContributions += inflationAdjustedSavings

            // Portfolio grows, then receives this year's contribution.
            balance = balance * (1 + expectedReturn) + inflationAdjustedSavings

            let target = effectiveFireTarget(
                grossTarget: grossFireNumber,
                age: age,
                benefitPlans: benefitPlans,
                withdrawalRate: withdrawalRate
            )

            yearlyProjections.append(FIREPathProjection(
                year: year,
                age: age,
                portfolioValue: balance,
                contributions: totalContributions,
                investmentGains: balance - totalContributions,
                effectiveTarget: target
            ))

            if balance >= target { break }
        }

        // The *effective* FIRE number is the target at the age FIRE was achieved —
        // this is what the portfolio actually needed to reach, not the gross number.
        let achievedTarget = effectiveFireTarget(
            grossTarget: grossFireNumber,
            age: age,
            benefitPlans: benefitPlans,
            withdrawalRate: withdrawalRate
        )

        // Active benefit income at FIRE age — used for the results summary.
        let benefitIncomeAtFIRE = benefitPlans
            .filter { age >= $0.startAge }
            .reduce(0.0) { $0 + $1.annualBenefit }

        // Calculate milestones against the gross number (so percentages are
        // meaningful relative to the user's full expense target), but each
        // milestone respects benefits that are active at the milestone age.
        let milestones = calculateMilestones(
            grossFireNumber: grossFireNumber,
            projections: yearlyProjections,
            currentAge: currentAge,
            benefitPlans: benefitPlans,
            withdrawalRate: withdrawalRate
        )

        return FIREResult(
            fireAge: age,
            yearsToFIRE: year,
            fireYear: Calendar.current.component(.year, from: Date()) + year,
            grossFireNumber: grossFireNumber,
            effectiveFireNumber: achievedTarget,
            benefitIncomeAtFIRE: benefitIncomeAtFIRE,
            annualSavings: annualSavings,
            annualExpenses: annualExpenses,
            withdrawalRate: withdrawalRate,
            totalContributions: totalContributions,
            investmentGains: balance - totalContributions,
            yearlyProjections: yearlyProjections,
            milestones: milestones
        )
    }

    // MARK: - Effective Target

    /// The portfolio value required at `age` after accounting for any guaranteed
    /// income streams that are already active.  A plan with `startAge <= age`
    /// reduces the required portfolio by `annualBenefit / withdrawalRate`.
    private func effectiveFireTarget(
        grossTarget: Double,
        age: Int,
        benefitPlans: [DefinedBenefitPlan],
        withdrawalRate: Double
    ) -> Double {
        let activeBenefitIncome = benefitPlans
            .filter { age >= $0.startAge }
            .reduce(0.0) { $0 + $1.annualBenefit }
        let benefitEquivalent = activeBenefitIncome / withdrawalRate
        return max(0, grossTarget - benefitEquivalent)
    }

    // MARK: - Milestones

    private func calculateMilestones(
        grossFireNumber: Double,
        projections: [FIREPathProjection],
        currentAge: Int,
        benefitPlans: [DefinedBenefitPlan],
        withdrawalRate: Double
    ) -> [Milestone] {
        let percentages = [0.25, 0.50, 0.75, 1.0]
        var milestones: [Milestone] = []

        for percentage in percentages {
            // The gross milestone target (e.g. 50% of the full FIRE number).
            let grossMilestoneTarget = grossFireNumber * percentage

            // Find the first year where the portfolio meets the benefit-adjusted
            // version of this milestone target.
            let match = projections.first { proj in
                let activeBenefits = benefitPlans
                    .filter { proj.age >= $0.startAge }
                    .reduce(0.0) { $0 + $1.annualBenefit }
                let effectiveMilestoneTarget = max(0, grossMilestoneTarget - activeBenefits / withdrawalRate)
                return proj.portfolioValue >= effectiveMilestoneTarget
            }

            if let projection = match {
                milestones.append(Milestone(
                    percentage: percentage,
                    amount: grossMilestoneTarget,
                    age: projection.age,
                    yearsFromNow: projection.age - currentAge
                ))
            }
        }

        return milestones
    }
}

// MARK: - Models

struct FIREResult {
    let fireAge: Int
    let yearsToFIRE: Int
    let fireYear: Int
    /// Full portfolio needed if there were zero guaranteed income.
    let grossFireNumber: Double
    /// The actual portfolio target at the FIRE age after subtracting the
    /// capitalised value of all active guaranteed income streams.
    let effectiveFireNumber: Double
    /// Total annual guaranteed income (pensions, SS, etc.) active at FIRE age.
    let benefitIncomeAtFIRE: Double
    let annualSavings: Double
    let annualExpenses: Double
    let withdrawalRate: Double
    let totalContributions: Double
    let investmentGains: Double
    let yearlyProjections: [FIREPathProjection]
    let milestones: [Milestone]

    /// Annual portfolio withdrawal needed at FIRE (expenses minus guaranteed income).
    var portfolioWithdrawalAtFIRE: Double {
        max(0, annualExpenses - benefitIncomeAtFIRE)
    }

    /// True when guaranteed income alone covers all expenses.
    var fullyFundedByBenefits: Bool {
        benefitIncomeAtFIRE >= annualExpenses
    }
}

struct FIREPathProjection {
    let year: Int
    let age: Int
    let portfolioValue: Double
    let contributions: Double
    let investmentGains: Double
    /// The benefit-adjusted portfolio target for this age.
    let effectiveTarget: Double
}

struct Milestone {
    let percentage: Double
    let amount: Double
    let age: Int
    let yearsFromNow: Int

    var title: String {
        switch percentage {
        case 0.25: return "Coast FIRE"
        case 0.50: return "Halfway There"
        case 0.75: return "Lean FIRE"
        case 1.0: return "Full FIRE"
        default: return "\(Int(percentage * 100))%"
        }
    }

    var description: String {
        switch percentage {
        case 0.25: return "Can stop contributing and let investments grow"
        case 0.50: return "Halfway to your FIRE goal"
        case 0.75: return "Could retire with reduced expenses"
        case 1.0: return "Full financial independence achieved"
        default: return ""
        }
    }
}

// MARK: - Milestone Row

struct MilestoneRow: View {
    let milestone: Milestone

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Text("\(Int(milestone.percentage * 100))%")
                    .font(.headline)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.headline)

                Text(milestone.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Age \(milestone.age) • \(milestone.yearsFromNow) years")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }

            Spacer()

            Text(milestone.amount.toCurrency())
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(12)
    }

    private var color: Color {
        switch milestone.percentage {
        case 0.25: return .orange
        case 0.50: return .blue
        case 0.75: return .purple
        case 1.0: return .green
        default: return .gray
        }
    }
}

#Preview {
    NavigationView {
        FIRECalculatorView(portfolioVM: PortfolioViewModel(), benefitManager: DefinedBenefitManager(), viewModel: FIRECalculatorViewModel())
    }
}

