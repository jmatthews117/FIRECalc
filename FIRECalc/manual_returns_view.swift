//
//  manual_returns_view.swift
//  FIRECalc
//
//  NEW FILE - Manual return adjustments for simulations
//

import SwiftUI

struct ManualReturnsView: View {
    @ObservedObject var simulationVM: SimulationViewModel
    @ObservedObject var portfolioVM: PortfolioViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var useCustomReturns: Bool = false
    @State private var customReturns: [AssetClass: Double] = [:]
    @State private var customVolatility: [AssetClass: Double] = [:]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Use Custom Returns", isOn: $useCustomReturns)
                        .onChange(of: useCustomReturns) { _, newValue in
                            if newValue && customReturns.isEmpty {
                                initializeCustomReturns()
                            }
                        }
                    
                    if !useCustomReturns {
                        Text("Using historical bootstrap data from 1926-2024")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Return Method")
                } footer: {
                    Text("Custom returns override historical data for simulations")
                }
                
                if useCustomReturns {
                    ForEach(assetClassesInPortfolio, id: \.self) { assetClass in
                        Section(assetClass.rawValue) {
                            VStack(alignment: .leading, spacing: 12) {
                                // Expected Return
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Expected Return")
                                        Spacer()
                                        Text((customReturns[assetClass] ?? assetClass.defaultReturn).toPercent())
                                            .foregroundColor(.green)
                                    }
                                    
                                    Slider(
                                        value: Binding(
                                            get: { customReturns[assetClass] ?? assetClass.defaultReturn },
                                            set: { customReturns[assetClass] = $0 }
                                        ),
                                        in: -0.10...0.30,
                                        step: 0.005
                                    )
                                    
                                    Text("Historical: \(assetClass.defaultReturn.toPercent())")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Divider()
                                
                                // Volatility
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Volatility")
                                        Spacer()
                                        Text((customVolatility[assetClass] ?? assetClass.defaultVolatility).toPercent())
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Slider(
                                        value: Binding(
                                            get: { customVolatility[assetClass] ?? assetClass.defaultVolatility },
                                            set: { customVolatility[assetClass] = $0 }
                                        ),
                                        in: 0.01...0.80,
                                        step: 0.01
                                    )
                                    
                                    Text("Historical: \(assetClass.defaultVolatility.toPercent())")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Button("Reset to Historical") {
                                    customReturns[assetClass] = assetClass.defaultReturn
                                    customVolatility[assetClass] = assetClass.defaultVolatility
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Section("Portfolio-Wide Impact") {
                        HStack {
                            Text("Weighted Expected Return")
                            Spacer()
                            Text(calculatePortfolioReturn().toPercent())
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("Weighted Volatility")
                            Spacer()
                            Text(calculatePortfolioVolatility().toPercent())
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Section {
                        Button("Reset All to Historical") {
                            resetAllToHistorical()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Return Assumptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
    }
    
    private var assetClassesInPortfolio: [AssetClass] {
        let classes = Set(portfolioVM.portfolio.assets.map { $0.assetClass })
        return Array(classes).sorted { $0.rawValue < $1.rawValue }
    }
    
    private func initializeCustomReturns() {
        for assetClass in assetClassesInPortfolio {
            customReturns[assetClass] = assetClass.defaultReturn
            customVolatility[assetClass] = assetClass.defaultVolatility
        }
    }
    
    private func loadCurrentSettings() {
        useCustomReturns = simulationVM.useCustomReturns
        if useCustomReturns {
            customReturns = simulationVM.customReturns
            customVolatility = simulationVM.customVolatility
        } else {
            initializeCustomReturns()
        }
    }
    
    private func applyChanges() {
        simulationVM.useCustomReturns = useCustomReturns
        simulationVM.customReturns = customReturns
        simulationVM.customVolatility = customVolatility
    }
    
    private func resetAllToHistorical() {
        for assetClass in assetClassesInPortfolio {
            customReturns[assetClass] = assetClass.defaultReturn
            customVolatility[assetClass] = assetClass.defaultVolatility
        }
    }
    
    private func calculatePortfolioReturn() -> Double {
        let total = portfolioVM.totalValue
        guard total > 0 else { return 0 }
        
        return portfolioVM.portfolio.assets.reduce(0.0) { sum, asset in
            let weight = asset.totalValue / total
            let returnRate = customReturns[asset.assetClass] ?? asset.assetClass.defaultReturn
            return sum + (weight * returnRate)
        }
    }
    
    private func calculatePortfolioVolatility() -> Double {
        let total = portfolioVM.totalValue
        guard total > 0 else { return 0 }
        
        let variance = portfolioVM.portfolio.assets.reduce(0.0) { sum, asset in
            let weight = asset.totalValue / total
            let vol = customVolatility[asset.assetClass] ?? asset.assetClass.defaultVolatility
            return sum + pow(weight * vol, 2)
        }
        
        return sqrt(variance)
    }
}

#Preview {
    ManualReturnsView(
        simulationVM: SimulationViewModel(),
        portfolioVM: PortfolioViewModel(portfolio: .sample)
    )
}
