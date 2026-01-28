//
//  WithdrawalConfigurationView.swift
//  FIRECalc
//
//  Enhanced withdrawal strategy configuration with explanations and visualizations
//

import SwiftUI
import Charts

struct WithdrawalConfigurationView: View {
    @Binding var config: WithdrawalConfiguration
    let portfolioValue: Double
    
    @State private var showingStrategyInfo = false
    @State private var selectedStrategy: WithdrawalStrategy
    @State private var withdrawalRate: Double
    @State private var fixedDollarAmount: Double
    
    init(config: Binding<WithdrawalConfiguration>, portfolioValue: Double) {
        self._config = config
        self.portfolioValue = portfolioValue
        self._selectedStrategy = State(initialValue: config.wrappedValue.strategy)
        self._withdrawalRate = State(initialValue: config.wrappedValue.withdrawalRate)
        self._fixedDollarAmount = State(initialValue: config.wrappedValue.annualAmount ?? 0)
    }
    
    var body: some View {
        Form {
            // Strategy Selection
            Section {
                Picker("Withdrawal Strategy", selection: $selectedStrategy) {
                    ForEach(WithdrawalStrategy.allCases) { strategy in
                        Text(strategy.rawValue)
                            .tag(strategy)
                    }
                }
                .onChange(of: selectedStrategy) { oldValue, newValue in
                    config.strategy = newValue
                    withdrawalRate = newValue.defaultPercentage
                }
                
                Button(action: { showingStrategyInfo = true }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("What is this strategy?")
                            .font(.subheadline)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Strategy-specific configuration
            strategySpecificSection
            
            // Dollar Amount Preview
            dollarAmountPreview
            
            // Visual Preview
            strategyVisualization
        }
        .navigationTitle("Withdrawal Strategy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingStrategyInfo) {
            StrategyInfoSheet(strategy: selectedStrategy)
        }
    }
    
    // MARK: - Strategy-Specific Section
    
    @ViewBuilder
    private var strategySpecificSection: some View {
        switch selectedStrategy {
        case .fixedPercentage:
            fixedPercentageSection
        case .dynamicPercentage:
            dynamicPercentageSection
        case .guardrails:
            guardrailsSection
        case .rmd:
            rmdSection
        case .fixedDollar:
            fixedDollarSection
        case .custom:
            customSection
        }
    }
    
    private var fixedPercentageSection: some View {
        Section("4% Rule Configuration") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Withdrawal Rate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Slider(value: $withdrawalRate, in: 0.01...0.10, step: 0.005)
                    Text(withdrawalRate.toPercent())
                        .font(.headline)
                        .frame(width: 60, alignment: .trailing)
                }
                .onChange(of: withdrawalRate) { _, newValue in
                    config.withdrawalRate = newValue
                }
                
                Text("First year withdrawal: \((portfolioValue * withdrawalRate).toCurrency())")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("Subsequent years adjust for inflation")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Toggle("Adjust for Inflation", isOn: $config.adjustForInflation)
        }
    }
    
    private var dynamicPercentageSection: some View {
        Section("Dynamic Percentage Configuration") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Withdrawal Rate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Slider(value: $withdrawalRate, in: 0.01...0.10, step: 0.005)
                    Text(withdrawalRate.toPercent())
                        .font(.headline)
                        .frame(width: 60, alignment: .trailing)
                }
                .onChange(of: withdrawalRate) { _, newValue in
                    config.withdrawalRate = newValue
                }
                
                Text("Withdraws \(withdrawalRate.toPercent()) of current portfolio value each year")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Toggle("Set Floor", isOn: Binding(
                get: { config.floorPercentage != nil },
                set: { enabled in
                    config.floorPercentage = enabled ? 0.025 : nil
                }
            ))
            
            if let floor = config.floorPercentage {
                HStack {
                    Text("Floor")
                    Spacer()
                    Text(floor.toPercent())
                        .foregroundColor(.secondary)
                }
            }
            
            Toggle("Set Ceiling", isOn: Binding(
                get: { config.ceilingPercentage != nil },
                set: { enabled in
                    config.ceilingPercentage = enabled ? 0.06 : nil
                }
            ))
            
