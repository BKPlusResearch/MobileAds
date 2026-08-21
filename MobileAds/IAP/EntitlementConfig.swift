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

    /// Every product this app may **buy** through `purchase()`. **Required — there is no default.**
    ///
    /// This is a *purchasable* set, not an *entitling* set — the two differ, and conflating
    /// them loses money. `purchase()` rejects any ID absent from here, so an app selling coin
    /// packs must list the coin SKUs too, or those purchases fail before reaching StoreKit.
    ///
    /// Granting is filtered separately and more strictly: `verify()` drops consumables by
    /// `Transaction.productType`, so listing a coin pack here does **not** let it grant
    /// premium. That `productType` check is the real protection — the naming convention of
    /// a product ID is not evidence of anything. A coin pack mis-registered as
    /// non-consumable in App Store Connect *would* grant permanent access.
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

    /// Delivers a **consumable** purchase. Called **before** the library finishes the
    /// transaction. Return `true` once the credit is recorded and the library finishes it;
    /// return `false` and it is **not** finished, so StoreKit redelivers it later.
    ///
    /// This is the *single* delivery point: every consumable the library sees is offered
    /// here exactly once, whether it came back from `purchase()` or arrived unprompted
    /// through `Transaction.updates`. Credit here and nowhere else.
    ///
    /// `nil` finishes immediately — correct for apps selling only subscriptions and
    /// non-consumables, whose entitlement is re-derivable from `currentEntitlements`.
    ///
    /// **An app selling consumables must supply this.** A consumable never enters
    /// `currentEntitlements`, so finishing one before crediting it destroys the only
    /// record that the purchase happened: the customer is charged and never credited.
    /// A foreground `purchase()` is not the only path — StoreKit also delivers consumables
    /// when the app was killed mid-purchase, when Ask to Buy is approved later, when the
    /// purchase began on another device, and when a prior delivery was interrupted.
    ///
    /// Contract for the host:
    /// - Persist the credit **before** returning `true`. Returning `true` first and writing
    ///   afterwards reintroduces exactly the loss this hook exists to prevent.
    /// - De-duplicate on `receipt.transactionID`; redelivery of an already-credited
    ///   transaction must return `true` without crediting twice.
    /// - Make the write atomic. A read-then-write across an `await`, or into an App Group
    ///   `UserDefaults` a widget also writes, loses concurrent credits.
    /// - Return `false` only when the credit genuinely could not be written. It is not an
    ///   error channel — a permanent `false` means permanent redelivery.
    ///
    /// Deliberately **not** called for:
    /// - **Non-consumables and subscriptions.** Their entitlement is re-derivable, so
    ///   there is nothing to lose by finishing them. Calling the hook for renewals would
    ///   invite a host to return `false` for a product it does not recognize, wedging that
    ///   renewal in permanent redelivery.
    /// - **Revoked or refunded transactions.** Delivering goods for a refund is a
    ///   giveaway. `refresh()` still runs, so the entitlement itself drops correctly.
    /// - **Transactions that fail verification.** Honoring them would grant goods against
    ///   unverifiable proof. That is a deliberate, known gap; closing it needs server-side
    ///   validation. A charged-but-unverifiable consumable is therefore still lost.
    ///
    /// Runs on the main actor, matching `EntitlementService`'s own isolation. It is
    /// awaited inside the `Transaction.updates` loop, so a hook that never returns stalls
    /// every later transaction — keep it bounded, and do not block it on user interaction.
    public let onUnfinished: (@MainActor @Sendable (EntitlementPurchaseReceipt) async -> Bool)?

    /// - Parameters:
    ///   - productIDs: Products this app may buy. Must not be empty. See the property docs —
    ///     this is the purchasable set, and it is wider than the entitling set.
    ///   - subscriptionGroupID: Optional group to scope intro-offer eligibility to.
    ///   - onUnfinished: Delivery hook for consumable purchases. Required for consumable
    ///     sellers; leave `nil` otherwise.
    public init(productIDs: Set<String>,
                subscriptionGroupID: String? = nil,
                onUnfinished: (@MainActor @Sendable (EntitlementPurchaseReceipt) async -> Bool)? = nil) {
        #if DEBUG
        if productIDs.isEmpty {
            assertionFailure("⚠️ [EntitlementConfig] productIDs is empty. An empty set grants nothing; it is never a way to accept every product.")
        }
        #endif
        self.productIDs = productIDs
        self.subscriptionGroupID = subscriptionGroupID
        self.onUnfinished = onUnfinished
    }
}
