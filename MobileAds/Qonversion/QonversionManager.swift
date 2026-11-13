//
//  QonversionManager.swift
//  MobileAds — `MobileAds/Qonversion` subspec
//
//  Subscription analytics. Qonversion runs in `.analytics` mode: `EntitlementService`
//  stays the only owner of StoreKit transactions, Qonversion only observes them and
//  never finishes one. Present only when the host's Podfile includes the subspec.
//

import Foundation
import StoreKit
import Qonversion
#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif

@available(iOS 15.0, *)
@MainActor
public final class QonversionManager {

    public static let shared = QonversionManager()

    private var isConfigured = false

    private init() {}

    /// Call once from `application(_:didFinishLaunchingWithOptions:)`.
    ///
    /// When the `MobileAds/AppsFlyer` subspec is installed too, the AppsFlyer install ID is
    /// attached to the Qonversion user so its revenue can be matched to the install source.
    public func configure(projectKey: String) {
        guard !isConfigured else { return }
        isConfigured = true

        Qonversion.initWithConfig(Qonversion.Configuration(projectKey: projectKey, launchMode: .analytics))

        #if canImport(AppsFlyerLib)
        Qonversion.shared().setUserProperty(.appsFlyerUserID, value: AppsFlyerLib.shared().getAppsFlyerUID())
        #endif

        EntitlementTransactionObservers.add(self)
    }
}

// MARK: - Purchases

// Sends only the transaction that just happened. A full `syncStoreKit2Purchases()` is kept
// to restore, where purchases are known to exist: Qonversion reads the app receipt on every
// send, and with no receipt on the device (a fresh simulator or Xcode install) it requests a
// refresh that shows an Apple Account sign-in prompt.
@available(iOS 15.0, *)
extension QonversionManager: EntitlementTransactionObserver {

    func entitlementService(didPurchase transaction: Transaction, product: Product) async {
        await QonversionSwift.shared.handleTransaction(transaction)
    }

    func entitlementService(didReceiveUpdate transaction: Transaction) async {
        await QonversionSwift.shared.handleTransaction(transaction)
    }

    func entitlementServiceDidRestore() async {
        await QonversionSwift.shared.syncStoreKit2Transactions()
    }
}
