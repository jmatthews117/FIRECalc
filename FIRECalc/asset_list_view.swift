//
//  AssetListView.swift
//  FIRECalc
//
//  Full list of portfolio assets
//

import SwiftUI

struct AssetListView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel
    @State private var showingAddAsset = false
    
    var body: some View {
        List {
            // Summary Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Total Portfolio Value")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(portfolioVM.totalValue.toCurrency())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack {
                        Label("\(portfolioVM.portfolio.assets.count) Assets", systemImage: "chart.bar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: { Task { await portfolioVM.refreshPrices() } }) {
                            Label("Refresh Prices", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(portfolioVM.isUpdatingPrices)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Assets by Class
            ForEach(AssetClass.allCases) { assetClass in
                let assetsInClass = portfolioVM.portfolio.assets(for: assetClass)
                
                if !assetsInClass.isEmpty {
                    Section(header: assetClassHeader(assetClass: assetClass, assets: assetsInClass)) {
                        ForEach(assetsInClass) { asset in
                            AssetDetailRow(asset: asset)
                        }
                        .onDelete { offsets in
                            deleteAssets(in: assetClass, at: offsets)
                        }
                    }
                }
            }
        }
        .navigationTitle("Assets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddAsset = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddAsset) {
            AddAssetView(portfolioVM: portfolioVM)
        }
    }
    
    private func assetClassHeader(assetClass: AssetClass, assets: [Asset]) -> some View {
        HStack {
            Image(systemName: assetClass.iconName)
            Text(assetClass.rawValue)
            Spacer()
            Text(portfolioVM.portfolio.totalValue(for: assetClass).toCurrency())
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func deleteAssets(in assetClass: AssetClass, at offsets: IndexSet) {
        let assetsInClass = portfolioVM.portfolio.assets(for: assetClass)
        for index in offsets {
            portfolioVM.deleteAsset(assetsInClass[index])
        }
    }
}

struct AssetDetailRow: View {
    let asset: Asset
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(asset.name)
                    .font(.headline)
                
                if let ticker = asset.ticker {
                    Text(ticker)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Text(asset.totalValue.toCurrency())
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            HStack {
                if asset.quantity != 1 {
                    Text("\(asset.quantity.toDecimal()) units × \(asset.unitValue.toPreciseCurrency())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let change = asset.priceChange {
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(change.toPercent())
                    }
                    .font(.caption)
                    .foregroundColor(change >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        AssetListView(portfolioVM: PortfolioViewModel(portfolio: .sample))
    }
}
