//
//  IAPUserDefaultsStorage.swift
//  MobileAds
//

import Foundation

/// UserDefaults-based storage để lưu/đọc subscription status
/// Thay thế IAPKeychainStorage
class IAPUserDefaultsStorage {

    // MARK: - Constants

    private let defaults = UserDefaults.standard
    private let idsKey = "iap.sub.ids"

    private func dataKey(for productID: String) -> String {
        return "iap.sub.\(productID)"
    }

    // MARK: - Public Methods

    /// Lưu subscription info vào UserDefaults
    func saveSubscriptionInfo(_ info: SubscriptionInfo, for productID: String) {
        do {
            let data = try JSONEncoder().encode(info)
            defaults.set(data, forKey: dataKey(for: productID))
            addProductID(productID)
        } catch {
            print("❌ IAPUserDefaultsStorage: Failed to save info for \(productID): \(error)")
        }
    }

    /// Đọc subscription info từ UserDefaults
    func getSubscriptionInfo(for productID: String) -> SubscriptionInfo? {
        guard let data = defaults.data(forKey: dataKey(for: productID)) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(SubscriptionInfo.self, from: data)
        } catch {
            print("❌ IAPUserDefaultsStorage: Failed to decode info for \(productID): \(error)")
            return nil
        }
    }

    /// Xóa subscription info của một product
    func clearSubscriptionInfo(for productID: String) {
        defaults.removeObject(forKey: dataKey(for: productID))
        removeProductID(productID)
    }

    /// Xóa tất cả subscription info
    func clearAllSubscriptionInfo() {
        for productID in getAllProductIDs() {
            defaults.removeObject(forKey: dataKey(for: productID))
        }
        defaults.removeObject(forKey: idsKey)
    }

    /// Lấy tất cả product IDs đã lưu
    func getAllProductIDs() -> [String] {
        return defaults.stringArray(forKey: idsKey) ?? []
    }

    // MARK: - Private Helpers

    private func addProductID(_ productID: String) {
        var ids = getAllProductIDs()
        if !ids.contains(productID) {
            ids.append(productID)
            defaults.set(ids, forKey: idsKey)
        }
    }

    private func removeProductID(_ productID: String) {
        var ids = getAllProductIDs()
        ids.removeAll { $0 == productID }
        defaults.set(ids, forKey: idsKey)
    }
}
