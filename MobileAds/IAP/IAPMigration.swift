//
//  IAPMigration.swift
//  MobileAds
//

import Foundation

/// Migration helper: chuyển dữ liệu IAP từ Keychain sang UserDefaults
/// Chạy một lần duy nhất khi app update
class IAPMigration {

    private static let migrationFlagKey = "iap.migration.v1.done"

    /// Migrate subscription data từ Keychain sang UserDefaults nếu chưa migrate
    static func migrateFromKeychainIfNeeded(
        keychain: IAPKeychainStorage,
        userDefaults: IAPUserDefaultsStorage
    ) {
        guard !UserDefaults.standard.bool(forKey: migrationFlagKey) else {
            return
        }

        let productIDs = keychain.getAllProductIDs()
        var migratedCount = 0

        for productID in productIDs {
            guard let info = keychain.getSubscriptionInfo(for: productID) else { continue }
            userDefaults.saveSubscriptionInfo(info, for: productID)
            migratedCount += 1
        }

        keychain.clearAllSubscriptionInfo()
        UserDefaults.standard.set(true, forKey: migrationFlagKey)

        print("✅ IAPMigration: Migrated \(migratedCount) entries from Keychain to UserDefaults")
    }
}
