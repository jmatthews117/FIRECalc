//
//  TickerMappingSuggestionCard.swift
//  FIRECalc
//
//  Reusable component for displaying ticker mapping suggestions
//  with value-based conversion to equivalent ETF shares
//

import SwiftUI

/// A card that displays a suggestion to use an ETF alternative for an unsupported ticker
/// Allows user to input their holding value and automatically converts to ETF shares
struct TickerMappingSuggestionCard: View {
    let originalTicker: String
    let mapping: TickerMapping
    let assetClass: AssetClass
    let onUseAlternative: (Double, Double) -> Void  // (quantity, unitPrice) -> Void
    let onDismiss: () -> Void
    
    @State private var holdingsValue: String = ""
    @State private var isLoadingPrice: Bool = false
    @State private var etfPrice: Double?
    @State private var priceError: String?
    @FocusState private var isValueFieldFocused: Bool
    
    private var calculatedShares: Double? {
        guard let value = Double(holdingsValue.replacingOccurrences(of: ",", with: "")),
              let price = etfPrice,
              value > 0,
              price > 0 else {
            return nil
        }
        return value / price
    }
    
    private var isReadyToConvert: Bool {
        calculatedShares != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unsupported Ticker")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    Text("\(originalTicker) cannot be tracked with live prices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Suggestion
            VStack(alignment: .leading, spacing: 10) {
                Text("We'll track it using this equivalent ETF:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // ETF Info
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mapping.etfAlternative)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text(mapping.etfName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    // Price display or load button
                    if isLoadingPrice {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let price = etfPrice {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(price.toPreciseCurrency())
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("per share")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else if priceError != nil {
                        Button("Retry") {
                            loadETFPrice()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    } else {
                        Button("Get Price") {
                            loadETFPrice()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                }
                
                // Reason
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(mapping.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Value conversion section
            if etfPrice != nil {
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("What's your total \(originalTicker) value?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("10,000", text: $holdingsValue)
                            .keyboardType(.decimalPad)
                            .focused($isValueFieldFocused)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Show conversion calculation
                    if let shares = calculatedShares, let price = etfPrice {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(.green)
                                Text("Converts to:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(shares, specifier: "%.4f") shares")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                    Text("of \(mapping.etfAlternative) @ \(price.toPreciseCurrency())")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.green.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Error message
                    if let error = priceError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    isValueFieldFocused = false
                    onDismiss()
                }) {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    isValueFieldFocused = false
                    if let shares = calculatedShares, let price = etfPrice {
                        onUseAlternative(shares, price)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Add as \(mapping.etfAlternative)")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isReadyToConvert ? Color.blue : Color.gray)
                    .cornerRadius(8)
                }
                .disabled(!isReadyToConvert)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
        )
        .onTapGesture {
            // Dismiss keyboard when tapping outside text field
            isValueFieldFocused = false
        }
        .onAppear {
            // Auto-load ETF price when card appears
            loadETFPrice()
        }
    }
    
    // MARK: - Price Loading
    
    private func loadETFPrice() {
        isLoadingPrice = true
        priceError = nil
        etfPrice = nil
        
        Task {
            do {
                let tempAsset = Asset(
                    name: mapping.etfAlternative,
                    assetClass: assetClass,
                    ticker: mapping.etfAlternative,
                    quantity: 1,
                    unitValue: 0
                )
                
                let price = try await AlternativePriceService.shared.fetchPrice(for: tempAsset, bypassCooldown: true)
                
                await MainActor.run {
                    etfPrice = price
                    isLoadingPrice = false
                }
            } catch {
                await MainActor.run {
                    priceError = "Could not load \(mapping.etfAlternative) price"
                    isLoadingPrice = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("VTSAX Suggestion") {
    TickerMappingSuggestionCard(
        originalTicker: "VTSAX",
        mapping: TickerMapping(
            name: "Vanguard Total Stock Market Index Fund",
            etfAlternative: "VTI",
            etfName: "Vanguard Total Stock Market ETF",
            reason: "Nearly identical holdings and performance"
        ),
        assetClass: .stocks,
        onUseAlternative: { quantity, price in
            print("Use VTI: \(quantity) shares @ \(price)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
    .padding()
}

#Preview("BTC Suggestion") {
    TickerMappingSuggestionCard(
        originalTicker: "BTC",
        mapping: TickerMapping(
            name: "Bitcoin",
            etfAlternative: "IBIT",
            etfName: "iShares Bitcoin Trust (or FBTC/GBTC)",
            reason: "Direct Bitcoin exposure via regulated ETF"
        ),
        assetClass: .crypto,
        onUseAlternative: { quantity, price in
            print("Use IBIT: \(quantity) shares @ \(price)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
    .padding()
}

#Preview("FXAIX Suggestion") {
    TickerMappingSuggestionCard(
        originalTicker: "FXAIX",
        mapping: TickerMapping(
            name: "Fidelity 500 Index Fund",
            etfAlternative: "VOO",
            etfName: "Vanguard S&P 500 ETF (or SPY/IVV)",
            reason: "Tracks S&P 500"
        ),
        assetClass: .stocks,
        onUseAlternative: { quantity, price in
            print("Use VOO: \(quantity) shares @ \(price)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
    .padding()
}
