# MobileAds — Codebase Summary

## Quick Stats

| Metric | Value |
|---|---|
| **Swift files** | 47 |
| **Total lines of code** | ~7,068 |
| **Modules** | 9 |
| **Xib templates** | 2 (NativeAdViewSmall, NativeAdViewMedium) |
| **Asset files** | 6 PNG images (icons, star ratings) |

---

## Module Overview

```
MobileAds/
├── AdMobHelper/        # 🎯 Core — Ad lifecycle management (27 files, ~3,500 LOC)
├── AdMob/              # 📊 Supporting — Metrics, models, enums
│   ├── Service/        #    AdMetricsTracker, AdMetricsMonitorView, AdMetricsWindow
│   ├── Model/          #    AdMetrics data model
│   ├── AdNative/       #    Native ad view templates (FreeSize, Medium, Small, Unified)
│   └── (empty dirs)    #    AdBanner, AdInterstitial, AdResume, Constants, Enum, Manager, Extension
├── IAP/                # 💰 In-App Purchase service (8 files, ~1,200 LOC)
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

**Key files:**

| File | Purpose | LOC |
|---|---|---|
| `AdMobHelper.swift` | Singleton, SDK init, consent, properties, enums | 327 |
| `AdMobHelper+Banner.swift` | Banner ad load/display via singleton | ~300 |
| `AdMobHelper+BannerCache.swift` | Banner caching logic | ~120 |
| `AdMobHelper+Interstitial.swift` | Interstitial load/show | ~100 |
| `AdMobHelper+Rewarded.swift` | Rewarded ad load/show | ~110 |
| `AdMobHelper+RewardedInterstitial.swift` | Rewarded interstitial load/show | ~95 |
| `AdMobHelper+AppOpen.swift` | App open ad load/show with expiry | ~140 |
| `AdMobHelper+Native.swift` | Native ad loading delegation | ~40 |
| `AdMobHelper+NativeCache.swift` | Native ad cache system | ~500 |
| `AdMobHelper+NativeDelegate.swift` | Native ad delegate callbacks | ~70 |
| `AdMobHelper+FullScreenDelegate.swift` | Full-screen ad lifecycle delegate | 149 |
| `AdMobHelper+LoadingViews.swift` | Loading overlay management | ~50 |
| `AdUnitID.swift` | `AdUnitIdentifiable` protocol | 30 |
| `NativeAdService.swift` | Native ad load/display service | 558 |
| `BannerAdView.swift` | Self-contained banner (no singleton) | 232 |
| `GoogleMobileAdsConsentManager.swift` | UMP consent wrapper | ~80 |
| `NativeAdViewSmall.swift` | Small native ad XIB view | ~260 |
| `NativeAdViewMedium.swift` | Medium native ad XIB view | ~300 |
| `NativeAdLoaderDelegateHelper.swift` | Ad loader delegate bridge | ~45 |
| `AppOpenAdLoadingView.swift` | App open loading overlay | ~60 |
| `BannerAdLoadingView.swift` | Banner shimmer loading | ~55 |
| `NativeAdLoadingView.swift` | Native ad loading view | ~110 |
| `NativeAdSmallLoadingView.swift` | Small native shimmer | ~110 |
| `NativeAdMediumLoadingView.swift` | Medium native shimmer | ~170 |

**Key patterns:**
- Singleton `AdMobHelper.shared` for most ad operations
- `BannerAdView` as a non-singleton alternative for multiple banners
- Status enums for type-safe lifecycle callbacks
- `@MainActor` isolation throughout

### 2. IAP (In-App Purchases)

StoreKit 2 integration with async/await.

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

### 3. ADJustManager

Wraps the Adjust SDK for ad revenue attribution and custom event tracking.

| File | Purpose |
|---|---|
| `ADJustManager.swift` | Revenue tracking to Adjust, Firebase, TikTok, Facebook |

**Revenue flow:** When an ad pays → `ADJustManager.logRevenue()` dispatches to ALL attribution platforms simultaneously.

### 4. TikTokManager

Comprehensive TikTok Business SDK integration.

| File | Purpose |
|---|---|
| `TikTokManager.swift` | SDK config, event tracking, ad revenue |
| `TikTokConfig.swift` | Configuration model |
| `TikTokEventType.swift` | Standard + custom event type enum |

### 5. FacebookManager

Minimal Facebook SDK integration focused on `AD_IMPRESSION` event logging.

| File | Purpose |
|---|---|
| `FacebookManager.swift` | Log ad impressions to Facebook for in-app ad revenue optimization |

### 6. FirebaseLogger

Type-safe Firebase Analytics wrapper.

| File | Purpose |
|---|---|
| `FirebaseLogger.swift` | Log events, set user properties |
| `AnalyticsEvent.swift` | Event name enum |
| `LogParameter.swift` | Parameter key enum |

### 7. RemoteConfig

Firebase Remote Config wrapper with protocol-based key management.

| File | Purpose |
|---|---|
| `RemoteConfigService.swift` | Fetch, activate, query remote config values |

### 8. AdMob/Service (Metrics)

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