            if let ceiling = config.ceilingPercentage {
                HStack {
                    Text("Ceiling")
                    Spacer()
                    Text(ceiling.toPercent())
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var guardrailsSection: some View {
        Section("Guardrails Configuration") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Initial Withdrawal Rate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Slider(value: $withdrawalRate, in: 0.01...0.10, step: 0.005)
                    Text(withdrawalRate.toPercent())
                        .font(.headline)
                        .frame(width: 60, alignment: .trailing)
                }
                .onChange(of: withdrawalRate) { _, newValue in
                    config.withdrawalRate = newValue
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Upper Guardrail")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Reduce spending by 10% if withdrawal rate exceeds \((withdrawalRate * 1.20).toPercent())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Lower Guardrail")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Increase spending by 10% if withdrawal rate falls below \((withdrawalRate * 0.85).toPercent())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var rmdSection: some View {
        Section("RMD Configuration") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Current Age")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Age", value: Binding(
                    get: { config.currentAge ?? 65 },
                    set: { config.currentAge = $0 }
                ), format: .number)
                .keyboardType(.numberPad)
                
                Text("Withdrawal amount based on IRS life expectancy tables")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var fixedDollarSection: some View {
        Section("Fixed Dollar Amount") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Annual Withdrawal Amount")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Amount", value: $fixedDollarAmount, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                    .onChange(of: fixedDollarAmount) { _, newValue in
                        config.annualAmount = newValue
                    }
                
                Text("Withdraws exactly this amount each year")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Toggle("Adjust for Inflation", isOn: $config.adjustForInflation)
        }
    }
    
    private var customSection: some View {
        Section("Custom Strategy") {
            Text("Configure your own withdrawal rules")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Dollar Amount Preview
    
    private var dollarAmountPreview: some View {
        Section("First Year Withdrawal") {
            VStack(spacing: 12) {
                HStack {
                    Text("Amount")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(firstYearWithdrawal.toCurrency())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Monthly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text((firstYearWithdrawal / 12).toCurrency())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if selectedStrategy != .fixedDollar {
                    HStack {
                        Text("Percentage of Portfolio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text((firstYearWithdrawal / portfolioValue).toPercent())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Strategy Visualization
    
    private var strategyVisualization: some View {
        Section("30-Year Projection") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Estimated withdrawal amounts over time")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Chart {
                    ForEach(projectedWithdrawals, id: \.year) { projection in
                        LineMark(
                            x: .value("Year", projection.year),
                            y: .value("Amount", projection.amount)
                        )
                        .foregroundStyle(.blue.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatChartValue(amount))
                            }
                        }
                    }
                }
                
                Text(strategyBehaviorDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var firstYearWithdrawal: Double {
        switch selectedStrategy {
        case .fixedDollar:
            return fixedDollarAmount
        default:
            return portfolioValue * withdrawalRate
        }
    }
    
    private var projectedWithdrawals: [(year: Int, amount: Double)] {
        let calculator = WithdrawalCalculator()
        var projections: [(Int, Double)] = []
        
        let inflationRate = 0.025 // Assume 2.5% for projection
        let assumedReturn = 0.05 // Assume 5% for projection
        var balance = portfolioValue
        var baselineWithdrawal = firstYearWithdrawal
        
        for year in 1...30 {
            let withdrawal = calculator.calculateWithdrawal(
                currentBalance: balance,
                year: year,
                baselineWithdrawal: baselineWithdrawal,
                initialBalance: portfolioValue,
                config: config,
                inflationRate: inflationRate
            )
            
            projections.append((year, withdrawal))
            
            // Update balance for next year
            balance = balance * (1 + assumedReturn) - withdrawal
            balance = max(0, balance)
        }
        
        return projections
    }
    
    private var strategyBehaviorDescription: String {
        switch selectedStrategy {
        case .fixedPercentage:
            return "Withdrawal increases with inflation, maintaining purchasing power"
        case .dynamicPercentage:
            return "Withdrawal fluctuates with portfolio value - higher in good years, lower in bad years"
        case .guardrails:
            return "Adjusts spending when portfolio performance deviates significantly from plan"
        case .rmd:
            return "Increases withdrawal percentage as you age, based on IRS tables"
        case .fixedDollar:
            return config.adjustForInflation ? "Fixed amount adjusted for inflation" : "Same dollar amount every year"
        case .custom:
            return "Custom withdrawal pattern"
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
}

// MARK: - Strategy Info Sheet

struct StrategyInfoSheet: View {
    let strategy: WithdrawalStrategy
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Strategy Overview
                    VStack(alignment: .leading, spacing: 12) {
                        Text(strategy.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(strategy.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // How it Works
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How It Works")
                            .font(.headline)
                        
                        Text(detailedExplanation)
                            .font(.body)
                    }
                    
                    // Pros and Cons
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Pros")
                                    .font(.headline)
                            }
                            
                            ForEach(pros, id: \.self) { pro in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text(pro)
                                        .font(.caption)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Cons")
                                    .font(.headline)
                            }
                            
                            ForEach(cons, id: \.self) { con in
                                HStack(alignment: \.top, spacing: 8) {
                                    Text("•")
                                    Text(con)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    
                    // When to Use
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Best For")
                            .font(.headline)
                        
                        Text(bestFor)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Strategy Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var detailedExplanation: String {
        switch strategy {
        case .fixedPercentage:
            return "In year 1, withdraw a fixed percentage (typically 4%) of your initial portfolio. In subsequent years, increase the dollar amount by inflation to maintain purchasing power. This is the classic \"4% rule\" developed by William Bengen."
        case .dynamicPercentage:
            return "Each year, withdraw a fixed percentage of your current portfolio value. If your portfolio grows, you withdraw more. If it shrinks, you withdraw less. This naturally adjusts spending based on portfolio performance."
        case .guardrails:
            return "Start with an initial withdrawal rate. If your actual withdrawal rate rises above the upper guardrail (portfolio performing poorly), cut spending by 10%. If it falls below the lower guardrail (portfolio performing well), increase spending by 10%. Developed by Jonathan Guyton and William Klinger."
        case .rmd:
            return "Follow IRS Required Minimum Distribution tables which specify what percentage of your portfolio to withdraw based on your age. The percentage increases as you age, reflecting shorter life expectancy."
        case .fixedDollar:
            return "Withdraw the same dollar amount each year, optionally adjusted for inflation. Provides predictable income but doesn't respond to portfolio performance."
        case .custom:
            return "Define your own withdrawal rules based on your specific needs and circumstances."
        }
    }
    
    private var pros: [String] {
        switch strategy {
        case .fixedPercentage:
            return [
                "Simple to understand and implement",
                "Maintains purchasing power",
                "Historically high success rate (95%+)",
                "Predictable income in nominal terms"
            ]
        case .dynamicPercentage:
            return [
                "Automatically adjusts to portfolio performance",
                "Lower risk of running out of money",
                "Can increase spending in good years",
                "Responsive to market conditions"
            ]
        case .guardrails:
            return [
                "Balances stability and flexibility",
                "Allows spending increases when safe",
                "Protects against depletion",
                "More spending than pure 4% rule"
            ]
        case .rmd:
            return [
                "Required for traditional IRAs after 73",
                "Increases with age (more when you need less)",
                "IRS-approved tables",
                "Tax-efficient for retirees"
            ]
        case .fixedDollar:
            return [
                "Maximum spending predictability",
                "Simple to budget",
                "No calculations needed"
            ]
        case .custom:
            return [
                "Tailored to your situation",
                "Maximum flexibility"
            ]
        }
    }
    
    private var cons: [String] {
        switch strategy {
        case .fixedPercentage:
            return [
                "Doesn't adjust to portfolio performance",
                "May withdraw too much in bear markets",
                "May withdraw too little in bull markets",
                "Can deplete portfolio if returns are poor"
            ]
        case .dynamicPercentage:
            return [
                "Income varies year-to-year",
                "Difficult to budget",
                "May force lifestyle changes",
                "Spending cuts in bear markets"
            ]
        case .guardrails:
            return [
                "More complex than fixed percentage",
                "Still requires spending adjustments",
                "Guardrail triggers can be jarring"
            ]
        case .rmd:
            return [
                "Increases withdrawals in later years",
                "Not optimized for spending needs",
                "May force withdrawals when not needed",
                "Only applies to tax-deferred accounts"
            ]
        case .fixedDollar:
            return [
                "Doesn't respond to portfolio changes",
                "Higher risk of depletion",
                "May leave money unspent"
            ]
        case .custom:
            return [
                "Requires careful design",
                "May be suboptimal"
            ]
        }
    }
    
    private var bestFor: String {
        switch strategy {
        case .fixedPercentage:
            return "Traditional retirees who value spending predictability and have a moderate risk tolerance. Works best with diversified portfolios and 30-year time horizons."
        case .dynamicPercentage:
            return "Flexible retirees who can adjust spending based on market conditions. Good for those with other income sources or variable expenses."
        case .guardrails:
            return "Retirees who want more spending than the 4% rule but still want protection. Best for those comfortable with occasional spending adjustments."
        case .rmd:
            return "Traditional IRA owners over 73 who must take required minimum distributions. Useful for tax planning."
        case .fixedDollar:
            return "Those with very specific spending needs or who have guaranteed income from other sources (pension, Social Security) covering basics."
        case .custom:
            return "Sophisticated investors with unique circumstances or preferences."
        }
    }
}

#Preview {
    NavigationView {
        WithdrawalConfigurationView(
            config: .constant(WithdrawalConfiguration()),
            portfolioValue: 1_000_000
        )
    }
}
