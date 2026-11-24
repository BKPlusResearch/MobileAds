import Foundation
import StoreKit

/// Which kind of offer a transaction was bought under.
///
/// Raw values are stable analytics strings; hosts may log them as-is.
@available(iOS 15.0, *)
public enum EntitlementOfferKind: String, Sendable, Equatable {
    /// Introductory offer with payment mode "free trial": nothing was charged.
    /// Introductory offers only: a free offer code or free promotional offer is `.promotional`.
    case freeTrial = "free_trial"
    /// Introductory offer that charges a reduced price (pay-as-you-go / pay-up-front).
    /// Introductory offers only; other discounted offers are `.promotional`.
    case introDiscount = "intro_discount"
    /// Any non-introductory offer: a promotional offer, an offer code, or a win-back.
    /// They share one bucket and are never reported as a free trial, even when the
    /// offer itself is free.
    case promotional = "promotional"
    /// Bought at the regular store price.
    case none = "none"
}

/// What a transaction actually cost, derived from the transaction and its `Product`.
///
/// Shared by every consumer that reports revenue (AppsFlyer, host analytics) so that
/// they cannot disagree about whether a free trial earned money.
@available(iOS 15.0, *)
public enum EntitlementPricing {

    /// Classifies the offer `transaction` was bought under.
    public static func offerKind(_ transaction: Transaction, product: Product) -> EntitlementOfferKind {
        if #available(iOS 17.2, *) {
            guard let offer = transaction.offer else { return .none }
            switch offer.type {
            case .introductory:
                return offer.paymentMode == .freeTrial ? .freeTrial : .introDiscount
            default:
                // promotional, code, win-back and any future type: all discounted offers.
                return .promotional
            }
        } else {
            switch transaction.offerType {
            case .introductory?:
                let mode = product.subscription?.introductoryOffer?.paymentMode
                return mode == .freeTrial ? .freeTrial : .introDiscount
            case nil:
                return .none
            default:
                return .promotional
            }
        }
    }

    /// The amount this transaction charged, in the product's currency:
    /// 0 for an introductory free trial, the intro price for a paid introductory offer,
    /// otherwise the store price. Offer codes, promotional offers and win-backs report the
    /// store price deliberately, to match what AppsFlyer reported before 2.2.2.
    /// Reporting the full price for an intro trial would book revenue never collected.
    public static func chargedPrice(_ transaction: Transaction, product: Product) -> Decimal {
        switch offerKind(transaction, product: product) {
        case .freeTrial:
            return 0
        case .introDiscount:
            // `price` is per period; for a pay-as-you-go offer the first charge equals it.
            return product.subscription?.introductoryOffer?.price ?? product.price
        case .promotional, .none:
            return product.price
        }
    }
}
