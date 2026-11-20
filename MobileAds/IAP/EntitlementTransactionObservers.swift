import Foundation
import StoreKit

/// Receives the transactions `EntitlementService` handles, without owning any of them.
///
/// Used by the optional attribution subspecs (`MobileAds/AppsFlyer`, `MobileAds/Qonversion`):
/// each registers itself when the host configures it, so the host never has to forward
/// purchases by hand, and the Core subspec carries no dependency on either SDK.
///
/// Observers are notified after `EntitlementService` has finished its own work, on a
/// detached task, so a slow observer can never delay a purchase result or a renewal.
@available(iOS 15.0, *)
@MainActor
protocol EntitlementTransactionObserver: AnyObject {
    /// A purchase the user made in the app through `EntitlementService.purchase(_:)`.
    func entitlementService(didPurchase transaction: Transaction, product: Product) async
    /// A transaction delivered out of band through `Transaction.updates`:
    /// renewals, Ask to Buy approvals, purchases on another device, refunds.
    func entitlementService(didReceiveUpdate transaction: Transaction) async
    /// `restore()` found at least one active purchase.
    func entitlementServiceDidRestore() async
}

@available(iOS 15.0, *)
extension EntitlementTransactionObserver {
    func entitlementService(didPurchase transaction: Transaction, product: Product) async {}
    func entitlementService(didReceiveUpdate transaction: Transaction) async {}
    func entitlementServiceDidRestore() async {}
}

@available(iOS 15.0, *)
@MainActor
enum EntitlementTransactionObservers {

    private static var observers: [EntitlementTransactionObserver] = []

    /// Idempotent: registering the same instance twice keeps one entry.
    static func add(_ observer: EntitlementTransactionObserver) {
        guard !observers.contains(where: { $0 === observer }) else { return }
        observers.append(observer)
    }

    static func notify(_ event: @escaping @MainActor (EntitlementTransactionObserver) async -> Void) {
        let current = observers
        guard !current.isEmpty else { return }
        Task { @MainActor in
            for observer in current {
                await event(observer)
            }
        }
    }
}
