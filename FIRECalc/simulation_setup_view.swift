//
//  SimulationSetupView.swift
//  FIRECalc
//
//  Configure and run Monte Carlo simulation
//

import SwiftUI

struct SimulationSetupView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @ObservedObject var simulationVM: SimulationViewModel
    @Binding var showingResults: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var numberOfRuns: Double
    @State private var timeHorizon: Double
    @State private var inflationRate: Double

    // MARK: - New parameters

    /// Whether to use a custom (user-typed) target rather than the live portfolio value.
    @State private var useTargetPortfolioValue: Bool
    @State private var targetPortfolioValue: Double
    /// Whether to override the portfolio's existing allocation with custom weights.
    @State private var useCustomAllocation: Bool
    /// Live-editable custom weights keyed by AssetClass, expressed as percentages (0-100).
    @State private var customAllocationPercents: [AssetClass: Double]

    // Single source of truth for the entire withdrawal configuration.
    // Strategy-specific controls below mutate this directly so nothing
    // is lost when runSimulation() fires.
    @State private var withdrawalConfig: WithdrawalConfiguration

    // Per-strategy local state, kept in sync with withdrawalConfig
    @State private var withdrawalRate: Double
    @State private var fixedDollarAmount: Double
    @State private var upperGuardrail: Double
    @State private var lowerGuardrail: Double
    @State private var floorEnabled: Bool
    @State private var floorRate: Double
    @State private var ceilingEnabled: Bool
    @State private var ceilingRate: Double

    @StateObject private var benefitManager = DefinedBenefitManager()

    // Income buckets read from persisted plans at sheet-open time.
    private let storedRealBucket: Double
    private let storedNominalBucket: Double

    init(portfolioVM: PortfolioViewModel, simulationVM: SimulationViewModel, showingResults: Binding<Bool>) {
        self.portfolioVM = portfolioVM
        self.simulationVM = simulationVM
        self._showingResults = showingResults

        self._numberOfRuns = State(initialValue: Double(simulationVM.parameters.numberOfRuns))
        self._timeHorizon = State(initialValue: Double(simulationVM.parameters.timeHorizonYears))
        self._inflationRate = State(initialValue: simulationVM.parameters.inflationRate)

        // Restore previously saved new parameters (fall back to sensible defaults).
        let params = simulationVM.parameters
        self._useTargetPortfolioValue = State(initialValue: params.targetPortfolioValue != nil)
        self._targetPortfolioValue = State(initialValue: params.targetPortfolioValue ?? portfolioVM.totalValue)

        let hasCustomAlloc = params.customAllocationWeights != nil
        self._useCustomAllocation = State(initialValue: hasCustomAlloc)

        // Seed the per-class sliders from saved weights, or from the live portfolio.
        var initialPercents: [AssetClass: Double] = [:]
        if let saved = params.customAllocationWeights {
            for (ac, w) in saved { initialPercents[ac] = w * 100 }
        } else {
            let totalValue = portfolioVM.portfolio.totalValue
            if totalValue > 0 {
                for ac in AssetClass.allCases {
                    let classValue = portfolioVM.portfolio.assets
                        .filter { $0.assetClass == ac }
                        .reduce(0) { $0 + $1.totalValue }
                    let pct = (classValue / totalValue) * 100
                    if pct > 0 { initialPercents[ac] = pct }
                }
            }
        }
        self._customAllocationPercents = State(initialValue: initialPercents)

        let config = simulationVM.withdrawalConfiguration
        self._withdrawalConfig = State(initialValue: config)
        self._withdrawalRate = State(initialValue: config.withdrawalRate)
        self._fixedDollarAmount = State(initialValue: config.annualAmount ?? 40_000)
        self._upperGuardrail = State(initialValue: config.upperGuardrail ?? (config.withdrawalRate * 1.25))
        self._lowerGuardrail = State(initialValue: config.lowerGuardrail ?? (config.withdrawalRate * 0.80))
        self._floorEnabled = State(initialValue: config.floorPercentage != nil)
        self._floorRate = State(initialValue: config.floorPercentage ?? 0.025)
        self._ceilingEnabled = State(initialValue: config.ceilingPercentage != nil)
        self._ceilingRate = State(initialValue: config.ceilingPercentage ?? 0.06)

        // Capture income buckets from persisted plans at sheet-open time.
        let plans = PersistenceService.shared.loadDefinedBenefitPlans()
        let planTotal = plans.reduce(0) { $0 + $1.annualBenefit }
        let realBucket = plans.filter { $0.inflationAdjusted }.reduce(0) { $0 + $1.annualBenefit }
        self.storedRealBucket = realBucket
        self.storedNominalBucket = planTotal - realBucket
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Portfolio Summary
                Section("Portfolio") {
                    HStack {
                        Text("Total Value")
                        Spacer()
                        Text(portfolioVM.totalValue.toCurrency())
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Expected Return")
                        Spacer()
                        Text(portfolioVM.portfolio.weightedExpectedReturn.toPercent())
                            .fontWeight(.semibold)
                    }
                }

                // MARK: Starting Portfolio Value
                Section {
                    Picker("Starting Value", selection: $useTargetPortfolioValue) {
                        Text("Current Portfolio").tag(false)
                        Text("Custom Target").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if useTargetPortfolioValue {
                        HStack {
                            Text("Target Value")
                            Spacer()
                            TextField("$1,000,000", value: $targetPortfolioValue, format: .currency(code: "USD"))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 150)
                        }
                        Text("Simulates what happens if you start with this balance — useful for \"what-if\" scenarios.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        HStack {
                            Text("Current Portfolio")
                            Spacer()
                            Text(portfolioVM.totalValue.toCurrency())
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Starting Portfolio Value")
                } footer: {
                    Text("\"Custom Target\" lets you model a future scenario without changing your actual portfolio.")
                }

                // MARK: Asset Allocation
                Section {
                    Picker("Allocation", selection: $useCustomAllocation) {
                        Text("Existing Portfolio").tag(false)
                        Text("Custom Weights").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if useCustomAllocation {
                        allocationSliders
                    } else {
                        // Show a read-only summary of the current allocation.
                        let totalValue = portfolioVM.portfolio.totalValue
                        ForEach(AssetClass.allCases) { ac in
                            let classValue = portfolioVM.portfolio.assets
                                .filter { $0.assetClass == ac }
                                .reduce(0.0) { $0 + $1.totalValue }
                            if classValue > 0 {
                                HStack {
                                    Circle()
                                        .fill(ac.color)
                                        .frame(width: 8, height: 8)
                                    Text(ac.rawValue)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(totalValue > 0
                                         ? (classValue / totalValue).toPercent()
                                         : "—")
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                } header: {
                    Text("Asset Allocation")
                } footer: {
                    if useCustomAllocation {
                        Text("Weights must sum to 100%. Current total: \(Int(customAllocationTotal.rounded()))%")
                            .foregroundColor(allocationIsValid ? .secondary : .red)
                    } else {
                        Text("Uses the weighted return and volatility of your existing holdings.")
                    }
                }

                // Simulation Parameters
                Section("Simulation Settings") {
                    HStack {
                        Text("Simulation Runs")
                        Spacer()
                        Text("\(Int(numberOfRuns))")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $numberOfRuns, in: 1000...50000, step: 1000)
                    Text("More runs = more accurate, but slower")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Time Horizon")
                        Spacer()
                        Text("\(Int(timeHorizon)) years")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $timeHorizon, in: 5...50, step: 1)

                    HStack {
                        Text("Inflation Rate")
                        Spacer()
                        Text(inflationRate.toPercent())
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $inflationRate, in: 0...0.10, step: 0.005)
                }
                
                // Withdrawal Strategy — strategy picker + strategy-specific controls
                Section("Withdrawal Strategy") {
                    Picker("Strategy", selection: $withdrawalConfig.strategy) {
                        ForEach(WithdrawalStrategy.allCases) { strategy in
                            Text(strategy.rawValue).tag(strategy)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(withdrawalConfig.strategy.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Strategy-specific inputs
                strategyInputSection

                // Fixed Income Section
                Section {
                    if benefitManager.plans.isEmpty {
                        Text("No plans configured. Add them in the Settings tab.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(benefitManager.plans) { plan in
                            HStack {
                                Image(systemName: plan.type.iconName)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plan.name)
                                        .font(.subheadline)
                                    Text(plan.inflationAdjusted ? "COLA — constant real value" : "Fixed — erodes with inflation")
                                        .font(.caption)
                                        .foregroundColor(plan.inflationAdjusted ? .green : .orange)
                                }
                                Spacer()
                                Text(plan.annualBenefit.toCurrency())
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        HStack {
                            Text("Total")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(formatCurrency(storedRealBucket + storedNominalBucket))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text("Fixed Income")
                } footer: {
                    Text("Pensions, Social Security, and annuities reduce required portfolio withdrawals each year.")
                }
                
                // Quick Presets
                Section("Quick Presets") {
                    Button("Conservative (3.5%, 30yr)") {
                        applyPreset(rate: 0.035, years: 30, runs: 10000)
                    }
                    
                    Button("Moderate (4%, 30yr)") {
                        applyPreset(rate: 0.04, years: 30, runs: 10000)
                    }
                    
                    Button("Aggressive (5%, 30yr)") {
                        applyPreset(rate: 0.05, years: 30, runs: 10000)
                    }
                }
                
                // Run Button
                Section {
                    if simulationVM.isSimulating {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Running simulation...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                    } else {
                        Button(action: runSimulation) {
                            HStack {
                                Spacer()
                                Image(systemName: "play.fill")
                                Text("Run Simulation")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    
                    if let error = simulationVM.errorMessage {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    if simulationVM.hasResult {
                        Text("✅ Simulation completed!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                // Debug Summary Section
                Section("Assumptions Summary") {
                    HStack {
                        Text("Starting Portfolio")
                        Spacer()
                        Text((useTargetPortfolioValue ? targetPortfolioValue : portfolioVM.totalValue).toCurrency())
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Allocation")
                        Spacer()
                        Text(useCustomAllocation ? "Custom" : "Portfolio Weights")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Strategy")
                        Spacer()
                        Text(withdrawalConfig.strategy.rawValue)
                            .foregroundColor(.secondary)
                    }
                    if withdrawalConfig.strategy == .fixedDollar {
                        HStack {
                            Text("Annual Withdrawal")
                            Spacer()
                            Text(fixedDollarAmount.toCurrency())
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Withdrawal Rate")
                            Spacer()
                            Text(withdrawalRate.toPercent())
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Text("Fixed Income")
                        Spacer()
                        Text(formatCurrency(storedRealBucket + storedNominalBucket))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("First-Year Gross Withdrawal")
                        Spacer()
                        Text(debugGrossWithdrawal.toCurrency())
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("First-Year Net Withdrawal")
                        Spacer()
                        Text(max(0, debugGrossWithdrawal - storedRealBucket - storedNominalBucket).toCurrency())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Setup Simulation")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Strategy-specific input sections

    @ViewBuilder
    private var strategyInputSection: some View {
        switch withdrawalConfig.strategy {
        case .fixedPercentage:
            fixedPercentageInputs
        case .dynamicPercentage:
            dynamicPercentageInputs
        case .guardrails:
            guardrailsInputs
        case .fixedDollar:
            fixedDollarInputs
        }
    }

    private var fixedPercentageInputs: some View {
        Section("4% Rule Configuration") {
            HStack {
                Text("Withdrawal Rate")
                Spacer()
                Text(withdrawalRate.toPercent())
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $withdrawalRate, in: 0.01...0.10, step: 0.005)
                .onChange(of: withdrawalRate) { _, v in
                    withdrawalConfig.withdrawalRate = v
                }
            Text("First year: \((portfolioVM.totalValue * withdrawalRate).toCurrency()) · stays constant in real terms")
                .font(.caption)
                .foregroundColor(.secondary)
            Toggle("Adjust for Inflation", isOn: $withdrawalConfig.adjustForInflation)
        }
    }

    private var dynamicPercentageInputs: some View {
        Section("Dynamic Percentage Configuration") {
            HStack {
                Text("Withdrawal Rate")
                Spacer()
                Text(withdrawalRate.toPercent())
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $withdrawalRate, in: 0.01...0.10, step: 0.005)
                .onChange(of: withdrawalRate) { _, v in
                    withdrawalConfig.withdrawalRate = v
                    // Clamp floor/ceiling to stay on the correct side
                    if floorEnabled, floorRate > v {
                        floorRate = v
                        withdrawalConfig.floorPercentage = v
                    }
                    if ceilingEnabled, ceilingRate < v {
                        ceilingRate = v
                        withdrawalConfig.ceilingPercentage = v
                    }
                }
            Text("Withdraws \(withdrawalRate.toPercent()) of current balance each year")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Set Floor", isOn: $floorEnabled)
                .onChange(of: floorEnabled) { _, enabled in
                    if enabled {
                        floorRate = min(floorRate, withdrawalRate)
                        withdrawalConfig.floorPercentage = floorRate
                    } else {
                        withdrawalConfig.floorPercentage = nil
                    }
                }

            if floorEnabled {
                HStack {
                    Text("Minimum Rate")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(floorRate.toPercent())
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $floorRate, in: 0.005...withdrawalRate, step: 0.005)
                    .onChange(of: floorRate) { _, v in
                        withdrawalConfig.floorPercentage = v
                    }
                Text("Fixed floor: \((portfolioVM.totalValue * floorRate).toCurrency())/yr (based on initial portfolio)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Toggle("Set Ceiling", isOn: $ceilingEnabled)
                .onChange(of: ceilingEnabled) { _, enabled in
                    if enabled {
                        ceilingRate = max(ceilingRate, withdrawalRate)
                        withdrawalConfig.ceilingPercentage = ceilingRate
                    } else {
                        withdrawalConfig.ceilingPercentage = nil
                    }
                }

            if ceilingEnabled {
                HStack {
                    Text("Maximum Rate")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(ceilingRate.toPercent())
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $ceilingRate, in: withdrawalRate...0.15, step: 0.005)
                    .onChange(of: ceilingRate) { _, v in
                        withdrawalConfig.ceilingPercentage = v
                    }
                Text("Fixed ceiling: \((portfolioVM.totalValue * ceilingRate).toCurrency())/yr (based on initial portfolio)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var guardrailsInputs: some View {
        Section("Guardrails Configuration") {
            HStack {
                Text("Initial Withdrawal Rate")
                Spacer()
                Text(withdrawalRate.toPercent())
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $withdrawalRate, in: 0.01...0.10, step: 0.005)
                .onChange(of: withdrawalRate) { _, v in
                    withdrawalConfig.withdrawalRate = v
                    // Keep guardrails on the correct side of the initial rate
                    if upperGuardrail < v {
                        upperGuardrail = v
                        withdrawalConfig.upperGuardrail = v
                    }
                    if lowerGuardrail > v {
                        lowerGuardrail = v
                        withdrawalConfig.lowerGuardrail = v
                    }
                }
            Text("First year: \((portfolioVM.totalValue * withdrawalRate).toCurrency())")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text("Upper Guardrail Rate")
                Spacer()
                Text(upperGuardrail.toPercent())
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $upperGuardrail, in: withdrawalRate...0.15, step: 0.005)
                .onChange(of: upperGuardrail) { _, v in
                    withdrawalConfig.upperGuardrail = v
                }
            Text("Cut spending 10% if current rate rises above \(upperGuardrail.toPercent()) — triggers when portfolio shrinks")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text("Lower Guardrail Rate")
                Spacer()
                Text(lowerGuardrail.toPercent())
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $lowerGuardrail, in: 0.005...withdrawalRate, step: 0.005)
                .onChange(of: lowerGuardrail) { _, v in
                    withdrawalConfig.lowerGuardrail = v
                }
            Text("Raise spending 10% if current rate falls below \(lowerGuardrail.toPercent()) — triggers when portfolio grows")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()

            HStack {
                Text("Adjustment Magnitude")
                Spacer()
                Text(String(format: "%.0f%%", (withdrawalConfig.guardrailAdjustmentMagnitude ?? 0.10) * 100))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: Binding(
                get: { withdrawalConfig.guardrailAdjustmentMagnitude ?? 0.10 },
                set: { withdrawalConfig.guardrailAdjustmentMagnitude = $0 }
            ), in: 0.05...0.20, step: 0.01)
            Text("Change spending by this percent when a guardrail is crossed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var fixedDollarInputs: some View {
        Section("Fixed Dollar Configuration") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Annual Withdrawal")
                    Spacer()
                    TextField("Amount", value: $fixedDollarAmount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 130)
                        .onChange(of: fixedDollarAmount) { _, v in withdrawalConfig.annualAmount = v }
                }
                Text("Monthly: \((fixedDollarAmount / 12).toCurrency())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Toggle("Adjust for Inflation", isOn: $withdrawalConfig.adjustForInflation)
        }
    }

    // MARK: - Helpers
    
    private func formatNumberInput(_ input: String) -> String {
        let digitsOnly = input.filter { $0.isNumber }
        if let number = Int(digitsOnly) {
            return formatNumber(number)
        }
        return digitsOnly
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }
    
    private func parseFormattedNumber(_ formatted: String) -> Double? {
        let digitsOnly = formatted.filter { $0.isNumber }
        return Double(digitsOnly)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
    
    private func applyPreset(rate: Double, years: Double, runs: Double) {
        withdrawalRate = rate
        withdrawalConfig.withdrawalRate = rate
        timeHorizon = years
        numberOfRuns = runs
    }
    
    private func runSimulation() {
        print("🚀 Starting simulation...")
        
        let settings = PersistenceService.shared.loadSettings()
        let useBootstrap = simulationVM.useCustomReturns ? false : settings.useHistoricalBootstrap

        // Stamp inflation rate and income buckets into the config.
        var config = withdrawalConfig
        config.inflationRate = inflationRate
        config.fixedIncomeReal    = storedRealBucket    > 0 ? storedRealBucket    : nil
        config.fixedIncomeNominal = storedNominalBucket > 0 ? storedNominalBucket : nil
        
        // Synchronize strategy-specific fields
        if config.strategy == .fixedDollar {
            config.annualAmount = fixedDollarAmount
        } else {
            config.withdrawalRate = withdrawalRate
        }

        // Persist the configuration back to the VM so it survives navigation.
        simulationVM.withdrawalConfiguration = config
        simulationVM.updateWithdrawalRate(withdrawalRate)
        simulationVM.updateTimeHorizon(Int(timeHorizon))
        simulationVM.updateInflationRate(inflationRate)

        // Build custom allocation weights (fractional) from the per-class percents.
        let resolvedAllocation: [AssetClass: Double]? = useCustomAllocation && allocationIsValid
            ? customAllocationPercents.mapValues { $0 / 100.0 }
            : nil

        simulationVM.parameters = SimulationParameters(
            numberOfRuns: Int(numberOfRuns),
            timeHorizonYears: Int(timeHorizon),
            inflationRate: inflationRate,
            useHistoricalBootstrap: useBootstrap,
            initialPortfolioValue: portfolioVM.totalValue,
            targetPortfolioValue: useTargetPortfolioValue ? targetPortfolioValue : nil,
            customAllocationWeights: resolvedAllocation,
            withdrawalConfig: config
        )
        
        Task {
            print("📊 Running simulation with \(Int(numberOfRuns)) runs...")
            await simulationVM.runSimulation(portfolio: portfolioVM.portfolio)
            
            print("✅ Simulation complete. Has result: \(simulationVM.hasResult)")

            if simulationVM.hasResult {
                print("📈 Opening results view...")
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                await MainActor.run {
                    dismiss()
                    showingResults = true
                }
            } else {
                print("❌ No result available. Error: \(simulationVM.errorMessage ?? "Unknown")")
            }
        }
    }
    
    // MARK: - Debug Computed Properties
    
    private var debugGrossWithdrawal: Double {
        if withdrawalConfig.strategy == .fixedDollar {
            return fixedDollarAmount
        } else {
            return portfolioVM.totalValue * withdrawalRate
        }
    }

    // MARK: - Custom Allocation Helpers

    /// Sum of all custom allocation percents (should equal 100 when valid).
    private var customAllocationTotal: Double {
        customAllocationPercents.values.reduce(0, +)
    }

    /// True when custom weights are either unused or sum to 100 ± 1.
    private var allocationIsValid: Bool {
        guard useCustomAllocation else { return true }
        return (99.0...101.0).contains(customAllocationTotal)
    }

    /// Sliders for each asset class weight, with a running total indicator.
    @ViewBuilder
    private var allocationSliders: some View {
        ForEach(AssetClass.allCases) { ac in
            VStack(spacing: 2) {
                HStack {
                    Circle()
                        .fill(ac.color)
                        .frame(width: 8, height: 8)
                    Text(ac.rawValue)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int((customAllocationPercents[ac] ?? 0).rounded()))%")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { customAllocationPercents[ac] ?? 0 },
                        set: { customAllocationPercents[ac] = $0 }
                    ),
                    in: 0...100,
                    step: 1
                )
            }
        }

        // Running total
        HStack {
            Text("Total")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text("\(Int(customAllocationTotal.rounded()))%")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(allocationIsValid ? .green : .red)
                .monospacedDigit()
        }
        .padding(.top, 4)
    }
}

#Preview {
    SimulationSetupView(
        portfolioVM: PortfolioViewModel(portfolio: .sample),
        simulationVM: SimulationViewModel(),
        showingResults: .constant(false)
    )
}

