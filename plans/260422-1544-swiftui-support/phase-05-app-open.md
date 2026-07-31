# Phase 5: App Open Ad Modifier

**Priority:** P2
**Status:** Pending
**Effort:** 45min
**Depends on:** Phase 1

## Overview

Tạo ViewModifier cho App Open Ad. Khác biệt với fullscreen ad khác:
- Tự động trigger khi app từ background → foreground
- Quản lý lifecycle phức tạp hơn (expiry, skip logic)
- `showAppOpenAd(from: nil)` đã hoạt động — không cần VC

## Key Insights (từ review)

- `showAppOpenAd(from: nil)` OK — GMA SDK tự tìm presenting VC
- Host app chịu trách nhiệm check `isPurchased` → cần `isEnabled` binding
- Nhiều guard conditions đã built-in trong `showAppOpenAd()`:
  - `isAppOpenShowing`, `isInterstitialShowing`, `isRewardedShowing`, `isRewardedInterstitialShowing`
  - `isAppOpenAdAvailable()` (4h expiry)
- **KHÔNG cần** invisible VC bridge cho App Open — khác với Interstitial/Rewarded

## Related Code Files

### Tạo mới
- `MobileAds/SwiftUI/AppOpenModifier.swift`

### Tham chiếu (không sửa)
- [AdMobHelper+AppOpen.swift](file:///Users/shjn/work_space/BKPlus/MobileAds/MobileAds/AdMobHelper/AdMobHelper+AppOpen.swift)

## Implementation Steps

### 1. Tạo `MobileAds/SwiftUI/AppOpenModifier.swift`

```swift
import SwiftUI

@available(iOS 15.0, *)
public struct AppOpenModifier: ViewModifier {
    let adUnitID: AdUnitIdentifiable
    let isEnabled: Bool
    var onStatusChange: ((AppOpenAdStatus) -> Void)?

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasPreloaded = false

    public func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { newPhase in
                guard isEnabled else { return }
                guard AdMobHelper.shared.checkEnableShowAds() else { return }

                switch newPhase {
                case .active:
                    if hasPreloaded {
                        // App returned from background → show ad
                        AdMobHelper.shared.showAppOpenAd(
                            statusCallback: onStatusChange
                        )
                    } else {
                        // First launch → preload
                        hasPreloaded = true
                        Task {
                            try? await AdMobHelper.shared.loadAppOpenAd(
                                adUnitID: adUnitID,
                                shouldShowLoadingView: false
                            )
                        }
                    }
                case .background:
                    // Preload for next foreground
                    guard !AdMobHelper.shared.shouldSkipNextAppResume else { return }
                    Task {
                        try? await AdMobHelper.shared.loadAppOpenAd(
                            adUnitID: adUnitID,
                            shouldShowLoadingView: false
                        )
                    }
                default:
                    break
                }
            }
    }
}

@available(iOS 15.0, *)
public extension View {
    /// Attach app open ad behavior.
    /// - Parameters:
    ///   - adUnitID: Ad unit ID
    ///   - isEnabled: Control flag (e.g. `!isPurchased`)
    ///   - onStatusChange: Optional status callback
    func appOpenAd(
        adUnitID: AdUnitIdentifiable,
        isEnabled: Bool = true,
        onStatusChange: ((AppOpenAdStatus) -> Void)? = nil
    ) -> some View {
        modifier(AppOpenModifier(
            adUnitID: adUnitID,
            isEnabled: isEnabled,
            onStatusChange: onStatusChange
        ))
    }
}
```

### Usage Example

```swift
@main
struct MyApp: App {
    @StateObject var iapVM = IAPViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .appOpenAd(
                    adUnitID: AppAdUnit.appOpen,
                    isEnabled: !iapVM.isPurchased
                )
        }
    }
}
```

## Todo List

- [ ] Tạo `MobileAds/SwiftUI/AppOpenModifier.swift`
- [ ] Build verify

## Success Criteria

- App open ad hiển thị khi app foreground (sau lần đầu)
- Không hiển thị khi `isEnabled = false`
- Không hiển thị khi `shouldSkipNextAppResume = true`
- Preload đúng timing (background → ready cho next foreground)

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| `scenePhase` trigger quá nhanh | Load chưa xong đã show | `isAppOpenAdAvailable()` check built-in |
| Double show | UX xấu | `isAppOpenShowing` guard built-in |
| First launch show quá sớm | User annoyed | `hasPreloaded` flag — skip first `.active` |
