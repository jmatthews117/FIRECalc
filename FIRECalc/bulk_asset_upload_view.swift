//  bulk_asset_upload_view.swift
//  FIRECalc
//
//  Spreadsheet-style bulk asset upload
//

import SwiftUI

struct BulkAssetUploadView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var assetRows: [AssetRow] = [AssetRow()]
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Instructions
                instructionsHeader
                
                // Spreadsheet Header
                spreadsheetHeader
                
                // Scrollable rows
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach($assetRows) { $row in
                            BulkUploadRowView(row: $row, onDelete: {
                                deleteRow(row)
                            })
                        }
                    }
                }
                
                // Add Row Button
                addRowButton
                
                // Action Buttons
                actionButtons
            }
            .navigationTitle("Bulk Add Assets")
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
                Text("Fill in the spreadsheet below to add multiple assets at once")
                    .font(.subheadline)
            }
            
            Text("Tip: Leave Ticker blank for assets without tickers (real estate, etc.)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
    }
    
    private var spreadsheetHeader: some View {
        HStack(spacing: 1) {
            Text("Name")
                .headerStyle(width: 120)
            
            Text("Type")
                .headerStyle(width: 100)
            
            Text("Ticker")
                .headerStyle(width: 80)
            
            Text("Qty")
                .headerStyle(width: 70)
            
            Text("Price")
                .headerStyle(width: 80)
            
            Text("")
                .headerStyle(width: 40)
        }
        .background(Color(.systemGray5))
    }
    
    private var addRowButton: some View {
        Button(action: addRow) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Row")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Clear All") {
                assetRows = [AssetRow()]
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("Add \(validRowCount) Assets") {
                addAssets()
            }
            .buttonStyle(.borderedProminent)
            .disabled(validRowCount == 0)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var validRowCount: Int {
        assetRows.filter { $0.isValid }.count
    }
    
    private func addRow() {
        assetRows.append(AssetRow())
    }
    
    private func deleteRow(_ row: AssetRow) {
        if assetRows.count > 1 {
            assetRows.removeAll { $0.id == row.id }
        }
    }
    
    private func addAssets() {
        let validRows = assetRows.filter { $0.isValid }
        
        guard !validRows.isEmpty else {
            errorMessage = "No valid assets to add"
            showingError = true
            return
        }
        
        var addedCount = 0
        
        for row in validRows {
            let asset = Asset(
                name: row.name,
                assetClass: row.assetClass,
                ticker: row.ticker.isEmpty ? nil : row.ticker.uppercased(),
                quantity: Double(row.quantity) ?? 1,
                unitValue: Double(row.price) ?? 0
            )
            
            portfolioVM.addAsset(asset)
            addedCount += 1
        }
        
        dismiss()
    }
}

// MARK: - Asset Row Model

struct AssetRow: Identifiable {
    let id = UUID()
    var name: String = ""
    var assetClass: AssetClass = .stocks
    var ticker: String = ""
    var quantity: String = "1"
    var price: String = ""
    
    var isValid: Bool {
        !name.isEmpty && !price.isEmpty && Double(price) != nil && Double(quantity) != nil
    }
}

// MARK: - Bulk Upload Row View

struct BulkUploadRowView: View {
    @Binding var row: AssetRow
    let onDelete: () -> Void
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, ticker, quantity, price
    }
    
    var body: some View {
        HStack(spacing: 1) {
            TextField("Asset name", text: $row.name)
                .cellStyle(width: 120)
                .focused($focusedField, equals: .name)
            
            Menu {
                ForEach(AssetClass.allCases) { assetClass in
                    Button(action: { row.assetClass = assetClass }) {
                        HStack {
                            Image(systemName: assetClass.iconName)
                            Text(assetClass.rawValue)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(shortClassName(row.assetClass))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .cellStyle(width: 100)
            }
            
            TextField("Optional", text: $row.ticker)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .cellStyle(width: 80)
                .focused($focusedField, equals: .ticker)
            
            TextField("1", text: $row.quantity)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .cellStyle(width: 70)
                .focused($focusedField, equals: .quantity)
            
            TextField("$0", text: $row.price)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .cellStyle(width: 80)
                .focused($focusedField, equals: .price)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .frame(width: 40)
            }
        }
        .background(row.isValid ? Color.clear : Color.yellow.opacity(0.1))
    }
    
    private func shortClassName(_ assetClass: AssetClass) -> String {
        switch assetClass {
        case .stocks: return "Stocks"
        case .bonds: return "Bonds"
        case .reits: return "REITs"
        case .realEstate: return "Real Est"
        case .preciousMetals: return "Metals"
        case .crypto: return "Crypto"
        case .cash: return "Cash"
        case .other: return "Other"
        }
    }
}

// MARK: - View Modifiers

extension View {
    func headerStyle(width: CGFloat) -> some View {
        self
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
    }
    
    func cellStyle(width: CGFloat) -> some View {
        self
            .font(.subheadline)
            .frame(width: width, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .background(Color(.systemBackground))
    }
}

#Preview {
    BulkAssetUploadView(portfolioVM: PortfolioViewModel())
}
