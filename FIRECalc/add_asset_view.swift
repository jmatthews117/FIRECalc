//
//  AddAssetView.swift
//  FIRECalc
//
//  Screen for adding new assets to portfolio - ENHANCED with auto-price loading
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
    
    // Auto-price loading states
    @State private var isLoadingPrice: Bool = false
    @State private var autoLoadedPrice: Double?
    @State private var priceError: String?
    
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
                            HStack {
                                TextField("Ticker Symbol", text: $ticker)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .onChange(of: ticker) { oldValue, newValue in
                                        // Clear previous price when ticker changes
                                        if oldValue != newValue {
                                            autoLoadedPrice = nil
                                            priceError = nil
                                        }
                                    }
                                
                                if !ticker.isEmpty {
                                    Button(action: loadPrice) {
                                        if isLoadingPrice {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(isLoadingPrice)
                                }
                            }
                            
                            // Price loading feedback
                            if let price = autoLoadedPrice {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Loaded: \(price.toPreciseCurrency())")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            } else if let error = priceError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
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
                    
                    // Auto-fill button if price was loaded
                    if let price = autoLoadedPrice, unitValue.isEmpty {
                        Button("Use Loaded Price (\(price.toPreciseCurrency()))") {
                            unitValue = String(price)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
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
                            
                            HStack(spacing: 4) {
                                Text(selectedAssetClass.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if !ticker.isEmpty {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(ticker.uppercased())
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
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
        let price = Double(unitValue) ?? autoLoadedPrice ?? 0
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
    
    private func loadPrice() {
        guard !ticker.isEmpty else { return }
        
        isLoadingPrice = true
        priceError = nil
        autoLoadedPrice = nil
        
        Task {
            do {
                let tempAsset = Asset(
                    name: assetName.isEmpty ? ticker.uppercased() : assetName,
                    assetClass: selectedAssetClass,
                    ticker: ticker.uppercased(),
                    quantity: 1,
                    unitValue: 0
                )
                
                let price = try await AlternativePriceService.shared.fetchPrice(for: tempAsset)
                
                await MainActor.run {
                    autoLoadedPrice = price
                    // Auto-populate name if empty
                    if assetName.isEmpty {
                        assetName = ticker.uppercased()
                    }
                    isLoadingPrice = false
                }
            } catch {
                await MainActor.run {
                    priceError = "Could not load price"
                    isLoadingPrice = false
                }
            }
        }
    }
    
    private func addAsset() {
        let finalPrice = Double(unitValue) ?? autoLoadedPrice ?? 0
        
        let asset = Asset(
            name: assetName,
            assetClass: selectedAssetClass,
            ticker: ticker.isEmpty ? nil : ticker.uppercased(),
            quantity: Double(quantity) ?? 1,
            unitValue: finalPrice
        )
        
        portfolioVM.addAsset(asset)
        dismiss()
    }
}

#Preview {
    AddAssetView(portfolioVM: PortfolioViewModel())
}
