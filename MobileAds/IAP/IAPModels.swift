//
//  IAPModels.swift
//  MobileAds
//
//  Created by MobileAds Framework
//

import Foundation
import StoreKit

// MARK: - Subscription Status

/// Trạng thái subscription của người dùng
public enum SubscriptionStatus: String, Codable {
    /// Subscription đang active
    case active
    /// Subscription đã hết hạn
    case expired
    /// Subscription trong grace period (vẫn có thể dùng nhưng có vấn đề với payment)
    case inGracePeriod
    /// Subscription bị revoked (thu hồi)
    case revoked
    /// Không xác định được trạng thái
    case unknown
}

// MARK: - Product Type

/// Loại sản phẩm IAP
public enum ProductType: String, Codable {
    /// Auto-renewable subscription (đăng ký tự động gia hạn)
    case autoRenewable
    /// Non-renewable subscription (đăng ký không tự động gia hạn)
    case nonRenewable
    /// Consumable product (sản phẩm tiêu dùng - mua nhiều lần)
    case consumable
    /// Non-consumable product (sản phẩm không tiêu dùng - mua 1 lần)
    case nonConsumable
}

// MARK: - Purchase Result

/// Kết quả sau khi purchase thành công
public struct PurchaseResult {
    /// Transaction ID từ Apple
    public let transactionID: String?
    /// Product ID đã mua
    public let productID: String
    /// Transaction date
    public let purchaseDate: Date
    /// Receipt data (nếu có)
    public let receiptData: Data?
    /// Transaction object từ StoreKit 2
    @available(iOS 15.0, *)
    public let transaction: Transaction?
    
    @available(iOS 15.0, *)
    public init(transaction: Transaction, receiptData: Data? = nil) {
        self.transactionID = String(transaction.id)
        self.productID = transaction.productID
        self.purchaseDate = transaction.purchaseDate
        self.receiptData = receiptData
        self.transaction = transaction
    }
    
    public init(transactionID: String?, productID: String, purchaseDate: Date, receiptData: Data?) {
        self.transactionID = transactionID
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.receiptData = receiptData
        self.transaction = nil
    }
}

// MARK: - Receipt Validation Response

/// Response từ Apple server khi validate receipt
public struct ReceiptValidationResponse: Codable {
    /// Status code từ Apple (0 = valid)
    public let status: Int
    /// Receipt info
    public let receipt: ReceiptInfo?
    /// Latest receipt info (cho subscriptions)
    public let latestReceiptInfo: [ReceiptItem]?
    /// Pending renewal info
    public let pendingRenewalInfo: [PendingRenewalInfo]?
    
    public init(status: Int, receipt: ReceiptInfo? = nil, latestReceiptInfo: [ReceiptItem]? = nil, pendingRenewalInfo: [PendingRenewalInfo]? = nil) {
        self.status = status
        self.receipt = receipt
        self.latestReceiptInfo = latestReceiptInfo
        self.pendingRenewalInfo = pendingRenewalInfo
    }
    
    enum CodingKeys: String, CodingKey {
        case status
        case receipt
        case latestReceiptInfo = "latest_receipt_info"
        case pendingRenewalInfo = "pending_renewal_info"
    }
}

/// Receipt info từ Apple
public struct ReceiptInfo: Codable {
    /// Bundle ID của app
    public let bundleId: String?
    /// In-app purchases trong receipt
    public let inApp: [ReceiptItem]?
    
    enum CodingKeys: String, CodingKey {
        case bundleId = "bundle_id"
        case inApp = "in_app"
    }
}

/// Receipt item (in-app purchase item)
public struct ReceiptItem: Codable {
    /// Product ID
    public let productId: String
    /// Transaction ID
    public let transactionId: String?
    /// Original transaction ID
    public let originalTransactionId: String?
    /// Purchase date (milliseconds since epoch)
    public let purchaseDateMs: String?
    /// Expiry date (milliseconds since epoch) - cho subscriptions
    public let expiresDateMs: String?
    /// Cancellation date (nếu bị cancel)
    public let cancellationDateMs: String?
    
    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case transactionId = "transaction_id"
        case originalTransactionId = "original_transaction_id"
        case purchaseDateMs = "purchase_date_ms"
        case expiresDateMs = "expires_date_ms"
        case cancellationDateMs = "cancellation_date_ms"
    }
    
    /// Expiry date as Date object
    public var expiryDate: Date? {
        guard let expiresDateMs = expiresDateMs,
              let timestamp = TimeInterval(expiresDateMs) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp / 1000.0)
    }
    
    /// Purchase date as Date object
    public var purchaseDate: Date? {
        guard let purchaseDateMs = purchaseDateMs,
              let timestamp = TimeInterval(purchaseDateMs) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp / 1000.0)
    }
}

/// Pending renewal info
public struct PendingRenewalInfo: Codable {
    /// Product ID
    public let productId: String
    /// Auto-renew status (1 = enabled, 0 = disabled)
    public let autoRenewStatus: String?
    
    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case autoRenewStatus = "auto_renew_status"
    }
}

// MARK: - Subscription Info

/// Thông tin subscription được lưu trong Keychain
public struct SubscriptionInfo: Codable {
    /// Product ID
    public let productID: String
    /// Trạng thái subscription
    public var status: SubscriptionStatus
    /// Ngày hết hạn (nếu có)
    public var expiryDate: Date?
    /// Ngày mua
    public var purchaseDate: Date
    /// Original transaction ID
    public var originalTransactionID: String?
    /// Có auto-renew không
    public var isAutoRenewEnabled: Bool
    /// Ngày update thông tin lần cuối
    public var lastUpdateDate: Date
    
    public init(
        productID: String,
        status: SubscriptionStatus,
        expiryDate: Date? = nil,
        purchaseDate: Date,
        originalTransactionID: String? = nil,
        isAutoRenewEnabled: Bool = false,
        lastUpdateDate: Date = Date()
    ) {
        self.productID = productID
        self.status = status
        self.expiryDate = expiryDate
        self.purchaseDate = purchaseDate
        self.originalTransactionID = originalTransactionID
        self.isAutoRenewEnabled = isAutoRenewEnabled
        self.lastUpdateDate = lastUpdateDate
    }
    
    /// Check xem subscription có còn active không (dựa vào expiry date)
    public var isActive: Bool {
        guard status == .active || status == .inGracePeriod else {
            return false
        }
        
        if let expiryDate = expiryDate {
            return Date() < expiryDate
        }
        
        // Nếu không có expiry date (non-renewable hoặc consumable), coi như active
        return status == .active
    }
}

// MARK: - IAP Error

/// Errors cho IAP Service
public enum IAPError: Error, LocalizedError {
    case productNotFound
    case purchaseCancelled
    case purchaseFailed(String)
    case verificationFailed
    case receiptNotFound
    case validationFailed(Int)
    case networkError(Error)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product không tìm thấy trên App Store"
        case .purchaseCancelled:
            return "Người dùng đã hủy purchase"
        case .purchaseFailed(let message):
            return "Purchase thất bại: \(message)"
        case .verificationFailed:
            return "Verification thất bại"
        case .receiptNotFound:
            return "Không tìm thấy receipt"
        case .validationFailed(let statusCode):
            return "Validation thất bại với status code: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Lỗi không xác định: \(error.localizedDescription)"
        }
    }
}

