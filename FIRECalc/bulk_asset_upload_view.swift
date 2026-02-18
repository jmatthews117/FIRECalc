//  bulk_asset_upload_view.swift
//  FIRECalc
//
//  Intuitive multi-asset upload interface
//

import SwiftUI

struct BulkAssetUploadView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var assets: [DraftAsset] = [DraftAsset()]
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isLoadingPrices: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Instructions
                instructionsHeader
                
                // Asset Cards
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach($assets) { $asset in
                            AssetEntryCard(
                                asset: $asset,
                                onDelete: {
                                    deleteAsset(asset)
                                },
                                onLoadPrice: {
                                    loadPrice(for: asset)
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                // Bottom Actions
                bottomActions
            }
            .navigationTitle("Add Multiple Assets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var instructionsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Add multiple assets quickly")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text("Fill out each card below, then tap 'Add All Assets' when finished")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
    }
    
    private var bottomActions: some View {
        VStack(spacing: 12) {
            Button(action: addNewAssetCard) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Another Asset")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            HStack(spacing: 12) {
                Button("Clear All") {
                    assets = [DraftAsset()]
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Add \(validAssetCount) Asset\(validAssetCount == 1 ? "" : "s")") {
                    addAllAssets()
                }
                .buttonStyle(.borderedProminent)
                .disabled(validAssetCount == 0)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var validAssetCount: Int {
        assets.filter { $0.isValid }.count
    }
    
    private func addNewAssetCard() {
        withAnimation {
            assets.append(DraftAsset())
        }
    }
    
    private func deleteAsset(_ asset: DraftAsset) {
        if assets.count > 1 {
            withAnimation {
                assets.removeAll { $0.id == asset.id }
            }
        } else {
            assets = [DraftAsset()]
        }
    }
    
    private func loadPrice(for asset: DraftAsset) {
        guard !asset.ticker.isEmpty else { return }
        
        Task {
            do {
                let tempAsset = Asset(
                    name: asset.name.isEmpty ? asset.ticker : asset.name,
                    assetClass: asset.assetClass,
                    ticker: asset.ticker,
                    quantity: 1,
                    unitValue: 0
                )
                
                let price = try await AlternativePriceService.shared.fetchPrice(for: tempAsset)
                
                await MainActor.run {
                    if let index = assets.firstIndex(where: { $0.id == asset.id }) {
                        assets[index].price = String(price)
                        assets[index].loadedPrice = price
                        if assets[index].name.isEmpty {
                            assets[index].name = asset.ticker
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Could not load price for \(asset.ticker)"
                    showingError = true
                }
            }
        }
    }
    
    private func addAllAssets() {
        let validAssets = assets.filter { $0.isValid }
        
        guard !validAssets.isEmpty else {
            errorMessage = "No valid assets to add"
            showingError = true
            return
        }
        
        for draft in validAssets {
            let asset = Asset(
                name: draft.name,
                assetClass: draft.assetClass,
                ticker: draft.ticker.isEmpty ? nil : draft.ticker.uppercased(),
                quantity: Double(draft.quantity.replacingOccurrences(of: ",", with: "")) ?? 1,
                unitValue: Double(draft.price.replacingOccurrences(of: ",", with: "")) ?? 0
            )
            
            portfolioVM.addAsset(asset)
        }
        
        dismiss()
    }
}

// MARK: - Draft Asset Model

struct DraftAsset: Identifiable {
    let id = UUID()
    var name: String = ""
    var assetClass: AssetClass = .stocks
    var ticker: String = ""
    var quantity: String = "1"
    var price: String = ""
    var loadedPrice: Double?
    
    var isValid: Bool {
        !name.isEmpty && !price.isEmpty &&
        Double(price.replacingOccurrences(of: ",", with: "")) != nil &&
        Double(quantity.replacingOccurrences(of: ",", with: "")) != nil
    }
}

// MARK: - Asset Entry Card

struct AssetEntryCard: View {
    @Binding var asset: DraftAsset
    let onDelete: () -> Void
    let onLoadPrice: () -> Void
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, ticker, quantity, price
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with delete button
            HStack {
                Image(systemName: asset.assetClass.iconName)
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text(asset.name.isEmpty ? "New Asset" : asset.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            Divider()
            
            // Asset Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Asset Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g., Apple Stock", text: $asset.name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)
            }
            
            // Asset Type
            VStack(alignment: .leading, spacing: 4) {
                Text("Asset Type")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Asset Type", selection: $asset.assetClass) {
                    ForEach(AssetClass.allCases) { assetClass in
                        HStack {
                            Image(systemName: assetClass.iconName)
                            Text(assetClass.rawValue)
                        }
                        .tag(assetClass)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Ticker (optional)
            if asset.assetClass.supportsTicker {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Ticker Symbol (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if !asset.ticker.isEmpty {
                            Button(action: onLoadPrice) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Load Price")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    TextField("e.g., AAPL", text: $asset.ticker)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .ticker)
                    
                    if let loaded = asset.loadedPrice {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Loaded: \(loaded.toPreciseCurrency())")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            // Quantity and Price
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quantity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("1", text: $asset.quantity)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .quantity)
                        .onChange(of: asset.quantity) { newValue in
                            let cleaned = newValue.replacingOccurrences(of: ",", with: "")
                            if let number = Double(cleaned) {
                                let formatter = NumberFormatter()
                                formatter.numberStyle = .decimal
                                formatter.groupingSeparator = ","
                                formatter.maximumFractionDigits = 6
                                asset.quantity = formatter.string(from: NSNumber(value: number)) ?? cleaned
                            } else {
                                asset.quantity = cleaned
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Price per Unit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("$0", text: $asset.price)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .price)
                        .onChange(of: asset.price) { newValue in
                            let cleaned = newValue.replacingOccurrences(of: ",", with: "")
                            if let number = Double(cleaned) {
                                let formatter = NumberFormatter()
                                formatter.numberStyle = .decimal
                                formatter.groupingSeparator = ","
                                formatter.maximumFractionDigits = 6
                                asset.price = formatter.string(from: NSNumber(value: number)) ?? cleaned
                            } else {
                                asset.price = cleaned
                            }
                        }
                }
            }
            
            // Total Value Preview
            if let qty = Double(asset.quantity.replacingOccurrences(of: ",", with: "")),
               let price = Double(asset.price.replacingOccurrences(of: ",", with: "")) {
                HStack {
                    Text("Total Value:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text((qty * price).toCurrency())
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
            
            // Validation indicator
            if !asset.isValid && (!asset.name.isEmpty || !asset.price.isEmpty) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Please fill all required fields")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(asset.isValid ? Color(.systemBackground) : Color.yellow.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(asset.isValid ? Color.gray.opacity(0.2) : Color.orange, lineWidth: 1)
        )
        .shadow(radius: 2)
    }
}

#Preview {
    BulkAssetUploadView(portfolioVM: PortfolioViewModel())
}
