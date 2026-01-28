//
//  AddAssetView.swift
//  FIRECalc
//
//  Screen for adding new assets to portfolio
//

import SwiftUI

struct AddAssetView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var assetName: String = ""
    @State private var selectedAssetClass: AssetClass = .stocks
    @State private var ticker: String = ""
    @State private var quantity: String = "1"
    @State private var unitValue: String = ""
    @State private var showingAdvanced = false
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Asset Details") {
                    TextField("Asset Name", text: $assetName)
                    
                    Picker("Asset Class", selection: $selectedAssetClass) {
                        ForEach(AssetClass.allCases) { assetClass in
                            HStack {
                                Image(systemName: assetClass.iconName)
                                Text(assetClass.rawValue)
                            }
                            .tag(assetClass)
                        }
                    }
                    
                    if selectedAssetClass.supportsTicker {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Ticker Symbol (Optional)", text: $ticker)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                            
                            // Show helpful suggestions based on asset class
                            Text(tickerSuggestion)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Value Information
                Section("Value") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("0", text: $quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Price per Unit")
                        Spacer()
                        TextField("$0", text: $unitValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Total Value")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(totalValue.toCurrency())
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                
                // Advanced Options
                Section {
                    Button(action: { showingAdvanced.toggle() }) {
                        HStack {
                            Text("Advanced Options")
                            Spacer()
                            Image(systemName: showingAdvanced ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if showingAdvanced {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom Expected Return")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Default: \(selectedAssetClass.defaultReturn.toPercent())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom Volatility")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Default: \(selectedAssetClass.defaultVolatility.toPercent())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Preview
                Section("Preview") {
                    HStack {
                        Image(systemName: selectedAssetClass.iconName)
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(assetName.isEmpty ? "Asset Name" : assetName)
                                .font(.headline)
                                .foregroundColor(assetName.isEmpty ? .secondary : .primary)
                            
                            Text(selectedAssetClass.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(totalValue.toCurrency())
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Add Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAsset()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var totalValue: Double {
        let qty = Double(quantity) ?? 0
        let price = Double(unitValue) ?? 0
        return qty * price
    }
    
    private var isValid: Bool {
        !assetName.isEmpty &&
        totalValue > 0
    }
    
    private var tickerSuggestion: String {
        switch selectedAssetClass {
        case .stocks:
            return "e.g., AAPL, SPY, VTI, QQQ"
        case .bonds:
            return "e.g., TLT (Treasury), LQD (Corporate), HYG (High Yield)"
        case .reits:
            return "e.g., VNQ (REIT Index), O (Realty Income)"
        case .preciousMetals:
            return "e.g., GLD (Gold), SLV (Silver), PPLT (Platinum)"
        case .crypto:
            return "e.g., BTC, ETH, LTC, BCH"
        default:
            return ""
        }
    }
    
    // MARK: - Actions
    
    private func addAsset() {
        let asset = Asset(
            name: assetName,
            assetClass: selectedAssetClass,
            ticker: ticker.isEmpty ? nil : ticker.uppercased(),
            quantity: Double(quantity) ?? 1,
            unitValue: Double(unitValue) ?? 0
        )
        
        portfolioVM.addAsset(asset)
        dismiss()
    }
}

#Preview {
    AddAssetView(portfolioVM: PortfolioViewModel())
}
