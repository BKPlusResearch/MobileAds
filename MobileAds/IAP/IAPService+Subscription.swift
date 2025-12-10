//
//  IAPService+Subscription.swift
//  MobileAds
//
//  Created by MobileAds Framework
//

import Foundation
import StoreKit

@available(iOS 15.0, *)
extension IAPService {
    
    // MARK: - Subscription Management
    
    /// Get subscription info từ Keychain
    /// - Parameter productID: Product ID
    /// - Returns: SubscriptionInfo nếu có
    func getSubscriptionInfo(for productID: String) -> SubscriptionInfo? {
        return keychainStorage.getSubscriptionInfo(for: productID)
    }
    
    /// Check xem user có bất kỳ subscription nào đang active không (bất kỳ ProductID nào)
    /// - Returns: true nếu có ít nhất 1 subscription đang active
    public func hasActiveSubscription() -> Bool {
        let allProductIDs = keychainStorage.getAllProductIDs()
        
        for productID in allProductIDs {
            if let info = keychainStorage.getSubscriptionInfo(for: productID) {
                // Check if status is active
                if info.status == .active {
                    // Check if not expired yet
                    if let expirationDate = info.expiryDate {
                        if expirationDate > Date() {
                            return true
                        }
                    } else {
                        // No expiration date means it's non-expiring (e.g. lifetime, non-consumable)
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    /// Update subscription status từ transaction
    /// - Parameter transaction: Transaction từ StoreKit
    func updateSubscriptionStatus(from transaction: Transaction) async {
        let productID = transaction.productID
        
        // Determine product type và status
        var status: SubscriptionStatus = .active
        var expiryDate: Date? = nil
        var isAutoRenewEnabled = false
        
        // Check if transaction has expiration date (subscription)
        if let expirationDate = transaction.expirationDate {
            expiryDate = expirationDate
            
            // Check if expired
            if Date() >= expirationDate {
                status = .expired
            }
        }
        
        // Check revocation date
        if let revocationDate = transaction.revocationDate {
            status = .revoked
            print("⚠️ Transaction revoked at: \(revocationDate)")
        }
        
        // For subscriptions, check auto-renew status
        if transaction.productType == .autoRenewable {
            // Check current entitlement status
            let currentEntitlement = await getCurrentEntitlement(for: productID)
            isAutoRenewEnabled = currentEntitlement != nil
        }
        
        // Create subscription info
        let subscriptionInfo = SubscriptionInfo(
            productID: productID,
            status: status,
            expiryDate: expiryDate,
            purchaseDate: transaction.purchaseDate,
            originalTransactionID: String(transaction.originalID),
            isAutoRenewEnabled: isAutoRenewEnabled,
            lastUpdateDate: Date()
        )
        
        // Save to Keychain
        keychainStorage.saveSubscriptionInfo(subscriptionInfo, for: productID)
        
        print("✅ Updated subscription status for \(productID): \(status.rawValue)")
    }
    
    /// Check xem subscription có expired không
    /// - Parameter productID: Product ID
    /// - Returns: true nếu expired
    func checkSubscriptionExpiry(for productID: String) -> Bool {
        guard let info = keychainStorage.getSubscriptionInfo(for: productID) else {
            return true // No subscription info = expired
        }
        
        // Check expiry date
        if let expiryDate = info.expiryDate {
            return Date() >= expiryDate
        }
        
        // No expiry date means it's either consumable, non-consumable, or non-renewable
        // For these, check status
        return info.status == .expired || info.status == .revoked
    }
    
    /// Get current entitlement cho một product
    /// - Parameter productID: Product ID
    /// - Returns: Transaction nếu có current entitlement
    private func getCurrentEntitlement(for productID: String) async -> Transaction? {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == productID {
                    return transaction
                }
            } catch {
                print("⚠️ Failed to verify entitlement: \(error.localizedDescription)")
            }
        }
        return nil
    }
    
    /// Refresh subscription status từ App Store
    /// - Parameter productID: Product ID cần refresh
    public func refreshSubscriptionStatus(for productID: IAPProductIdentifiable) async throws {
        // Get current entitlement
        if let transaction = await getCurrentEntitlement(for: productID.productIDString) {
            // Update status
            await updateSubscriptionStatus(from: transaction)
            print("✅ Refreshed subscription status for \(productID.productIDString)")
        } else {
            // No current entitlement, mark as expired
            if var info = keychainStorage.getSubscriptionInfo(for: productID.productIDString) {
                info.status = .expired
                info.lastUpdateDate = Date()
                keychainStorage.saveSubscriptionInfo(info, for: productID.productIDString)
                print("⚠️ No current entitlement found, marked as expired")
            }
        }
    }
    
    /// Get all active subscriptions
    /// - Returns: Danh sách SubscriptionInfo đang active
    public func getAllActiveSubscriptions() async -> [SubscriptionInfo] {
        var activeSubscriptions: [SubscriptionInfo] = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if let info = keychainStorage.getSubscriptionInfo(for: transaction.productID),
                   info.isActive {
                    activeSubscriptions.append(info)
                }
            } catch {
                print("⚠️ Failed to verify entitlement: \(error.localizedDescription)")
            }
        }
        
        return activeSubscriptions
    }
}

