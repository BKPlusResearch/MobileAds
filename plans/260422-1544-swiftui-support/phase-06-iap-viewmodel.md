# Phase 6: IAPViewModel SwiftUI

<!-- Updated: Validation Session 1 - Added per validation Q2 decision -->

**Priority:** P2
**Status:** Pending
**Effort:** 30min
**Depends on:** None (independent of ad phases)

## Overview

Tạo `ObservableObject` wrapper cho `IAPService` để SwiftUI host apps có thể reactive observe purchase state. Thin wrapper — delegate tất cả logic cho `IAPService.shared`.

## Key Insights

- `IAPService` đã `@MainActor` → safe để gọi từ SwiftUI
- `IAPService` đã iOS 15+ → khớp với SwiftUI minimum target
- Host app cần reactive `isPurchased` để control ad visibility (e.g. `isEnabled: !vm.isPurchased`)
- `hasActiveSubscription()` là API chính — check tất cả product IDs

## Related Code Files

### Tạo mới
- `MobileAds/SwiftUI/IAPViewModel.swift`

### Tham chiếu (không sửa)
- [IAPService.swift](file:///Users/shjn/work_space/BKPlus/MobileAds/MobileAds/IAP/IAPService.swift) — singleton, purchase/restore
- [IAPService+Subscription.swift](file:///Users/shjn/work_space/BKPlus/MobileAds/MobileAds/IAP/IAPService+Subscription.swift) — `hasActiveSubscription()`
- [IAPModels.swift](file:///Users/shjn/work_space/BKPlus/MobileAds/MobileAds/IAP/IAPModels.swift) — PurchaseResult, IAPError

## Implementation

### `MobileAds/SwiftUI/IAPViewModel.swift`

```swift
import SwiftUI
import StoreKit

/// Thin ObservableObject wrapper cho IAPService.
/// Provide reactive `isPurchased` state cho SwiftUI views.
///
/// Usage:
/// ```swift
/// @StateObject var iapVM = IAPViewModel()
///
/// ContentView()
///     .appOpenAd(adUnitID: .appOpen, isEnabled: !iapVM.isPurchased)
///     .task { await iapVM.refreshStatus() }
/// ```
@available(iOS 15.0, *)
@MainActor
public class IAPViewModel: ObservableObject {

    // MARK: - Published

    /// True nếu user có active subscription/purchase
    @Published public private(set) var isPurchased: Bool = false

    /// True khi đang purchase hoặc restore
    @Published public private(set) var isLoading: Bool = false

    /// Products đã fetch từ App Store
    @Published public private(set) var products: [Product] = []

    /// Error message (nếu có)
    @Published public private(set) var errorMessage: String?

    // MARK: - Init

    public init() {
        isPurchased = IAPService.shared.hasActiveSubscription()
    }

    // MARK: - Public Methods

    /// Fetch products từ App Store
    public func fetchProducts(_ productIDs: [IAPProductIdentifiable]) async {
        do {
            products = try await IAPService.shared.fetchProducts(productIDs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Purchase product
    public func purchase(_ productID: IAPProductIdentifiable) async -> PurchaseResult? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await IAPService.shared.purchase(productID)
            isPurchased = IAPService.shared.hasActiveSubscription()
            return result
        } catch {
            if let iapError = error as? IAPError, iapError == .purchaseCancelled {
                // User cancelled — not an error
            } else {
                errorMessage = error.localizedDescription
            }
            return nil
        }
    }

    /// Restore purchases
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

    /// Refresh subscription status (không fetch từ App Store, chỉ check local)
    public func refreshStatus() {
        isPurchased = IAPService.shared.hasActiveSubscription()
    }
}
```

## Usage Example

```swift
@main
struct MyApp: App {
    @StateObject var iapVM = IAPViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(iapVM)
                .appOpenAd(
                    adUnitID: AppAdUnit.appOpen,
                    isEnabled: !iapVM.isPurchased
                )
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var iapVM: IAPViewModel

    var body: some View {
        Button(iapVM.isPurchased ? "Subscribed ✓" : "Subscribe") {
            Task { await iapVM.purchase(AppProduct.premium) }
        }
        .disabled(iapVM.isLoading || iapVM.isPurchased)
    }
}
```

## Todo List

- [ ] Tạo `MobileAds/SwiftUI/IAPViewModel.swift`
- [ ] Build verify

## Success Criteria

- `isPurchased` reactive — update sau purchase/restore
- `isLoading` hiển thị loading state
- `errorMessage` capture failures (không crash)
- Backward compatible — không sửa IAPService
