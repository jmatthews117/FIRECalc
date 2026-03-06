//
//  SubscriptionPaywallView.swift
//  FIRECalc
//
//  Paywall view for FIRECalc Pro subscription
//

import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerSection
                    
                    // Features
                    featuresSection
                    
                    // Subscription Plans
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                    } else {
                        subscriptionPlansSection
                    }
                    
                    // Purchase Button
                    if let product = selectedProduct ?? subscriptionManager.availableProducts.first {
                        purchaseButton(for: product)
                    }
                    
                    // Restore Purchases
                    restorePurchasesButton
                    
                    // Legal Links
                    legalLinksSection
                }
                .padding()
            }
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(subscriptionManager.errorMessage != nil)) {
                Button("OK") {
                    subscriptionManager.errorMessage = nil
                }
            } message: {
                if let error = subscriptionManager.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text("FIRECalc Pro")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            
            Text("Track your portfolio in real-time")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(spacing: 20) {
            FeatureRow(
                icon: "chart.xyaxis.line",
                iconColor: .blue,
                title: "Live Stock Prices",
                description: "Automatic price updates for stocks, ETFs, and crypto"
            )
            
            FeatureRow(
                icon: "arrow.clockwise",
                iconColor: .green,
                title: "Portfolio Refresh",
                description: "Pull-to-refresh keeps your portfolio current"
            )
            
            FeatureRow(
                icon: "dollarsign.circle.fill",
                iconColor: .orange,
                title: "Real-Time Values",
                description: "See your exact portfolio value at any moment"
            )
            
            FeatureRow(
                icon: "sparkles",
                iconColor: .purple,
                title: "Ticker Search",
                description: "Find and add assets by ticker symbol"
            )
            
            // Free Trial Banner
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(.green)
                Text("7-day free trial included!")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Subscription Plans Section
    
    private var subscriptionPlansSection: some View {
        VStack(spacing: 12) {
            Text("Choose Your Plan")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            ForEach(subscriptionManager.availableProducts, id: \.id) { product in
                SubscriptionPlanCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    savingsText: subscriptionManager.savingsText(for: product)
                ) {
                    selectedProduct = product
                }
            }
        }
    }
    
    // MARK: - Purchase Button
    
    private func purchaseButton(for product: Product) -> some View {
        VStack(spacing: 8) {
            Button(action: {
                Task {
                    let success = await subscriptionManager.purchase(product)
                    if success {
                        dismiss()
                    }
                }
            }) {
                HStack {
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        VStack(spacing: 4) {
                            Text("Start Free Trial")
                                .fontWeight(.bold)
                            Text("Then \(product.displayPrice)")
                                .font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(subscriptionManager.isLoading)
            
            // Free trial disclaimer
            Text("Cancel anytime during trial. No charge until trial ends.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Restore Purchases Button
    
    private var restorePurchasesButton: some View {
        Button(action: {
            Task {
                await subscriptionManager.restorePurchases()
                if subscriptionManager.isProSubscriber {
                    dismiss()
                }
            }
        }) {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .disabled(subscriptionManager.isLoading)
    }
    
    // MARK: - Legal Links Section
    
    private var legalLinksSection: some View {
        VStack(spacing: 8) {
            Text("Start 7-day free trial. Subscription auto-renews after trial unless cancelled. Cancel anytime in Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Link("Terms of Service", destination: URL(string: "https://yourwebsite.com/terms")!)
                Text("•")
                    .foregroundColor(.secondary)
                Link("Privacy Policy", destination: URL(string: "https://yourwebsite.com/privacy")!)
            }
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Subscription Plan Card

struct SubscriptionPlanCard: View {
    let product: Product
    let isSelected: Bool
    let savingsText: String?
    let onTap: () -> Void
    
    private var isYearly: Bool {
        product.id.contains("yearly")
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(isYearly ? "Annual Plan" : "Monthly Plan")
                            .font(.headline)
                        
                        if let savings = savingsText {
                            Text(savings)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(product.displayPrice + (isYearly ? "/year" : "/month"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if isYearly {
                        Text("Just $1.67 per month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .shadow(color: isSelected ? .blue.opacity(0.2) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    SubscriptionPaywallView()
}
