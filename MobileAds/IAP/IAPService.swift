//
//  IAPService.swift
//  MobileAds
//
//  Created by MobileAds Framework
//

import Foundation
import StoreKit

/// Main IAP Service để quản lý In-App Purchases
/// Sử dụng StoreKit 2 với async/await pattern
@available(iOS 15.0, *)
@MainActor
public class IAPService: NSObject {
    
    // MARK: - Singleton
    
    public static let shared = IAPService()
    
    // MARK: - Properties
    
    /// App Store Connect API Key (optional, cho App Store Server API)
    public var appStoreConnectAPIKey: String?
    
    /// Shared secret cho verifyReceipt endpoint (optional)
    public var sharedSecret: String?
    
    /// Cache của products đã fetch
    private var products: [String: Product] = [:]
    
    /// Keychain storage - chỉ dùng cho migration
    internal let keychainStorage = IAPKeychainStorage()

    /// UserDefaults storage để lưu subscription status
    internal let storage = IAPUserDefaultsStorage()

    /// Transaction update listener task
    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Initialization

    private override init() {
        super.init()
        // Migrate từ Keychain sang UserDefaults (chạy một lần)
        IAPMigration.migrateFromKeychainIfNeeded(keychain: keychainStorage, userDefaults: storage)
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Fetch products từ App Store
    /// - Parameter productIDs: Danh sách Product IDs cần fetch
    /// - Returns: Danh sách Product objects từ StoreKit
    public func fetchProducts(_ productIDs: [IAPProductIdentifiable]) async throws -> [Product] {
        let productIDStrings = productIDs.map { $0.productIDString }
        
        // Debug: Print requested product IDs
        print("🔍 Requesting products with IDs: \(productIDStrings)")
        
        do {
            let storeProducts = try await Product.products(for: productIDStrings)
            
            // Cache products
            for product in storeProducts {
                products[product.id] = product
                print("📦 Found product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
            }
            
            print("✅ Fetched \(storeProducts.count) products from App Store")
            return storeProducts
        } catch {
            print("❌ Failed to fetch products: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            throw IAPError.productNotFound
        }
    }
    
    /// Purchase một product
    /// - Parameter productID: Product ID cần mua
    /// - Returns: PurchaseResult với transaction info
    public func purchase(_ productID: IAPProductIdentifiable) async throws -> PurchaseResult {
        // Get product from cache hoặc fetch nếu chưa có
        let product: Product
        if let cachedProduct = products[productID.productIDString] {
            product = cachedProduct
        } else {
            let fetchedProducts = try await fetchProducts([productID])
            guard let fetchedProduct = fetchedProducts.first else {
                throw IAPError.productNotFound
            }
            product = fetchedProduct
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify transaction
                let transaction = try checkVerified(verification)
                
                // Update subscription status trong UserDefaults
                await updateSubscriptionStatus(from: transaction)
                
                // Finish the transaction
                await transaction.finish()
                
                // Get receipt data nếu cần validate với Apple
                let receiptData = getReceiptData()
                
                let purchaseResult = PurchaseResult(transaction: transaction, receiptData: receiptData)
                print("✅ Purchase successful: \(product.id)")
                
                return purchaseResult
                
            case .userCancelled:
                print("⚠️ User cancelled purchase")
                throw IAPError.purchaseCancelled
                
            case .pending:
                print("⚠️ Purchase is pending")
                throw IAPError.purchaseFailed("Purchase is pending approval")
                
            @unknown default:
                throw IAPError.unknown(NSError(domain: "IAPService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown purchase result"]))
            }
        } catch {
            print("❌ Purchase failed: \(error.localizedDescription)")
            if let iapError = error as? IAPError {
                throw iapError
            }
            throw IAPError.purchaseFailed(error.localizedDescription)
        }
    }
    
    /// Restore purchases
    /// - Returns: Danh sách PurchaseResult từ các transactions đã restore
    public func restorePurchases() async throws -> [PurchaseResult] {
        var restoredPurchases: [PurchaseResult] = []
        
        do {
            // Sync with App Store
            try await AppStore.sync()
            
            // Get all transactions
            for await result in Transaction.currentEntitlements {
                do {
                    let transaction = try checkVerified(result)
                    
                    // Update subscription status
                    await updateSubscriptionStatus(from: transaction)
                    
                    // Get receipt data
                    let receiptData = getReceiptData()
                    
                    let purchaseResult = PurchaseResult(transaction: transaction, receiptData: receiptData)
                    restoredPurchases.append(purchaseResult)
                    
                    print("✅ Restored: \(transaction.productID)")
                } catch {
                    print("⚠️ Failed to verify transaction: \(error.localizedDescription)")
                }
            }
            
            print("✅ Restored \(restoredPurchases.count) purchases")
            return restoredPurchases
            
        } catch {
            print("❌ Restore failed: \(error.localizedDescription)")
            throw IAPError.unknown(error)
        }
    }
    
    /// Check subscription status cho một product
    /// - Parameter productID: Product ID cần check
    /// - Returns: SubscriptionStatus
    public func checkSubscriptionStatus(for productID: IAPProductIdentifiable) -> SubscriptionStatus {
        if let info = storage.getSubscriptionInfo(for: productID.productIDString) {
            // Check if expired
            if let expiryDate = info.expiryDate, Date() >= expiryDate {
                return .expired
            }
            return info.status
        }
        
        return .unknown
    }
    
    /// Check xem subscription có active không
    /// - Parameter productID: Product ID cần check
    /// - Returns: true nếu subscription đang active
    public func isSubscriptionActive(for productID: IAPProductIdentifiable) -> Bool {
        guard let info = storage.getSubscriptionInfo(for: productID.productIDString) else {
            return false
        }
        return info.isActive
    }
    
    /// Clear all cached data (dùng khi logout)
    public func clearAllData() {
        products.removeAll()
        storage.clearAllSubscriptionInfo()
        print("✅ Cleared all IAP data")
    }
    
    // MARK: - Private Methods
    
    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Update subscription status
                    await self.updateSubscriptionStatus(from: transaction)
                    
                    // Finish the transaction
                    await transaction.finish()
                    
                    print("✅ Transaction updated: \(transaction.productID)")
                } catch {
                    print("⚠️ Transaction verification failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Verify transaction
    nonisolated internal func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw IAPError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    

}

