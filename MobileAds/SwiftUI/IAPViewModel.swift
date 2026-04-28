import SwiftUI
import StoreKit

/// Thin `ObservableObject` wrapper for `IAPService`.
/// Provides reactive `isPurchased` state for SwiftUI views.
///
/// Usage:
/// ```swift
/// @StateObject var iapVM = IAPViewModel()
///
/// ContentView()
///     .appOpenAd(adUnitID: .appOpen, isEnabled: !iapVM.isPurchased)
///     .task { iapVM.refreshStatus() }
/// ```
@available(iOS 15.0, *)
@MainActor
public class IAPViewModel: ObservableObject {

    // MARK: - Published

    /// True if user has an active subscription/purchase
    @Published public private(set) var isPurchased: Bool = false

    /// True while a purchase or restore operation is in progress
    @Published public private(set) var isLoading: Bool = false

    /// Products fetched from App Store
    @Published public private(set) var products: [Product] = []

    /// Error message from the last failed operation (nil if none)
    @Published public private(set) var errorMessage: String?

    // MARK: - Init

    public init() {
        isPurchased = IAPService.shared.hasActiveSubscription()
    }

    // MARK: - Public Methods

    /// Fetch products from App Store.
    public func fetchProducts(_ productIDs: [IAPProductIdentifiable]) async {
        do {
            products = try await IAPService.shared.fetchProducts(productIDs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Purchase a product.
    public func purchase(_ productID: IAPProductIdentifiable) async -> PurchaseResult? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await IAPService.shared.purchase(productID)
            isPurchased = IAPService.shared.hasActiveSubscription()
            return result
        } catch {
            if case .purchaseCancelled = error as? IAPError {
                // User cancelled — not an error
            } else {
                errorMessage = error.localizedDescription
            }
            return nil
        }
    }

    /// Restore purchases.
    public func restore() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await IAPService.shared.restorePurchases()
            isPurchased = IAPService.shared.hasActiveSubscription()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Refresh subscription status from local storage (no App Store fetch).
    public func refreshStatus() {
        isPurchased = IAPService.shared.hasActiveSubscription()
    }
}
