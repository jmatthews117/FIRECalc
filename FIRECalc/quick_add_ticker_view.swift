//
//  QuickAddTickerView.swift
//  FIRECalc
//
//  Quick add common tickers with live price lookup
//

import SwiftUI

struct QuickAddTickerView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTicker: String = ""
    @State private var quantity: String = "1"
    @State private var isLoadingPrice: Bool = false
    @State private var currentPrice: Double?
    @State private var errorMessage: String?
    
    let commonAssets: [(name: String, ticker: String, assetClass: AssetClass)] = [
        // Stocks
        ("S&P 500 ETF", "SPY", .stocks),
        ("Total Market ETF", "VTI", .stocks),
        ("Nasdaq 100", "QQQ", .stocks),
        ("Apple", "AAPL", .stocks),
        ("Microsoft", "MSFT", .stocks),
        ("Amazon", "AMZN", .stocks),
        
        // Bonds
        ("20+ Year Treasury", "TLT", .bonds),
        ("Corp Bonds", "LQD", .bonds),
        ("High Yield Bonds", "HYG", .bonds),
        ("TIPS", "TIP", .bonds),
        
        // REITs
        ("Real Estate ETF", "VNQ", .reits),
        ("Realty Income", "O", .reits),
        
        // Precious Metals
        ("Gold ETF", "GLD", .preciousMetals),
        ("Silver ETF", "SLV", .preciousMetals),
        
        // Crypto
        ("Bitcoin", "BTC", .crypto),
        ("Ethereum", "ETH", .crypto)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Popular Assets") {
                    ForEach(commonAssets, id: \.ticker) { asset in
                        Button(action: { selectAsset(asset) }) {
                            HStack {
                                Image(systemName: asset.assetClass.iconName)
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(asset.name)
                                        .foregroundColor(.primary)
                                    Text(asset.ticker)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedTicker == asset.ticker && isLoadingPrice {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else if selectedTicker == asset.ticker && currentPrice != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if let ticker = selectedTicker.isEmpty ? nil : selectedTicker {
                    Section("Add to Portfolio") {
                        let asset = commonAssets.first { $0.ticker == ticker }!
                        
                        HStack {
                            Text("Asset")
                            Spacer()
                            Text(asset.name)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Ticker")
                            Spacer()
                            Text(ticker)
                                .foregroundColor(.secondary)
                        }
                        
                        if let price = currentPrice {
                            HStack {
                                Text("Current Price")
                                Spacer()
                                Text(price.toPreciseCurrency())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        HStack {
                            Text("Quantity")
                            Spacer()
                            TextField("0", text: $quantity)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                        
                        if let price = currentPrice {
                            HStack {
                                Text("Total Value")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(totalValue.toCurrency())
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Button(action: addAsset) {
                            HStack {
                                Spacer()
                                Text("Add to Portfolio")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(currentPrice == nil)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Error")
                                    .fontWeight(.semibold)
                            }
                            
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Text("Tip: Verify the ticker symbol.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var totalValue: Double {
        guard let price = currentPrice else { return 0 }
        let qty = Double(quantity) ?? 0
        return price * qty
    }
    
    private func selectAsset(_ asset: (name: String, ticker: String, assetClass: AssetClass)) {
        selectedTicker = asset.ticker
        currentPrice = nil
        errorMessage = nil
        
        print("🎯 Selected asset: \(asset.name) (\(asset.ticker))")
        
        Task {
            isLoadingPrice = true
            
            do {
                print("💰 Fetching price for \(asset.ticker)...")
                
                let tempAsset = Asset(
                    name: asset.name,
                    assetClass: asset.assetClass,
                    ticker: asset.ticker,
                    quantity: 1,
                    unitValue: 0
                )
                
                let price = try await AlternativePriceService.shared.fetchPrice(for: tempAsset)
                
                print("✅ Got price: $\(price)")
                
                await MainActor.run {
                    currentPrice = price
                    isLoadingPrice = false
                }
            } catch {
                print("❌ Failed to fetch price: \(error.localizedDescription)")
                
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingPrice = false
                }
            }
        }
    }
    
    private func addAsset() {
        guard let asset = commonAssets.first(where: { $0.ticker == selectedTicker }),
              let price = currentPrice else {
            return
        }
        
        let newAsset = Asset(
            name: asset.name,
            assetClass: asset.assetClass,
            ticker: asset.ticker,
            quantity: Double(quantity) ?? 1,
            unitValue: price
        )
        
        portfolioVM.addAsset(newAsset)
        dismiss()
    }
}

#Preview {
    QuickAddTickerView(portfolioVM: PortfolioViewModel())
}
