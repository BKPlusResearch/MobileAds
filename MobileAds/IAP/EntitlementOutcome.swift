import Foundation
import StoreKit

/// Why an entitlement operation failed.
///
/// The host needs the *kind* of failure to decide what to do; it does not need the
/// system's English sentence. Raw `localizedDescription` text is confined to
/// `.unknown`, which exists for logging rather than for display.
@available(iOS 15.0, *)
public enum EntitlementFailure: Equatable {
    case network
    case cancelled
    /// Parental controls, or payments disallowed on this device/account.
    case notAllowed
    case productUnavailable
    case verificationFailed
    /// System-supplied description. Log it; do not show it to users.
    case unknown(String)
}

/// Proof that one specific transaction happened.
///
/// Carried out of the library so a host selling **consumables** can credit the purchase
/// and record what it credited. `transactionID` is the de-duplication key: StoreKit may
/// deliver the same transaction more than once (relaunch, Ask to Buy approval, an
/// interrupted delivery), and crediting per delivery instead of per ID double-credits.
///
/// The library keeps no copy of this. Persisting it is the host's job.
@available(iOS 15.0, *)
public struct EntitlementPurchaseReceipt: Equatable, Sendable {
    /// Stable per transaction, and the only safe key for "have I already credited this?".
    public let transactionID: String
    public let productID: String
    public let purchaseDate: Date
    /// What kind of product this was. Carried so the host never has to infer it from the
    /// shape of a product ID — a naming convention is not evidence of a product's type,
    /// and guessing wrong here means crediting the wrong thing.
    public let productType: Product.ProductType
    /// Offer the transaction was bought under. `.freeTrial` and `.introDiscount` are
    /// introductory offers only; a free offer code or free promotional offer is
    /// `.promotional`. `.none` means a regular-price purchase, but also appears when the
    /// receipt came from a path without a `Product` (listener / background delivery), where
    /// it must not be read as "no offer".
    public let offerKind: EntitlementOfferKind
    /// Amount charged (0 for an introductory free trial; the store price for promo, offer
    /// code and win-back). `nil` means unknown: the receipt came from a path without a
    /// `Product` (listener / background delivery), not "regular price".
    public let chargedPrice: Decimal?
    /// ISO currency code of `chargedPrice`. `nil` under the same condition.
    public let currencyCode: String?

    /// `true` when the purchase started an introductory free trial. A free offer code or
    /// free promotional offer is `.promotional` and is not flagged.
    public var isFreeTrial: Bool { offerKind == .freeTrial }

    public init(transactionID: String,
                productID: String,
                purchaseDate: Date,
                productType: Product.ProductType,
                offerKind: EntitlementOfferKind = .none,
                chargedPrice: Decimal? = nil,
                currencyCode: String? = nil) {
        self.transactionID = transactionID
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.productType = productType
        self.offerKind = offerKind
        self.chargedPrice = chargedPrice
        self.currencyCode = currencyCode
    }
}

/// Result of a single purchase attempt.
///
/// This describes *that one purchase*, never the global entitlement state — a
/// consumable purchase succeeds without ever appearing in `currentEntitlements`.
@available(iOS 15.0, *)
public enum EntitlementPurchaseOutcome: Equatable {
    /// Carries the receipt so a consumable seller can credit *this* purchase. A
    /// subscription/non-consumable host may ignore the payload and re-derive
    /// entitlement from `isEntitled` as before.
    case purchased(EntitlementPurchaseReceipt)
    case cancelled
    /// Ask to Buy and other deferred approvals. Resolved later through the
    /// `Transaction.updates` listener — the host should dismiss the paywall and say
    /// "waiting for approval", **not** report an error.
    case pending
    case failed(EntitlementFailure)
}

/// Result of a restore attempt.
@available(iOS 15.0, *)
public enum EntitlementRestoreOutcome: Equatable {
    case restored
    case nothingToRestore
    /// The user dismissed the App Store sign-in sheet. Normal behavior, **not** an error —
    /// do not show an alert for this.
    case cancelled
    case failed(EntitlementFailure)
}

/// Whether StoreKit has answered yet.
///
/// Three states, deliberately not a `Bool`. A timeout must never stamp "verified" onto
/// a value that was never checked; the host has to be able to tell "don't know yet"
/// apart from "gave up waiting" and pick its own policy for each.
@available(iOS 15.0, *)
public enum EntitlementVerification: Equatable {
    /// No answer yet. Unlock nothing.
    case pending
    /// `currentEntitlements` was read to completion. `isEntitled` is now meaningful.
    case verified
    /// StoreKit did not answer within the timeout. `isEntitled` is still `false` and
    /// still unverified — the host decides the policy. See the README for the
    /// recommended default (treat as free, show ads).
    case timedOut
}
