//
//  IAPKeychainStorage.swift
//  MobileAds
//
//  Created by MobileAds Framework
//

import Foundation
import Security

/// Helper class để lưu/đọc subscription status từ Keychain
/// Sử dụng native Security framework APIs
class IAPKeychainStorage {
    
    // MARK: - Constants
    
    private let serviceIdentifier = "com.bkplus.mobileads.iap"
    
    // MARK: - Public Methods
    
    /// Lưu subscription info vào Keychain
    /// - Parameters:
    ///   - info: SubscriptionInfo cần lưu
    ///   - productID: Product ID
    func saveSubscriptionInfo(_ info: SubscriptionInfo, for productID: String) {
        do {
            let data = try JSONEncoder().encode(info)
            let key = keychainKey(for: productID)
            
            // Try to update first
            if getSubscriptionInfo(for: productID) != nil {
                updateKeychainItem(data: data, forKey: key)
            } else {
                addKeychainItem(data: data, forKey: key)
            }
        } catch {
            print("Failed to save subscription info to Keychain: \(error.localizedDescription)")
        }
    }
    
    /// Đọc subscription info từ Keychain
    /// - Parameter productID: Product ID
    /// - Returns: SubscriptionInfo nếu có, nil nếu không tìm thấy
    func getSubscriptionInfo(for productID: String) -> SubscriptionInfo? {
        let key = keychainKey(for: productID)
        
        guard let data = readKeychainItem(forKey: key) else {
            return nil
        }
        
        do {
            let info = try JSONDecoder().decode(SubscriptionInfo.self, from: data)
            return info
        } catch {
            print("Failed to decode subscription info from Keychain: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Xóa subscription info khỏi Keychain
    /// - Parameter productID: Product ID
    func clearSubscriptionInfo(for productID: String) {
        let key = keychainKey(for: productID)
        deleteKeychainItem(forKey: key)
    }
    
    /// Xóa tất cả subscription info khỏi Keychain
    func clearAllSubscriptionInfo() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Failed to clear all subscription info from Keychain: \(status)")
        }
    }
    
    /// Lấy tất cả product IDs đã lưu trong Keychain
    /// - Returns: Array of product IDs
    func getAllProductIDs() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item in
            guard let account = item[kSecAttrAccount as String] as? String else {
                return nil
            }
            // Remove "subscription." prefix to get productID
            return account.replacingOccurrences(of: "subscription.", with: "")
        }
    }
    
    // MARK: - Private Methods
    
    /// Generate keychain key cho product ID
    private func keychainKey(for productID: String) -> String {
        return "subscription.\(productID)"
    }
    
    /// Add item vào Keychain
    private func addKeychainItem(data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to add item to Keychain: \(status)")
        }
    }
    
    /// Update item trong Keychain
    private func updateKeychainItem(data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status != errSecSuccess {
            print("Failed to update item in Keychain: \(status)")
        }
    }
    
    /// Đọc item từ Keychain
    private func readKeychainItem(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else if status != errSecItemNotFound {
            print("Failed to read item from Keychain: \(status)")
        }
        
        return nil
    }
    
    /// Xóa item khỏi Keychain
    private func deleteKeychainItem(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Failed to delete item from Keychain: \(status)")
        }
    }
}

