# MobileAds — Codebase Summary

Navigation map for the framework source. For current size or file counts, ask the tree rather than this page:

```bash
find MobileAds -name '*.swift' | wc -l
find MobileAds -name '*.swift' -exec cat {} + | wc -l
```

---

## Module Overview

```
MobileAds/
├── AdMobHelper/        # 🎯 Core — Ad lifecycle management
├── AdMob/              # 📊 Supporting — Metrics, models, enums
│   ├── Service/        #    AdMetricsTracker, AdMetricsMonitorView, AdMetricsWindow
│   ├── Model/          #    AdMetrics data model
│   ├── AdNative/       #    Native ad view templates (FreeSize, Medium, Small, Unified)
│   └── (empty dirs)    #    AdBanner, AdInterstitial, AdResume, Constants, Enum, Manager, Extension
├── SwiftUI/            # 🧩 SwiftUI entry points wrapping the UIKit views
├── IAP/                # 💰 In-App Purchase service
├── ADJustManager/      # 📈 Adjust SDK attribution wrapper
├── TikTokManager/      # 📊 TikTok Business SDK wrapper
├── FacebookManager/    # 📘 Facebook SDK AD_IMPRESSION logger
├── FirebaseLogger/     # 🔥 Firebase Analytics wrapper
├── RemoteConfig/       # ⚙️ Firebase Remote Config wrapper
├── Extension/          # 🔧 Shared utilities (CallBackDefine, UIView+Extension)
├── Assets/             # 🖼️ Image assets (close, info, star ratings)
└── MobileAds.docc/     # 📖 DocC documentation catalog
```

---

## Module Details

### 1. AdMobHelper (Core)

The heart of the framework. `AdMobHelper` is a `@MainActor` singleton that manages the Google Mobile Ads SDK lifecycle.

**Where to look:**

| Concern | Files |
|---|---|
| Singleton, SDK init, consent + ATT gating, shared state | `AdMobHelper.swift`, `GoogleMobileAdsConsentManager.swift` |
| Per-format load/show | `AdMobHelper+{Banner,Interstitial,Rewarded,RewardedInterstitial,AppOpen,Native}.swift` |
| Caching | `AdMobHelper+BannerCache.swift`, `AdMobHelper+NativeCache.swift` |
| Delegates | `AdMobHelper+FullScreenDelegate.swift`, `AdMobHelper+NativeDelegate.swift`, `NativeAdLoaderDelegateHelper.swift` |
| Loading overlays / shimmer | `AdMobHelper+LoadingViews.swift`, `*LoadingView.swift` |
| Non-singleton banner | `BannerAdView.swift` |
| Native rendering | `NativeAdService.swift`, `NativeAdView{Small,Medium}.swift` |
| Consumer-facing protocol | `AdUnitID.swift` |

**Key patterns:**
- Singleton `AdMobHelper.shared` for most ad operations
- `BannerAdView` as a non-singleton alternative for multiple banners
- Status enums for type-safe lifecycle callbacks
- `@MainActor` isolation throughout
- Full-screen presentation is refused while backgrounded; the throwing path hides its own overlay and keeps the loaded ad

### 2. SwiftUI

Entry points for SwiftUI consumers. No ad logic lives here — each type forwards to the same `AdMobHelper` / `BannerAdView` / `NativeAdService` path UIKit uses, so both surfaces share one cache, one metrics stream, and one attribution pipeline.

| File | Surface |
|---|---|
| `BannerAdSwiftUI.swift`, `NativeAdSwiftUI.swift` | `UIViewRepresentable` views |
| `InterstitialModifier.swift`, `RewardedModifier.swift`, `RewardedInterstitialModifier.swift`, `AppOpenModifier.swift` | `ViewModifier`s exposed as `.interstitialAd(…)`, `.rewardedAd(…)`, `.rewardedInterstitialAd(…)`, `.appOpenAd(…)` |
| `ViewControllerResolver.swift` | Finds the presenting `UIViewController` that full-screen formats require |
| `IAPViewModel.swift` | `ObservableObject` wrapper over `IAPService` for reactive purchase state |

### 3. IAP (In-App Purchases)

StoreKit 2 integration with async/await. The module holds **two independent layers**; an app uses one or the other, never both.

