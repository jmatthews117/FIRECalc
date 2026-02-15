//
//  FIRECalculatorView.swift
//  FIRECalc
//
//  Calculate when you can retire based on income, savings rate, and expenses
//

import SwiftUI
import Charts

struct FIRECalculatorView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @ObservedObject var benefitManager: DefinedBenefitManager

    @State private var currentAge: Int = 35
    @State private var currentSavings: String = ""
    @State private var annualIncome: String = ""
    @State private var annualExpenses: String = ""
    @State private var savingsRate: Double = 0.20 // 20%
    @State private var expectedReturn: Double = 0.07 // 7%
    @State private var withdrawalRate: Double = 0.04 // 4%
    @State private var inflationRate: Double = 0.025 // 2.5%
    
    @State private var calculationResult: FIREResult?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Input Section
                inputSection

                // Guaranteed income from pensions / Social Security
                benefitIncomeCard

                // Calculate Button
                calculateButton
                
                // Results Section
                if let result = calculationResult {
                    resultsSection(result: result)
                    pathwayChart(result: result)
                    milestonesSection(result: result)
                }
            }
            .padding()
        }
        .navigationTitle("FIRE Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if currentSavings.isEmpty && portfolioVM.totalValue > 0 {
                currentSavings = String(format: "%.0f", portfolioVM.totalValue)
            }
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
                    TextField("Age", value: $currentAge, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                
                // Current Savings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Savings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("$0", text: $currentSavings)
                        .keyboardType(.decimalPad)
                }
                
                // Annual Income
                VStack(alignment: .leading, spacing: 8) {
                    Text("Annual Income (Gross)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("$0", text: $annualIncome)
                        .keyboardType(.decimalPad)
                }
                
                // Annual Expenses
                VStack(alignment: .leading, spacing: 8) {
                    Text("Annual Expenses")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("$0", text: $annualExpenses)
                        .keyboardType(.decimalPad)
                    
                    if let income = Double(annualIncome),
                       let expenses = Double(annualExpenses),
                       income > 0 {
                        Text("Savings Rate: \(((income - expenses) / income).toPercent())")
                            .font(.caption)
                            .foregroundColor(.blue)
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
                            Text(expectedReturn.toPercent())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $expectedReturn, in: 0...0.15, step: 0.005)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Withdrawal Rate")
                            Spacer()
                            Text(withdrawalRate.toPercent())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $withdrawalRate, in: 0.025...0.06, step: 0.005)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Inflation Rate")
                            Spacer()
                            Text(inflationRate.toPercent())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $inflationRate, in: 0...0.05, step: 0.005)
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
            
            Divider()
            
            // Key Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                MetricCard(
                    title: "FIRE Number",
                    value: result.fireNumber.toCurrency(),
                    subtitle: "Target portfolio",
                    icon: "target",
                    color: .blue
                )
                
                MetricCard(
                    title: "Annual Savings",
                    value: result.annualSavings.toCurrency(),
                    subtitle: "Per year",
                    icon: "arrow.down.circle",
                    color: .green
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
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    // MARK: - Pathway Chart
    
    private func pathwayChart(result: FIREResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Path to FIRE")
                .font(.headline)
            
            Chart {
                ForEach(result.yearlyProjections, id: \.year) { projection in
                    LineMark(
                        x: .value("Age", projection.age),
                        y: .value("Savings", projection.portfolioValue)
                    )
                    .foregroundStyle(.blue.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    PointMark(
                        x: .value("Age", projection.age),
                        y: .value("Savings", projection.portfolioValue)
                    )
                    .foregroundStyle(.blue)
                }
                
                // FIRE Number Line
                RuleMark(y: .value("FIRE Number", result.fireNumber))
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("FIRE Number")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 4)
                            .background(Color(.systemBackground))
                    }
            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatChartValue(amount))
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
        !currentSavings.isEmpty &&
        !annualIncome.isEmpty &&
        !annualExpenses.isEmpty &&
        Double(currentSavings) != nil &&
        Double(annualIncome) != nil &&
        Double(annualExpenses) != nil
    }
    
    private func calculate() {
        guard let savings = Double(currentSavings),
              let income = Double(annualIncome),
              let expenses = Double(annualExpenses) else { return }
        
        let calculator = FIRECalculator()
        calculationResult = calculator.calculate(
            currentAge: currentAge,
            currentSavings: savings,
            annualIncome: income,
            annualExpenses: expenses,
            expectedReturn: expectedReturn,
            withdrawalRate: withdrawalRate,
            inflationRate: inflationRate,
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
        annualIncome: Double,
        annualExpenses: Double,
        expectedReturn: Double,
        withdrawalRate: Double,
        inflationRate: Double,
        benefitPlans: [DefinedBenefitPlan] = []
    ) -> FIREResult {
        
        // Calculate FIRE number (25x rule adjusted for withdrawal rate).
        // Benefit income that starts *at* retirement reduces the required portfolio.
        // For simplicity we use the plans' nominal benefit values here; the
        // year-by-year accumulation loop below handles phased-in income.
        let fireNumber = annualExpenses / withdrawalRate
        
        // Calculate annual savings
        let annualSavings = max(0, annualIncome - annualExpenses)
        
        // Project year by year until reaching the *effective* target.
        // As each benefit plan kicks in, the required portfolio shrinks by
        // benefit / withdrawalRate (the capitalised value of that income stream).
        var yearlyProjections: [FIREPathProjection] = []
        var balance = currentSavings
        var age = currentAge
        var year = 0
        var totalContributions = currentSavings
        
        yearlyProjections.append(FIREPathProjection(
            year: year,
            age: age,
            portfolioValue: balance,
            contributions: currentSavings,
            investmentGains: 0
        ))
        
        while year < 50 { // Cap at 50 years
            year += 1
            age += 1
            
            // Add contributions (inflation-adjusted)
            let inflationAdjustedSavings = annualSavings * pow(1 + inflationRate, Double(year))
            totalContributions += inflationAdjustedSavings
            
            // Apply investment return
            balance = balance * (1 + expectedReturn) + inflationAdjustedSavings
            
            // Benefits active this year reduce the amount the portfolio must fund.
            let activeBenefitIncome = benefitPlans
                .filter { age >= $0.startAge }
                .reduce(0.0) { $0 + $1.annualBenefit }
            let benefitPortfolioEquivalent = activeBenefitIncome / withdrawalRate
            let effectiveTarget = max(0, fireNumber - benefitPortfolioEquivalent)
            
            yearlyProjections.append(FIREPathProjection(
                year: year,
                age: age,
                portfolioValue: balance,
                contributions: totalContributions,
                investmentGains: balance - totalContributions
            ))
            
            if balance >= effectiveTarget { break }
        }
        
        // Calculate milestones
        let milestones = calculateMilestones(
            fireNumber: fireNumber,
            projections: yearlyProjections,
            currentAge: currentAge,
            benefitPlans: benefitPlans,
            withdrawalRate: withdrawalRate
        )
        
        return FIREResult(
            fireAge: age,
            yearsToFIRE: year,
            fireYear: Calendar.current.component(.year, from: Date()) + year,
            fireNumber: fireNumber,
            annualSavings: annualSavings,
            totalContributions: totalContributions,
            investmentGains: balance - totalContributions,
            yearlyProjections: yearlyProjections,
            milestones: milestones
        )
    }
    
    private func calculateMilestones(
        fireNumber: Double,
        projections: [FIREPathProjection],
        currentAge: Int,
        benefitPlans: [DefinedBenefitPlan] = [],
        withdrawalRate: Double = 0.04
    ) -> [Milestone] {
        let percentages = [0.25, 0.50, 0.75, 1.0]
        var milestones: [Milestone] = []
        
        for percentage in percentages {
            let baseTarget = fireNumber * percentage
            
            // Find the first projection where balance meets the benefit-adjusted target.
            let match = projections.first { proj in
                let activeBenefits = benefitPlans
                    .filter { proj.age >= $0.startAge }
                    .reduce(0.0) { $0 + $1.annualBenefit }
                let effective = max(0, baseTarget - activeBenefits / withdrawalRate)
                return proj.portfolioValue >= effective
            }

            if let projection = match {
                milestones.append(Milestone(
                    percentage: percentage,
                    amount: baseTarget,
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
    let fireNumber: Double
    let annualSavings: Double
    let totalContributions: Double
    let investmentGains: Double
    let yearlyProjections: [FIREPathProjection]
    let milestones: [Milestone]
}

struct FIREPathProjection {
    let year: Int
    let age: Int
    let portfolioValue: Double
    let contributions: Double
    let investmentGains: Double
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
        FIRECalculatorView(portfolioVM: PortfolioViewModel(), benefitManager: DefinedBenefitManager())
    }
}
