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
    @State private var floorEnabled: Bool
    @State private var ceilingEnabled: Bool
    @State private var floorPercentage: Double
    @State private var ceilingPercentage: Double
    @State private var upperGuardrail: Double
    @State private var lowerGuardrail: Double

    init(config: Binding<WithdrawalConfiguration>, portfolioValue: Double) {
        self._config = config
        self.portfolioValue = portfolioValue
        let rate = config.wrappedValue.withdrawalRate
        self._selectedStrategy = State(initialValue: config.wrappedValue.strategy)
        self._withdrawalRate = State(initialValue: rate)
        self._fixedDollarAmount = State(initialValue: config.wrappedValue.annualAmount ?? 0)
        self._floorEnabled = State(initialValue: config.wrappedValue.floorPercentage != nil)
        self._ceilingEnabled = State(initialValue: config.wrappedValue.ceilingPercentage != nil)
        self._floorPercentage = State(initialValue: config.wrappedValue.floorPercentage ?? 0.025)
        self._ceilingPercentage = State(initialValue: config.wrappedValue.ceilingPercentage ?? 0.06)
        // Default upper guardrail to initial rate × 1.25, lower to initial rate × 0.80
        self._upperGuardrail = State(initialValue: config.wrappedValue.upperGuardrail ?? (rate * 1.25))
        self._lowerGuardrail = State(initialValue: config.wrappedValue.lowerGuardrail ?? (rate * 0.80))
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
        .keyboardDoneButton()
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
        case .fixedDollar:
            fixedDollarSection
        }
    }
    
    private var fixedPercentageSection: some View {
        Section("4% Rule Configuration") {
            HStack {
                Text("Withdrawal Rate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(withdrawalRate.toPercent())
                    .font(.headline)
                    .monospacedDigit()
            }
            Slider(value: $withdrawalRate, in: 0.01...0.10, step: 0.005)
                .onChange(of: withdrawalRate) { _, newValue in
                    config.withdrawalRate = newValue
                }
            Text("First year withdrawal: \((portfolioValue * withdrawalRate).toCurrency())")
                .font(.caption)
                .foregroundColor(.blue)
            Text("Subsequent years adjust for inflation")
                .font(.caption)
                .foregroundColor(.secondary)
            Toggle("Adjust for Inflation", isOn: $config.adjustForInflation)
        }
    }
    
    private var dynamicPercentageSection: some View {
        Section("Dynamic Percentage Configuration") {
            HStack {
                Text("Withdrawal Rate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(withdrawalRate.toPercent())
                    .font(.headline)
                    .monospacedDigit()
            }
            Slider(value: $withdrawalRate, in: 0.01...0.10, step: 0.005)
                .onChange(of: withdrawalRate) { _, newValue in
                    config.withdrawalRate = newValue
                    // Clamp floor/ceiling to stay on the correct side of the withdrawal rate
                    if floorEnabled && floorPercentage > newValue {
                        floorPercentage = newValue
                        config.floorPercentage = newValue
                    }
                    if ceilingEnabled && ceilingPercentage < newValue {
                        ceilingPercentage = newValue
                        config.ceilingPercentage = newValue
                    }
                }
            Text("Withdraws \(withdrawalRate.toPercent()) of current portfolio value each year")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Set Floor", isOn: $floorEnabled)
                .onChange(of: floorEnabled) { _, enabled in
                    if enabled {
                        // Default to withdrawal rate or lower
                        floorPercentage = min(floorPercentage, withdrawalRate)
                        config.floorPercentage = floorPercentage
                    } else {
                        config.floorPercentage = nil
                    }
                }

            if floorEnabled {
                HStack {
                    Text("Floor")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(floorPercentage.toPercent())
                        .font(.headline)
                        .monospacedDigit()
                }
                Slider(value: $floorPercentage, in: 0.005...withdrawalRate, step: 0.005)
                    .onChange(of: floorPercentage) { _, newValue in
                        config.floorPercentage = newValue
                    }
                Text("Fixed floor: \((portfolioValue * floorPercentage).toCurrency())/yr (based on initial portfolio)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Toggle("Set Ceiling", isOn: $ceilingEnabled)
                .onChange(of: ceilingEnabled) { _, enabled in
                    if enabled {
                        // Default to withdrawal rate or higher
                        ceilingPercentage = max(ceilingPercentage, withdrawalRate)
                        config.ceilingPercentage = ceilingPercentage
                    } else {
                        config.ceilingPercentage = nil
                    }
                }

            if ceilingEnabled {
                HStack {
                    Text("Ceiling")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(ceilingPercentage.toPercent())
                        .font(.headline)
                        .monospacedDigit()
                }
                Slider(value: $ceilingPercentage, in: withdrawalRate...0.15, step: 0.005)
                    .onChange(of: ceilingPercentage) { _, newValue in
                        config.ceilingPercentage = newValue
                    }
                Text("Fixed ceiling: \((portfolioValue * ceilingPercentage).toCurrency())/yr (based on initial portfolio)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var guardrailsSection: some View {
        Section("Guardrails Configuration") {
            HStack {
                Text("Initial Withdrawal Rate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(withdrawalRate.toPercent())
                    .font(.headline)
                    .monospacedDigit()
            }
            Slider(value: $withdrawalRate, in: 0.01...0.10, step: 0.005)
                .onChange(of: withdrawalRate) { _, newValue in
                    config.withdrawalRate = newValue
                    // Keep guardrails on the correct side of the initial rate
                    if upperGuardrail < newValue {
                        upperGuardrail = newValue
                        config.upperGuardrail = newValue
                    }
                    if lowerGuardrail > newValue {
                        lowerGuardrail = newValue
                        config.lowerGuardrail = newValue
                    }
                }
            Text("First year withdrawal: \((portfolioValue * withdrawalRate).toCurrency())")
                .font(.caption)
                .foregroundColor(.blue)

            HStack {
                Text("Upper Guardrail Rate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(upperGuardrail.toPercent())
                    .font(.headline)
                    .monospacedDigit()
            }
            Slider(value: $upperGuardrail, in: withdrawalRate...0.15, step: 0.005)
                .onChange(of: upperGuardrail) { _, newValue in
                    config.upperGuardrail = newValue
                }
            Text("Cut spending 10% if current rate rises above \(upperGuardrail.toPercent()) — triggers when portfolio shrinks")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text("Lower Guardrail Rate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(lowerGuardrail.toPercent())
                    .font(.headline)
                    .monospacedDigit()
            }
            Slider(value: $lowerGuardrail, in: 0.005...withdrawalRate, step: 0.005)
                .onChange(of: lowerGuardrail) { _, newValue in
                    config.lowerGuardrail = newValue
                }
            Text("Raise spending 10% if current rate falls below \(lowerGuardrail.toPercent()) — triggers when portfolio grows")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack {
                Text("Adjustment Magnitude")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", (config.guardrailAdjustmentMagnitude ?? 0.10) * 100))
                    .font(.headline)
                    .monospacedDigit()
            }
            Slider(value: Binding(
                get: { config.guardrailAdjustmentMagnitude ?? 0.10 },
                set: { config.guardrailAdjustmentMagnitude = $0 }
            ), in: 0.05...0.20, step: 0.01)
            Text("Change spending by this percent when a guardrail is crossed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var fixedDollarSection: some View {
        Section("Fixed Dollar Amount") {
            HStack {
                Text("Annual Withdrawal Amount")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                TextField("Amount", value: $fixedDollarAmount, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 130)
                    .onChange(of: fixedDollarAmount) { _, newValue in
                        config.annualAmount = newValue
                    }
            }
            Text("Withdraws exactly this amount each year")
                .font(.caption)
                .foregroundColor(.secondary)
            Toggle("Adjust for Inflation", isOn: $config.adjustForInflation)
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
        
        // Work in REAL terms - assumed return is already real (inflation-adjusted)
        let assumedRealReturn = 0.02 // Assume 2% real return for projection (conservative)
        var balance = portfolioValue
        var baselineWithdrawal = firstYearWithdrawal
        
        for year in 1...30 {
            // Call the NEW calculateWithdrawal signature (no inflationRate parameter)
            let withdrawal = calculator.calculateWithdrawal(
                currentBalance: balance,
                year: year,
                baselineWithdrawal: baselineWithdrawal,
                initialBalance: portfolioValue,
                config: config
            )
            
            projections.append((year, withdrawal))
            
            // Update balance for next year using REAL return
            balance = balance * (1 + assumedRealReturn) - withdrawal
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
        case .fixedDollar:
            return config.adjustForInflation ? "Fixed amount adjusted for inflation" : "Same dollar amount every year"
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
                                HStack(alignment: .top, spacing: 8) {
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
            return "In year 1, withdraw a fixed dollar amount based on your initial rate. Each subsequent year, carry that same dollar amount forward. If the current withdrawal rate (dollars / current portfolio) rises above the upper guardrail, cut spending by 10%. If it falls below the lower guardrail, raise spending by 10%. Developed by Jonathan Guyton and William Klinger."
        case .fixedDollar:
            return "Withdraw the same dollar amount each year, optionally adjusted for inflation. Provides predictable income but doesn't respond to portfolio performance."
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
        case .fixedDollar:
            return [
                "Maximum spending predictability",
                "Simple to budget",
                "No calculations needed"
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
        case .fixedDollar:
            return [
                "Doesn't respond to portfolio changes",
                "Higher risk of depletion",
                "May leave money unspent"
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
        case .fixedDollar:
            return "Those with very specific spending needs or who have guaranteed income from other sources (pension, Social Security) covering basics."
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

