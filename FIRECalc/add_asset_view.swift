//
//  AddAssetView.swift
//  FIRECalc
//
//  Simplified asset entry with auto-loading ticker names and smart field display
//

import SwiftUI

struct AddAssetView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    @State private var assetName: String = ""
    @State private var selectedAssetClass: AssetClass = .stocks
    @State private var ticker: String = ""
    @State private var quantity: String = "1"
    @State private var unitValue: String = ""
    @State private var bondYield: String = ""
    @State private var showingAdvanced = false
    
    // Auto-price loading states
    @State private var isLoadingPrice: Bool = false
    @State private var autoLoadedPrice: Double?
    @State private var priceError: String?
    @State private var lastLoadedTicker: String = ""
    
    enum Field {
        case ticker, quantity, unitValue, bondYield
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Asset Type Selection
                Section("Asset Type") {
                    Picker("Type", selection: $selectedAssetClass) {
                        ForEach(AssetClass.allCases) { assetClass in
                            HStack {
                                Image(systemName: assetClass.iconName)
                                Text(assetClass.rawValue)
                            }
                            .tag(assetClass)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedAssetClass) { _, _ in
                        // Reset fields when asset class changes
                        ticker = ""
                        quantity = "1"
                        unitValue = ""
                        bondYield = ""
                        assetName = ""
                        autoLoadedPrice = nil
                        priceError = nil
                    }
                }
                
                // Ticker Input (for stocks, bonds, REITs, crypto, precious metals)
                if selectedAssetClass.supportsTicker || selectedAssetClass == .bonds || selectedAssetClass == .preciousMetals {
                    Section("Ticker Symbol") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("e.g., AAPL, SPY, GLD", text: $ticker)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .ticker)
                                .onChange(of: ticker) { oldValue, newValue in
                                    if oldValue != newValue {
                                        autoLoadedPrice = nil
                                        priceError = nil
                                        assetName = ""
                                        
                                        if !newValue.isEmpty && newValue.count >= 1 {
                                            scheduleAutoLoad()
                                        }
                                    }
                                }
                            
                            // Price loading feedback
                            if isLoadingPrice {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading...")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            } else if let price = autoLoadedPrice {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("\(assetName.isEmpty ? ticker.uppercased() : assetName) • \(price.toPreciseCurrency())")
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
                            
                            Text(tickerSuggestion)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Bond Yield (only for bonds)
                    if selectedAssetClass == .bonds {
                        Section("Bond Details") {
                            HStack {
                                Text("Yield %")
                                Spacer()
                                TextField("e.g., 4.5", text: $bondYield)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .focused($focusedField, equals: .bondYield)
                            }
                            
                            if let yieldVal = Double(bondYield), yieldVal > 0 {
                                Text("Annual yield: \(yieldVal)%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Value Section - Different for different asset types
                if needsQuantityAndPrice {
                    // Stocks, REITs, Crypto - Quantity + Price
                    Section("Quantity & Price") {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            TextField("0", text: $quantity)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .focused($focusedField, equals: .quantity)
                        }
                        
                        HStack {
                            Text("Price per Unit")
                            Spacer()
                            TextField("$0", text: $unitValue)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .focused($focusedField, equals: .unitValue)
                        }
                        
                        if let price = autoLoadedPrice, unitValue.isEmpty {
                            Button("Use Loaded Price (\(price.toPreciseCurrency()))") {
                                unitValue = String(price)
                                focusedField = nil
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        if let total = totalValue {
                            HStack {
                                Text("Total Value")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(total.toCurrency())
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                } else {
                    // Real Estate, Cash, Other - Value only
                    Section("Value") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Total Value", text: $unitValue)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .unitValue)
                            
                            if !selectedAssetClass.supportsTicker && assetName.isEmpty {
                                TextField("Asset Name (optional)", text: $assetName)
                            }
                            
                            if let value = Double(unitValue) {
                                Text("Value: \(value.toCurrency())")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
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
                            Text(displayName)
                                .font(.headline)
                                .foregroundColor(displayName.isEmpty ? .secondary : .primary)
                            
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
                        
                        if let total = totalValue {
                            Text(total.toCurrency())
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
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
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    focusedField = .ticker
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var needsQuantityAndPrice: Bool {
        selectedAssetClass == .stocks ||
        selectedAssetClass == .bonds ||
        selectedAssetClass == .reits ||
        selectedAssetClass == .crypto ||
        selectedAssetClass == .preciousMetals
    }
    
    private var displayName: String {
        if !assetName.isEmpty {
            return assetName
        } else if !ticker.isEmpty {
            return ticker.uppercased()
        } else if selectedAssetClass == .realEstate {
            return "Real Estate Property"
        } else if selectedAssetClass == .cash {
            return "Cash Holdings"
        } else if selectedAssetClass == .other {
            return "Other Asset"
        }
        return "New Asset"
    }
    
    private var totalValue: Double? {
        if needsQuantityAndPrice {
            let qty = Double(quantity) ?? 0
            let price = Double(unitValue) ?? autoLoadedPrice ?? 0
            return qty > 0 && price > 0 ? qty * price : nil
        } else {
            return Double(unitValue)
        }
    }
    
    private var isValid: Bool {
        if let total = totalValue, total > 0 {
            return true
        }
        return false
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
    
    private func scheduleAutoLoad() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if ticker.uppercased() != lastLoadedTicker && !ticker.isEmpty {
                loadPrice()
            }
        }
    }
    
    private func loadPrice() {
        guard !ticker.isEmpty else { return }
        
        let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        guard cleanTicker != lastLoadedTicker else { return }
        
        lastLoadedTicker = cleanTicker
        isLoadingPrice = true
        priceError = nil
        autoLoadedPrice = nil
        
        Task {
            do {
                let tempAsset = Asset(
                    name: cleanTicker,
                    assetClass: selectedAssetClass,
                    ticker: cleanTicker,
                    quantity: 1,
                    unitValue: 0
                )
                
                let price = try await AlternativePriceService.shared.fetchPrice(for: tempAsset)
                
                await MainActor.run {
                    autoLoadedPrice = price
                    assetName = cleanTicker
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
        focusedField = nil
        
        let finalName = assetName.isEmpty ? ticker.uppercased() : assetName
        let finalTicker = ticker.isEmpty ? nil : ticker.uppercased()
        
        let finalPrice: Double
        let finalQuantity: Double
        
        if needsQuantityAndPrice {
            finalPrice = Double(unitValue) ?? autoLoadedPrice ?? 0
            finalQuantity = Double(quantity) ?? 1
        } else {
            finalPrice = Double(unitValue) ?? 0
            finalQuantity = 1
        }
        
        let asset = Asset(
            name: finalName,
            assetClass: selectedAssetClass,
            ticker: finalTicker,
            quantity: finalQuantity,
            unitValue: finalPrice
        )
        
        portfolioVM.addAsset(asset)
        dismiss()
    }
}

#Preview {
    AddAssetView(portfolioVM: PortfolioViewModel())
}
