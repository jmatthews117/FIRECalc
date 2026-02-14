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

    // Per-run override — pre-populated from stored plans, resets after run.
    @State private var fixedIncomeOverride: String = "0"
    // The total stored in plans at the time the sheet opened (used to restore).
    private let storedPlanTotal: Double

    init(portfolioVM: PortfolioViewModel, simulationVM: SimulationViewModel, showingResults: Binding<Bool>) {
        self.portfolioVM = portfolioVM
        self.simulationVM = simulationVM
        self._showingResults = showingResults

        self._numberOfRuns = State(initialValue: Double(simulationVM.parameters.numberOfRuns))
        self._timeHorizon = State(initialValue: Double(simulationVM.parameters.timeHorizonYears))
        self._inflationRate = State(initialValue: simulationVM.parameters.inflationRate)

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

        // Seed the override from the persisted plan total.
        let planTotal = PersistenceService.shared.loadDefinedBenefitPlans()
            .reduce(0) { $0 + $1.annualBenefit }
        self.storedPlanTotal = planTotal
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        let formattedTotal = formatter.string(from: NSNumber(value: Int(planTotal))) ?? "0"
        self._fixedIncomeOverride = State(initialValue: formattedTotal)
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
                    // Per-plan breakdown (read-only)
                    if benefitManager.plans.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                            Text("No plans configured")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            Spacer()
                            NavigationLink("Add in Settings") {
                                DefinedBenefitPlansView()
                            }
                            .font(.subheadline)
                        }
                    } else {
                        ForEach(benefitManager.plans) { plan in
                            HStack {
                                Image(systemName: plan.type.iconName)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plan.name)
                                        .font(.subheadline)
                                    HStack(spacing: 4) {
                                        Text(plan.type.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if plan.inflationAdjusted {
                                            Text("• COLA")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                                Spacer()
                                Text(plan.annualBenefit.toCurrency())
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }

                        Divider()

                        HStack {
                            Text("Stored Total")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(storedPlanTotal.toCurrency())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Editable override for this run only
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Override for this run")
                                .font(.subheadline)
                            Spacer()
                            TextField("$0", text: $fixedIncomeOverride)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                .onChange(of: fixedIncomeOverride) { _, newVal in
                                    fixedIncomeOverride = formatNumberInput(newVal)
                                }
                        }

                        if let income = parseFormattedNumber(fixedIncomeOverride), income > 0 {
                            let overrideIsModified = abs(income - storedPlanTotal) > 0.5
                            if overrideIsModified {
                                Label(
                                    "Modified from stored \(storedPlanTotal.toCurrency()) — resets after run",
                                    systemImage: "arrow.uturn.backward.circle"
                                )
                                .font(.caption)
                                .foregroundColor(.orange)
                            } else {
                                Text("Reduces required withdrawals by \(formatCurrency(income))/yr")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Fixed Income")
                        Spacer()
                        NavigationLink("Manage") {
                            DefinedBenefitPlansView()
                        }
                        .font(.caption)
                    }
                } footer: {
                    Text("Pensions, Social Security, and annuities reduce required portfolio withdrawals each year. Manage your plans in Settings → Defined Benefits.")
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
                Section("Debug Summary") {
                    HStack {
                        Text("Initial Portfolio Value")
                        Spacer()
                        Text(portfolioVM.totalValue.toCurrency())
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
                        Text("Stored Plan Total")
                        Spacer()
                        Text(formatCurrency(storedPlanTotal))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Override for This Run")
                        Spacer()
                        Text(formatCurrency(parseFormattedNumber(fixedIncomeOverride) ?? 0))
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
                        let income = parseFormattedNumber(fixedIncomeOverride) ?? 0
                        Text(max(0, debugGrossWithdrawal - income).toCurrency())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Setup Simulation")
            .navigationBarTitleDisplayMode(.inline)
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

        // Stamp the inflation rate into the config so Fixed Dollar nominal mode works.
        var config = withdrawalConfig
        config.inflationRate = inflationRate

        // Use the per-run override value for this run.
        config.fixedIncome = parseFormattedNumber(fixedIncomeOverride) ?? 0
        
        // Synchronize strategy-specific fields
        if config.strategy == .fixedDollar {
            config.annualAmount = fixedDollarAmount
        } else {
            config.withdrawalRate = withdrawalRate
        }

        // Persist the configuration back to the VM so it survives navigation.
        // fixedIncome here carries the override — we'll restore the plan total below.
        simulationVM.withdrawalConfiguration = config

        simulationVM.updateWithdrawalRate(withdrawalRate)
        simulationVM.updateTimeHorizon(Int(timeHorizon))
        simulationVM.updateInflationRate(inflationRate)
        
        simulationVM.parameters = SimulationParameters(
            numberOfRuns: Int(numberOfRuns),
            timeHorizonYears: Int(timeHorizon),
            inflationRate: inflationRate,
            useHistoricalBootstrap: useBootstrap,
            initialPortfolioValue: portfolioVM.totalValue,
            withdrawalConfig: config
        )
        
        Task {
            print("📊 Running simulation with \(Int(numberOfRuns)) runs...")
            await simulationVM.runSimulation(portfolio: portfolioVM.portfolio)
            
            print("✅ Simulation complete. Has result: \(simulationVM.hasResult)")

            // Restore withdrawalConfiguration.fixedIncome to the stored plan total
            // so the override doesn't persist beyond this single run.
            var restoredConfig = simulationVM.withdrawalConfiguration
            restoredConfig.fixedIncome = storedPlanTotal > 0 ? storedPlanTotal : nil
            simulationVM.withdrawalConfiguration = restoredConfig
            
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
}

#Preview {
    SimulationSetupView(
        portfolioVM: PortfolioViewModel(portfolio: .sample),
        simulationVM: SimulationViewModel(),
        showingResults: .constant(false)
    )
}

