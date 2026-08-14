import Foundation

/// Configuration for `EntitlementService`. Supplied by the host app, once, before `bootstrap()`.
///
/// The base library knows nothing about any specific app — no bundled product IDs,
/// no assumption that the app sells subscriptions at all. Everything app-specific
/// arrives through this struct.
///
/// ```swift
/// EntitlementService.shared.configure(
///     EntitlementConfig(productIDs: ["your.weekly", "your.yearly"],
///                       subscriptionGroupID: "your_group")
/// )
/// ```
@available(iOS 15.0, *)
public struct EntitlementConfig {

    /// The set of products that grant entitlement. **Required — there is no default.**
    ///
    /// There is deliberately no "empty means accept everything" branch. `Transaction.currentEntitlements`
    /// still emits unfinished consumables and expired non-renewing purchases, so accepting
    /// everything would let a coin pack grant permanent premium access.
    public let productIDs: Set<String>

    /// Scopes the intro-offer eligibility question to a single subscription group.
    ///
    /// `nil` means every subscription in the loaded catalog is a candidate. Set this
    /// when the app ships more than one subscription group, otherwise eligibility may
    /// be answered for a group the user is not looking at.
    public let subscriptionGroupID: String?

    /// - Parameters:
    ///   - productIDs: Products that grant entitlement. Must not be empty.
    ///   - subscriptionGroupID: Optional group to scope intro-offer eligibility to.
    public init(productIDs: Set<String>, subscriptionGroupID: String? = nil) {
        #if DEBUG
        if productIDs.isEmpty {
            assertionFailure("⚠️ [EntitlementConfig] productIDs is empty. An empty set grants nothing; it is never a way to accept every product.")
        }
        #endif
        self.productIDs = productIDs
        self.subscriptionGroupID = subscriptionGroupID
    }
}
