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
            
            // Sort: monthly first, then yearly
            self.availableProducts = products.sorted { product1, product2 in
                if product1.id == monthlyProductID { return true }
                if product2.id == monthlyProductID { return false }
                return product1.id < product2.id
            }
            
            print("✅ Loaded \(products.count) subscription products")
        } catch {
            print("❌ Failed to load products: \(error)")
            errorMessage = "Unable to load subscription options. Please try again."
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            // Attempt the purchase
            let result = try await product.purchase()
            
            switch result {
            case .success(let verificationResult):
                // Check verification
                switch verificationResult {
                case .verified(let transaction):
                    // Transaction is verified, finish it
                    await transaction.finish()
                    
                    // Update subscription status
                    await updateSubscriptionStatus()
                    
                    print("✅ Purchase successful: \(product.displayName)")
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
            print("❌ Purchase failed: \(error)")
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
        // Check for active subscriptions
        var activeSubscription: Product.SubscriptionInfo.Status?
        
        for productID in productIDs {
            // Get the subscription status for this product
            if let statuses = try? await Product.SubscriptionInfo.status(for: productID),
               let status = statuses.first {
                
                // Check if this subscription is active
                switch status.state {
                case .subscribed, .inGracePeriod:
                    activeSubscription = status
                    break
                default:
                    continue
                }
            }
        }
        
        // Update published properties
        if let subscription = activeSubscription {
            // Verify the transaction and renewal info
            guard case .verified(let transaction) = subscription.transaction,
                  case .verified(let renewalInfo) = subscription.renewalInfo else {
                isProSubscriber = false
                subscriptionStatus = .notSubscribed
                print("⚠️ Could not verify subscription transaction")
                return
            }
            
            switch subscription.state {
            case .subscribed:
                isProSubscriber = true
                
                // RenewalInfo uses renewalDate for the next renewal
                // For expiration, we can use renewalInfo.renewalDate or leave it nil for auto-renewing
                subscriptionStatus = .subscribed(
                    productID: transaction.productID,
                    expirationDate: renewalInfo.renewalDate
                )
                
                print("✅ Active subscription: \(transaction.productID)")
                
            case .inGracePeriod:
                isProSubscriber = true
                subscriptionStatus = .inGracePeriod
                print("⚠️ Subscription in grace period")
                
            case .expired:
                isProSubscriber = false
                subscriptionStatus = .expired
                print("ℹ️ Subscription expired")
                
            default:
                isProSubscriber = false
                subscriptionStatus = .notSubscribed
                print("ℹ️ No active subscription")
            }
        } else {
            isProSubscriber = false
            subscriptionStatus = .notSubscribed
            print("ℹ️ No active subscription found")
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
