# Phase 3: Fullscreen Ad Modifiers

**Priority:** P1
**Status:** Pending
**Effort:** 2h
**Depends on:** Phase 1

## Overview

Tạo ViewModifier cho 3 loại fullscreen ad: Interstitial, Rewarded, RewardedInterstitial.
Pattern: invisible `ViewControllerResolver` embed vào view → resolve VC → gọi AdMobHelper show.

## Key Insights (từ review)

- Interstitial: `showInterstitialAd(from:statusCallback:)` — **synchronous** `throws`
- Rewarded: `showRewardedAd(from:adUnitID:statusCallback:completion:)` — **async throws**
- RewardedInterstitial: `showRewardedInterstitialAd(from:adUnitID:completion:)` — **async throws**, **KHÔNG có statusCallback**
- Cần thêm `statusCallback` cho RewardedInterstitial TRƯỚC khi tạo modifier (sửa UIKit layer)
- Tất cả show methods cần `UIViewController`

## Related Code Files

### Tạo mới
- `MobileAds/SwiftUI/InterstitialModifier.swift`
- `MobileAds/SwiftUI/RewardedModifier.swift`
- `MobileAds/SwiftUI/RewardedInterstitialModifier.swift`

### Sửa (UIKit layer — prerequisite)
- [AdMobHelper+RewardedInterstitial.swift](file:///Users/shjn/work_space/BKPlus/MobileAds/MobileAds/AdMobHelper/AdMobHelper+RewardedInterstitial.swift) — thêm `statusCallback`
- [AdMobHelper+FullScreenDelegate.swift](file:///Users/shjn/work_space/BKPlus/MobileAds/MobileAds/AdMobHelper/AdMobHelper+FullScreenDelegate.swift) — handle RewardedInterstitial status events

### Tham chiếu (không sửa)
- [AdMobHelper+Interstitial.swift](file:///Users/shjn/work_space/BKPlus/MobileAds/MobileAds/AdMobHelper/AdMobHelper+Interstitial.swift)
- [AdMobHelper+Rewarded.swift](file:///Users/shjn/work_space/BKPlus/MobileAds/MobileAds/AdMobHelper/AdMobHelper+Rewarded.swift)

## Implementation Steps

### Step 0: Sửa UIKit Layer — Thêm statusCallback cho RewardedInterstitial

**File:** `AdMobHelper+RewardedInterstitial.swift`

Thêm property vào `AdMobHelper.swift`:
```swift
/// Callback for rewarded interstitial ad status events
var rewardedInterstitialAdStatusCallback: ((RewardedAdStatus) -> Void)?
```

Sửa `showRewardedInterstitialAd`:
```swift
public func showRewardedInterstitialAd(
    from viewController: UIViewController,
    adUnitID: AdUnitIdentifiable,
    statusCallback: ((RewardedAdStatus) -> Void)? = nil,  // ← THÊM
    completion: @escaping (AdReward) -> Void
) async throws {
    guard !isRewardedInterstitialShowing else {
        throw AdMobHelperError.adAlreadyShowing
    }

    // Store callback
    rewardedInterstitialAdStatusCallback = statusCallback

    if rewardedInterstitialAd == nil {
        try await loadRewardedInterstitialAd(adUnitID: adUnitID)
    }

    guard let rewardedInterstitialAd = rewardedInterstitialAd else {
        throw AdMobHelperError.adNotLoaded
    }

    shouldSkipNextAppResume = true
    isRewardedInterstitialShowing = true

    rewardedInterstitialAd.present(from: viewController) {
        let reward = rewardedInterstitialAd.adReward
        statusCallback?(.didEarnReward)
        completion(reward)
    }
}
```

**File:** `AdMobHelper+FullScreenDelegate.swift` — Cập nhật các delegate methods:

```swift
// Trong adWillPresentFullScreenContent:
} else if ad === rewardedInterstitialAd {
    rewardedInterstitialAdStatusCallback?(.didPresent)
}

// Trong adWillDismissFullScreenContent:
} else if ad === rewardedInterstitialAd {
    rewardedInterstitialAdStatusCallback?(.willDismiss)
}

// Trong adDidDismissFullScreenContent:
} else if ad === rewardedInterstitialAd {
    rewardedInterstitialAdStatusCallback?(.didDismiss)
    rewardedInterstitialAdStatusCallback = nil
    rewardedInterstitialAd = nil
    isRewardedInterstitialShowing = false
}

// Trong ad(_:didFailToPresentFullScreenContentWithError:):
} else if ad === rewardedInterstitialAd {
    rewardedInterstitialAdStatusCallback?(.didFailToPresent)
    rewardedInterstitialAdStatusCallback = nil
    rewardedInterstitialAd = nil
    isRewardedInterstitialShowing = false
}
```

Thêm vào `clearAllAds()`:
```swift
rewardedInterstitialAdStatusCallback = nil
```

---

### Step 1: `InterstitialModifier.swift`

```swift
import SwiftUI

@available(iOS 15.0, *)
public struct InterstitialModifier: ViewModifier {
    @Binding var isPresented: Bool
    let adUnitID: AdUnitIdentifiable
    var onStatusChange: ((InterstitialAdStatus) -> Void)?

    public func body(content: Content) -> some View {
        content
            .background(
                ViewControllerResolver { vc in
                    guard isPresented else { return }
                    Task { @MainActor in
                        do {
                            try await AdMobHelper.shared.loadInterstitialAd(adUnitID: adUnitID)
                            try AdMobHelper.shared.showInterstitialAd(
                                from: vc,
                                statusCallback: { status in
                                    onStatusChange?(status)
                                    if status == .didDismiss || status == .didFailToPresent {
                                        isPresented = false
                                    }
                                }
                            )
                        } catch {
                            debugPrint("Interstitial error: \(error)")
                            isPresented = false
                        }
                    }
                }
                .frame(width: 0, height: 0)
            )
    }
}

@available(iOS 15.0, *)
public extension View {
    func interstitialAd(
        isPresented: Binding<Bool>,
        adUnitID: AdUnitIdentifiable,
        onStatusChange: ((InterstitialAdStatus) -> Void)? = nil
    ) -> some View {
        modifier(InterstitialModifier(
            isPresented: isPresented,
            adUnitID: adUnitID,
            onStatusChange: onStatusChange
        ))
    }
}
```

### Step 2: `RewardedModifier.swift`

```swift
import SwiftUI

@available(iOS 15.0, *)
public struct RewardedModifier: ViewModifier {
    @Binding var isPresented: Bool
    let adUnitID: AdUnitIdentifiable
    var onReward: ((AdReward) -> Void)?
    var onStatusChange: ((RewardedAdStatus) -> Void)?

    public func body(content: Content) -> some View {
        content
            .background(
                ViewControllerResolver { vc in
                    guard isPresented else { return }
                    Task { @MainActor in
                        do {
                            try await AdMobHelper.shared.showRewardedAd(
                                from: vc,
                                adUnitID: adUnitID,
                                statusCallback: { status in
                                    onStatusChange?(status)
                                    if status == .didDismiss || status == .didEarnRewardAndDismiss || status == .didFailToPresent {
                                        isPresented = false
                                    }
                                },
                                completion: { reward in
                                    onReward?(reward)
                                }
                            )
                        } catch {
                            debugPrint("Rewarded error: \(error)")
                            isPresented = false
                        }
                    }
                }
                .frame(width: 0, height: 0)
            )
    }
}

@available(iOS 15.0, *)
public extension View {
    func rewardedAd(
        isPresented: Binding<Bool>,
        adUnitID: AdUnitIdentifiable,
        onReward: ((AdReward) -> Void)? = nil,
        onStatusChange: ((RewardedAdStatus) -> Void)? = nil
    ) -> some View {
        modifier(RewardedModifier(
            isPresented: isPresented,
            adUnitID: adUnitID,
            onReward: onReward,
            onStatusChange: onStatusChange
        ))
    }
}
```

### Step 3: `RewardedInterstitialModifier.swift`

Cùng pattern với RewardedModifier nhưng gọi `showRewardedInterstitialAd`:

```swift
import SwiftUI

@available(iOS 15.0, *)
public struct RewardedInterstitialModifier: ViewModifier {
    @Binding var isPresented: Bool
    let adUnitID: AdUnitIdentifiable
    var onReward: ((AdReward) -> Void)?
    var onStatusChange: ((RewardedAdStatus) -> Void)?

    public func body(content: Content) -> some View {
        content
            .background(
                ViewControllerResolver { vc in
                    guard isPresented else { return }
                    Task { @MainActor in
                        do {
                            try await AdMobHelper.shared.showRewardedInterstitialAd(
                                from: vc,
                                adUnitID: adUnitID,
                                statusCallback: { status in
                                    onStatusChange?(status)
                                    if status == .didDismiss || status == .didEarnRewardAndDismiss || status == .didFailToPresent {
                                        isPresented = false
                                    }
                                },
                                completion: { reward in
                                    onReward?(reward)
                                }
                            )
                        } catch {
                            debugPrint("RewardedInterstitial error: \(error)")
                            isPresented = false
                        }
                    }
                }
                .frame(width: 0, height: 0)
            )
    }
}

@available(iOS 15.0, *)
public extension View {
    func rewardedInterstitialAd(
        isPresented: Binding<Bool>,
        adUnitID: AdUnitIdentifiable,
        onReward: ((AdReward) -> Void)? = nil,
        onStatusChange: ((RewardedAdStatus) -> Void)? = nil
    ) -> some View {
        modifier(RewardedInterstitialModifier(
            isPresented: isPresented,
            adUnitID: adUnitID,
            onReward: onReward,
            onStatusChange: onStatusChange
        ))
    }
}
```

### Usage Example

```swift
struct GameView: View {
    @State private var showInterstitial = false
    @State private var showRewarded = false

    var body: some View {
        VStack {
            Button("Next Level") { showInterstitial = true }
            Button("Watch Ad for Coins") { showRewarded = true }
        }
        .interstitialAd(
            isPresented: $showInterstitial,
            adUnitID: AppAdUnit.interstitial
        )
        .rewardedAd(
            isPresented: $showRewarded,
            adUnitID: AppAdUnit.rewarded,
            onReward: { reward in
                coins += Int(reward.amount.intValue)
            }
        )
    }
}
```

## Todo List

- [ ] Sửa `AdMobHelper.swift` — thêm `rewardedInterstitialAdStatusCallback` property
- [ ] Sửa `AdMobHelper+RewardedInterstitial.swift` — thêm `statusCallback` parameter
- [ ] Sửa `AdMobHelper+FullScreenDelegate.swift` — handle RI status events
- [ ] Sửa `AdMobHelper.clearAllAds()` — clear RI callback
- [ ] Tạo `InterstitialModifier.swift`
- [ ] Tạo `RewardedModifier.swift`
- [ ] Tạo `RewardedInterstitialModifier.swift`
- [ ] Build verify

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| ViewControllerResolver trả VC sai | Ad present fail | Fallback: key window root VC |
| `isPresented` binding race | Show ad 2 lần | `guard isPresented` check |
| Backward compat: thêm param có default | Không break | `statusCallback: ... = nil` |
