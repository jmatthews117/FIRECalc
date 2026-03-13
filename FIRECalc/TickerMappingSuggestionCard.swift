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
    let onUseAlternative: (String, String, Double, Double) -> Void  // (displayName, lookupTicker, quantity, unitPrice) -> Void
    let onDismiss: () -> Void
    
    @State private var holdingsValue: String = ""
    @State private var isLoadingPrice: Bool = false
    @State private var etfPrice: Double?
    @State private var priceError: String?
    @State private var keepOriginalName: Bool = true  // NEW: Allow user to choose name
    @FocusState private var isValueFieldFocused: Bool
    
    private var calculatedShares: Double? {
        guard let value = Double(holdingsValue.replacingOccurrences(of: ",", with: "")),
              let price = etfPrice,
              value > 0,
              price > 0 else {
            print("❌ calculatedShares = nil: holdingsValue='\(holdingsValue)', etfPrice=\(String(describing: etfPrice))")
            return nil
        }
        let shares = value / price
        print("✅ calculatedShares = \(shares): value=\(value), price=\(price)")
        return shares
    }
    
    private var isReadyToConvert: Bool {
        let ready = calculatedShares != nil
        print("🔘 isReadyToConvert = \(ready)")
        return ready
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
                            .onChange(of: holdingsValue) { oldValue, newValue in
                                print("💰 holdingsValue changed: '\(oldValue)' → '\(newValue)'")
                            }
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
                    
                    // Name preference toggle
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display as")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Toggle(isOn: $keepOriginalName) {
                            HStack(spacing: 6) {
                                Text("Keep original ticker name")
                                    .font(.subheadline)
                                Text("(\(originalTicker))")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(.blue)
                        
                        if keepOriginalName {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text("Asset will show as \(originalTicker), but prices will be tracked using \(mapping.etfAlternative)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, 4)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text("Asset will show as \(mapping.etfAlternative)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 4)
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
                    print("🔵 Blue button tapped! isReadyToConvert = \(isReadyToConvert)")
                    print("   - calculatedShares: \(String(describing: calculatedShares))")
                    print("   - holdingsValue: '\(holdingsValue)'")
                    print("   - etfPrice: \(String(describing: etfPrice))")
                    print("   - keepOriginalName: \(keepOriginalName)")
                    
                    isValueFieldFocused = false
                    if let shares = calculatedShares, let price = etfPrice {
                        let displayName = keepOriginalName ? originalTicker : mapping.etfAlternative
                        let lookupTicker = mapping.etfAlternative
                        print("   - Calling onUseAlternative with:")
                        print("     - displayName: \(displayName)")
                        print("     - lookupTicker: \(lookupTicker)")
                        print("     - shares: \(shares)")
                        print("     - price: \(price)")
                        onUseAlternative(displayName, lookupTicker, shares, price)
                    } else {
                        print("   - ❌ Button tapped but validation failed!")
                        print("     - calculatedShares: \(String(describing: calculatedShares))")
                        print("     - etfPrice: \(String(describing: etfPrice))")
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(keepOriginalName ? "Add as \(originalTicker)" : "Add as \(mapping.etfAlternative)")
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
        // REMOVED: .onTapGesture was blocking button taps
        // The keyboard dismisses when user taps the button anyway
        .onAppear {
            print("🔔 TickerMappingSuggestionCard appeared for \(originalTicker) → \(mapping.etfAlternative)")
            // Auto-load ETF price when card appears
            loadETFPrice()
        }
    }
    
    // MARK: - Price Loading
    
    private func loadETFPrice() {
        print("🔄 loadETFPrice called for \(mapping.etfAlternative)")
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
                
                print("📡 Fetching price for \(mapping.etfAlternative)...")
                let price = try await AlternativePriceService.shared.fetchPrice(for: tempAsset, bypassCooldown: true)
                
                await MainActor.run {
                    print("✅ Loaded ETF price: \(mapping.etfAlternative) = $\(price)")
                    etfPrice = price
                    isLoadingPrice = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to load ETF price: \(error.localizedDescription)")
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
        onUseAlternative: { displayName, lookupTicker, quantity, price in
            print("Display: \(displayName), Lookup: \(lookupTicker), Shares: \(quantity) @ \(price)")
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
        onUseAlternative: { displayName, lookupTicker, quantity, price in
            print("Display: \(displayName), Lookup: \(lookupTicker), Shares: \(quantity) @ \(price)")
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
        onUseAlternative: { displayName, lookupTicker, quantity, price in
            print("Display: \(displayName), Lookup: \(lookupTicker), Shares: \(quantity) @ \(price)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
    .padding()
}
