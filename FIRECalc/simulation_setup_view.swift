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
    
    @State private var numberOfRuns: Double = 10000
    @State private var timeHorizon: Double = 30
    @State private var inflationRate: Double = 0.02
    @State private var withdrawalRate: Double = 0.04
    @State private var selectedStrategy: WithdrawalStrategy = .fixedPercentage
    
    @State private var fixedIncome: String = "0"
    
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Simulation Runs")
                            Spacer()
                            Text("\(Int(numberOfRuns))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $numberOfRuns, in: 1000...50000, step: 1000)
                        
                        Text("More runs = more accurate, but slower")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Time Horizon")
                            Spacer()
                            Text("\(Int(timeHorizon)) years")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $timeHorizon, in: 5...50, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Inflation Rate")
                            Spacer()
                            Text(inflationRate.toPercent())
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $inflationRate, in: 0...0.10, step: 0.005)
                    }
                }
                
                // Withdrawal Strategy
                Section("Withdrawal Strategy") {
                    Picker("Strategy", selection: $selectedStrategy) {
                        ForEach(WithdrawalStrategy.allCases) { strategy in
                            Text(strategy.rawValue)
                                .tag(strategy)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Withdrawal Rate")
                            Spacer()
                            Text(withdrawalRate.toPercent())
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $withdrawalRate, in: 0.01...0.10, step: 0.005)
                        
                        Text("Initial annual withdrawal: \((portfolioVM.totalValue * withdrawalRate).toCurrency())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(selectedStrategy.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Fixed Income Section
                Section("Fixed Income (Pension & Social Security)") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Annual Fixed Income")
                            Spacer()
                            TextField("$0", text: $fixedIncome)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }
                        .onChange(of: fixedIncome) { _, newVal in
                            fixedIncome = formatNumberInput(newVal)
                        }
                        
                        if let income = parseFormattedNumber(fixedIncome), income > 0 {
                            Text("This reduces required portfolio withdrawals by \(formatCurrency(income)) per year")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Text("We treat pensions and Social Security as external income that offsets your spending needs. Each year, required withdrawals from the portfolio are reduced by this amount (but not below zero).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                    
                    // Debug info
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
            }
            .navigationTitle("Setup Simulation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
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
        timeHorizon = years
        numberOfRuns = runs
    }
    
    private func runSimulation() {
        print("🚀 Starting simulation...")
        
        let settings = PersistenceService.shared.loadSettings()
        let useBootstrap = simulationVM.useCustomReturns ? false : settings.useHistoricalBootstrap
        
        // Update simulation parameters
        simulationVM.updateWithdrawalRate(withdrawalRate)
        simulationVM.updateTimeHorizon(Int(timeHorizon))
        simulationVM.updateInflationRate(inflationRate)
        
        // Update number of runs
        simulationVM.parameters = SimulationParameters(
            numberOfRuns: Int(numberOfRuns),
            timeHorizonYears: Int(timeHorizon),
            inflationRate: inflationRate,
            useHistoricalBootstrap: useBootstrap,
            initialPortfolioValue: portfolioVM.totalValue,
            withdrawalConfig: WithdrawalConfiguration(
                strategy: selectedStrategy,
                withdrawalRate: withdrawalRate,
                fixedIncome: parseFormattedNumber(fixedIncome) ?? 0
            )
        )
        
        Task {
            print("📊 Running simulation with \(Int(numberOfRuns)) runs...")
            await simulationVM.runSimulation(portfolio: portfolioVM.portfolio)
            
            print("✅ Simulation complete. Has result: \(simulationVM.hasResult)")
            
            if simulationVM.hasResult {
                print("📈 Opening results view...")
                // Small delay to ensure state updates
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                await MainActor.run {
                    dismiss()
                    showingResults = true
                }
            } else {
                print("❌ No result available. Error: \(simulationVM.errorMessage ?? "Unknown")")
            }
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