| Layer | Use when | Status |
|---|---|---|
| `EntitlementService` | New apps | Recommended. Entitlement derived from `Transaction.currentEntitlements`, nothing persisted. **Not yet exercised on a device** |
| `IAPService` / `IAPViewModel` | The four apps already on it | Frozen. Entitlement read from `UserDefaults` — **premium lost on reinstall**; `.pending` (Ask to Buy) surfaced as an error |

Running both in one app gives it two `Transaction.updates` listeners and two sources of truth. Constructing an `IAPViewModel` is enough to start the legacy one.

**Entitlements-first layer**

| File | Purpose |
|---|---|
| `EntitlementService.swift` | Derives entitlement from `currentEntitlements`; purchase, restore, intro-offer eligibility |
| `EntitlementConfig.swift` | Host-supplied product IDs (required, non-empty) and optional subscription group |
| `EntitlementOutcome.swift` | Typed outcomes: purchase, restore, failure, and the three-state `EntitlementVerification` |

**Legacy layer**

| File | Purpose |
|---|---|
| `IAPService.swift` | Main service: fetch, purchase, restore, listen |
| `IAPService+Subscription.swift` | Subscription status management |
| `IAPService+Receipt.swift` | Receipt validation with Apple server |
| `IAPModels.swift` | Data models: PurchaseResult, SubscriptionInfo, IAPError |
| `IAPProductIdentifiable.swift` | Protocol for type-safe product IDs |
| `IAPKeychainStorage.swift` | Keychain storage (legacy) |
| `IAPUserDefaultsStorage.swift` | UserDefaults storage (current) |
| `IAPMigration.swift` | Keychain → UserDefaults migration |

### 4. ADJustManager

Wraps the Adjust SDK for ad revenue attribution and custom event tracking.

| File | Purpose |
|---|---|
| `ADJustManager.swift` | Revenue tracking to Adjust, Firebase, TikTok, Facebook |

**Revenue flow:** When an ad pays → `ADJustManager.logRevenue()` dispatches to ALL attribution platforms simultaneously.

### 5. TikTokManager

Comprehensive TikTok Business SDK integration.

| File | Purpose |
|---|---|
| `TikTokManager.swift` | SDK config, event tracking, ad revenue |
| `TikTokConfig.swift` | Configuration model |
| `TikTokEventType.swift` | Standard + custom event type enum |

### 6. FacebookManager

Minimal Facebook SDK integration focused on `AD_IMPRESSION` event logging.

| File | Purpose |
|---|---|
| `FacebookManager.swift` | Log ad impressions to Facebook for in-app ad revenue optimization |

### 7. FirebaseLogger

Type-safe Firebase Analytics wrapper.

| File | Purpose |
|---|---|
| `FirebaseLogger.swift` | Log events, set user properties |
| `AnalyticsEvent.swift` | Event name enum |
| `LogParameter.swift` | Parameter key enum |

### 8. RemoteConfig

Firebase Remote Config wrapper with protocol-based key management.

| File | Purpose |
|---|---|
| `RemoteConfigService.swift` | Fetch, activate, query remote config values |

### 9. AdMob/Service (Metrics)

Debug-only ad performance monitoring.

| File | Purpose |
|---|---|
| `AdMetricsTracker.swift` | In-memory per-session ad metrics |
| `AdMetricsMonitorView.swift` | On-screen floating metrics UI |
| `AdMetricsWindow.swift` | Passthrough window for metrics overlay |
| `AdMetrics.swift` | Metrics data model |

---

## Key Protocols

| Protocol | Module | Purpose |
|---|---|---|
| `AdUnitIdentifiable` | AdMobHelper | App defines ad unit IDs with test/production variants |
| `IAPProductIdentifiable` | IAP | App defines product IDs for StoreKit |
| `RemoteKeyIdentifiable` | RemoteConfig | App defines remote config keys |

---

## Key Singletons

| Singleton | Thread Safety |
|---|---|
| `AdMobHelper.shared` | `@MainActor` |
| `IAPService.shared` | `@MainActor` |
| `NativeAdConfiguration.shared` | `@MainActor` |
| `ADJustManager.shared` | Not isolated (thread-safe by design) |
| `TikTokManager.shared` | Not isolated |
| `FacebookManager.shared` | Not isolated |
| `FirebaseLogger.shared` | Not isolated |
| `RemoteConfigService.shared` | Not isolated |
| `AdMetricsTracker.shared` | `@MainActor` |
