//
//  IAPService+Receipt.swift
//  MobileAds
//
//  Created by MobileAds Framework
//

import Foundation
import StoreKit

@available(iOS 15.0, *)
extension IAPService {
    
    // MARK: - Receipt Validation
    
    /// Get receipt data từ app bundle
    /// - Returns: Receipt data nếu có
    func getReceiptData() -> Data? {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            print("⚠️ Receipt not found")
            return nil
        }
        
        do {
            let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
            return receiptData
        } catch {
            print("❌ Failed to read receipt: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Validate receipt với Apple server
    /// Sử dụng verifyReceipt endpoint (legacy)
    /// - Returns: ReceiptValidationResponse
    public func validateReceiptWithApple() async throws -> ReceiptValidationResponse {
        guard let receiptData = getReceiptData() else {
            throw IAPError.receiptNotFound
        }
        
        // Try production first, then sandbox if failed
        do {
            return try await validateWithVerifyReceipt(receiptData, useSandbox: false)
        } catch let error as IAPError {
            if case .validationFailed(let statusCode) = error, statusCode == 21007 {
                // Status 21007 means the receipt is from sandbox, try sandbox endpoint
                print("⚠️ Receipt is from sandbox, retrying with sandbox endpoint")
                return try await validateWithVerifyReceipt(receiptData, useSandbox: true)
            }
            throw error
        }
    }
    
    /// Validate receipt với verifyReceipt endpoint
    /// - Parameters:
    ///   - receiptData: Receipt data
    ///   - useSandbox: true để dùng sandbox endpoint
    /// - Returns: ReceiptValidationResponse
    private func validateWithVerifyReceipt(_ receiptData: Data, useSandbox: Bool) async throws -> ReceiptValidationResponse {
        // Endpoint URL
        let urlString = useSandbox
            ? "https://sandbox.itunes.apple.com/verifyReceipt"
            : "https://buy.itunes.apple.com/verifyReceipt"
        
        guard let url = URL(string: urlString) else {
            throw IAPError.unknown(NSError(domain: "IAPService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
        }
        
        // Prepare request body
        let receiptString = receiptData.base64EncodedString()
        var requestBody: [String: Any] = [
            "receipt-data": receiptString
        ]
        
        // Add shared secret if available (cho auto-renewable subscriptions)
        if let sharedSecret = sharedSecret {
            requestBody["password"] = sharedSecret
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw IAPError.unknown(error)
        }
        
        // Send request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                throw IAPError.networkError(NSError(
                    domain: "IAPService",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"]
                ))
            }
            
            // Parse response
            let validationResponse = try JSONDecoder().decode(ReceiptValidationResponse.self, from: data)
            
            // Check status code
            if validationResponse.status == 0 {
                print("✅ Receipt validation successful")
                
                // Update subscription status from receipt
                await updateSubscriptionStatusFromReceipt(validationResponse)
                
                return validationResponse
            } else {
                print("❌ Receipt validation failed with status: \(validationResponse.status)")
                throw IAPError.validationFailed(validationResponse.status)
            }
            
        } catch let error as IAPError {
            throw error
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw IAPError.networkError(error)
        }
    }
    
    /// Update subscription status từ receipt validation response
    /// - Parameter response: ReceiptValidationResponse
    private func updateSubscriptionStatusFromReceipt(_ response: ReceiptValidationResponse) async {
        guard let latestReceiptInfo = response.latestReceiptInfo else {
            print("⚠️ No latest receipt info found")
            return
        }
        
        // Process each receipt item
        for receiptItem in latestReceiptInfo {
            let productID = receiptItem.productId
            
            // Determine status
            var status: SubscriptionStatus = .active
            if let expiryDate = receiptItem.expiryDate {
                if Date() >= expiryDate {
                    status = .expired
                }
            }
            
            // Check cancellation
            if receiptItem.cancellationDateMs != nil {
                status = .revoked
            }
            
            // Check auto-renew status
            var isAutoRenewEnabled = false
            if let pendingRenewalInfo = response.pendingRenewalInfo {
                if let renewalInfo = pendingRenewalInfo.first(where: { $0.productId == productID }) {
                    isAutoRenewEnabled = renewalInfo.autoRenewStatus == "1"
                }
            }
            
            // Create subscription info
            let subscriptionInfo = SubscriptionInfo(
                productID: productID,
                status: status,
                expiryDate: receiptItem.expiryDate,
                purchaseDate: receiptItem.purchaseDate ?? Date(),
                originalTransactionID: receiptItem.originalTransactionId,
                isAutoRenewEnabled: isAutoRenewEnabled,
                lastUpdateDate: Date()
            )
            
            // Save to Keychain
            keychainStorage.saveSubscriptionInfo(subscriptionInfo, for: productID)
            
            print("✅ Updated subscription from receipt for \(productID): \(status.rawValue)")
        }
    }
}

