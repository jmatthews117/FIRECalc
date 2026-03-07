//
//  SubscriptionManager.swift
//  FIRECalc
//
//  Manages StoreKit 2 subscriptions for Pro features
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var isProSubscriber = false
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Product IDs
    
    private let monthlyProductID = "com.firecalc.pro.monthly"  // TODO: Replace with your actual product ID
    private let yearlyProductID = "com.firecalc.pro.yearly"    // TODO: Replace with your actual product ID
    
    private var productIDs: [String] {
        [monthlyProductID, yearlyProductID]
    }
    
    // MARK: - Subscription Status
    
    enum SubscriptionStatus: Equatable {
        case notSubscribed
        case subscribed(productID: String, expirationDate: Date?)
        case expired
        case inGracePeriod
        
        var isActive: Bool {
            switch self {
            case .subscribed, .inGracePeriod:
                return true
            case .notSubscribed, .expired:
                return false
            }
        }
    }
    
    // MARK: - Transaction Listener
    
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Initialization
    
    init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products and check subscription status
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Request products from the App Store
            let products = try await Product.products(for: productIDs)
            
            if products.isEmpty {
                print("⚠️ No products returned from App Store")
                print("   Product IDs requested: \(productIDs)")
                print("   Make sure these IDs match your App Store Connect configuration")
                errorMessage = "No subscription products available. Please ensure the app is properly configured."
            } else {
                // Sort: monthly first, then yearly
                self.availableProducts = products.sorted { product1, product2 in
                    if product1.id == monthlyProductID { return true }
                    if product2.id == monthlyProductID { return false }
                    return product1.id < product2.id
                }
                
                print("✅ Loaded \(products.count) subscription products:")
                for product in products {
                    print("   - \(product.id): \(product.displayName) - \(product.displayPrice)")
                }
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            print("   Error details: \(error.localizedDescription)")
            errorMessage = "Unable to load subscription options. Please check your internet connection and try again."
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        print("🛒 Attempting to purchase: \(product.displayName) (\(product.id))")
        
        do {
            // Attempt the purchase
            let result = try await product.purchase()
            
            switch result {
            case .success(let verificationResult):
                print("✅ Purchase result: success")
                
                // Check verification
                switch verificationResult {
                case .verified(let transaction):
                    print("✅ Transaction verified")
                    print("   - Product ID: \(transaction.productID)")
                    print("   - Transaction ID: \(transaction.id)")
                    print("   - Purchase Date: \(transaction.purchaseDate)")
                    
                    // Transaction is verified, finish it
                    await transaction.finish()
                    print("✅ Transaction finished")
                    
                    // Update subscription status
                    print("🔄 Updating subscription status...")
                    await updateSubscriptionStatus()
                    
                    // Verify the update worked
                    print("📊 After update - isProSubscriber: \(isProSubscriber)")
                    
                    isLoading = false
                    return true
                    
                case .unverified(let transaction, let error):
                    // Transaction failed verification
                    print("❌ Transaction failed verification: \(error)")
                    errorMessage = "Purchase verification failed. Please contact support."
                    await transaction.finish()
                    isLoading = false
                    return false
                }
                
            case .userCancelled:
                print("ℹ️ User cancelled purchase")
                isLoading = false
                return false
                
            case .pending:
                print("⏳ Purchase pending approval")
                errorMessage = "Purchase is pending approval."
                isLoading = false
                return false
                
            @unknown default:
                print("❌ Unknown purchase result")
                errorMessage = "An unknown error occurred."
                isLoading = false
                return false
            }
        } catch {
            print("❌ Purchase failed with error: \(error)")
            print("   Error description: \(error.localizedDescription)")
            errorMessage = "Purchase failed. Please try again."
            isLoading = false
            return false
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Sync with the App Store
            try await AppStore.sync()
            
            // Update subscription status
            await updateSubscriptionStatus()
            
            if isProSubscriber {
                print("✅ Purchases restored successfully")
            } else {
                print("ℹ️ No active subscriptions found")
                errorMessage = "No active subscriptions found."
            }
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            errorMessage = "Failed to restore purchases. Please try again."
        }
        
        isLoading = false
    }
    
    // MARK: - Subscription Status
    
    func updateSubscriptionStatus() async {
        print("🔍 Checking subscription status...")
        
        // METHOD 1: Check currentEntitlements (works for both StoreKit testing and production)
        var hasActiveSubscription = false
        var activeProductID: String?
        var expirationDate: Date?
        
        for await result in Transaction.currentEntitlements {
            // Verify the transaction
            guard case .verified(let transaction) = result else {
                print("⚠️ Unverified transaction found")
                continue
            }
            
            // Check if this is one of our subscription products
            if productIDs.contains(transaction.productID) {
                print("✅ Found active entitlement for: \(transaction.productID)")
                print("   - Purchase Date: \(transaction.purchaseDate)")
                print("   - Expiration Date: \(transaction.expirationDate?.description ?? "none")")
                print("   - Revocation Date: \(transaction.revocationDate?.description ?? "none")")
                
                // Check if subscription is still valid (not revoked and not expired)
                if transaction.revocationDate == nil {
                    if let expiration = transaction.expirationDate {
                        // Has expiration date - check if it's in the future
                        if expiration > Date() {
                            hasActiveSubscription = true
                            activeProductID = transaction.productID
                            expirationDate = expiration
                            print("✅ Subscription is active (expires: \(expiration))")
                        } else {
                            print("❌ Subscription expired on: \(expiration)")
                        }
                    } else {
                        // No expiration date means it's a lifetime purchase or active subscription
                        hasActiveSubscription = true
                        activeProductID = transaction.productID
                        print("✅ Subscription is active (no expiration)")
                    }
                } else {
                    print("❌ Subscription was revoked")
                }
            }
        }
        
        // Update published properties
        if hasActiveSubscription, let productID = activeProductID {
            isProSubscriber = true
            subscriptionStatus = .subscribed(productID: productID, expirationDate: expirationDate)
            print("✅ User is Pro subscriber")
        } else {
            isProSubscriber = false
            subscriptionStatus = .notSubscribed
            print("❌ No active subscription found")
        }
        
        // METHOD 2: Also check subscription status (for production, provides more details)
        // This will give us grace period, billing issues, etc.
        for productID in productIDs {
            if let statuses = try? await Product.SubscriptionInfo.status(for: productID) {
                for status in statuses {
                    print("📊 Subscription status for \(productID):")
                    print("   - State: \(status.state)")
                    
                    switch status.state {
                    case .subscribed, .inGracePeriod:
                        // Double-check with verification
                        if case .verified(let transaction) = status.transaction {
                            isProSubscriber = true
                            if status.state == .inGracePeriod {
                                subscriptionStatus = .inGracePeriod
                                print("⚠️ Subscription in grace period")
                            } else {
                                if let renewalInfo = try? status.renewalInfo.payloadValue {
                                    subscriptionStatus = .subscribed(
                                        productID: transaction.productID,
                                        expirationDate: renewalInfo.renewalDate
                                    )
                                }
                                print("✅ Active subscription via SubscriptionInfo")
                            }
                        }
                    case .expired, .revoked:
                        print("❌ Subscription \(status.state)")
                    default:
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Listen for transaction updates
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try await self.checkVerifiedTransaction(result)
                    
                    // Update subscription status on the main actor
                    await MainActor.run {
                        Task {
                            await self.updateSubscriptionStatus()
                        }
                    }
                    
                    // Finish the transaction
                    await transaction.finish()
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    
    private func checkVerifiedTransaction(_ result: VerificationResult<StoreKit.Transaction>) async throws -> StoreKit.Transaction {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw error
        }
    }
    
    // MARK: - Formatted Pricing
    
    func formattedPrice(for product: Product) -> String {
        return product.displayPrice
    }
    
    func savingsText(for product: Product) -> String? {
        // Calculate savings for yearly subscription
        if product.id == yearlyProductID,
           let monthlyProduct = availableProducts.first(where: { $0.id == monthlyProductID }) {
            
            let yearlyPrice = product.price
            let monthlyPrice = monthlyProduct.price * 12
            
            if monthlyPrice > yearlyPrice {
                let savings = monthlyPrice - yearlyPrice
                let percentSavings = (Double(truncating: savings as NSDecimalNumber) / Double(truncating: monthlyPrice as NSDecimalNumber)) * 100
                return "Save \(Int(percentSavings))%"
            }
        }
        
        return nil
    }
}

// MARK: - Subscription Info for Display

extension SubscriptionManager {
    var subscriptionDisplayText: String {
        switch subscriptionStatus {
        case .notSubscribed:
            return "Free Plan"
        case .subscribed(let productID, let expirationDate):
            let planName = productID.contains("monthly") ? "Pro (Monthly)" : "Pro (Annual)"
            if let expiration = expirationDate {
                return "\(planName) • Renews \(expiration.formatted(date: .abbreviated, time: .omitted))"
            }
            return planName
        case .expired:
            return "Subscription Expired"
        case .inGracePeriod:
            return "Pro (Grace Period)"
        }
    }
    
    var canAccessProFeatures: Bool {
        return isProSubscriber
    }
}
