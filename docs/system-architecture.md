# System Architecture

**Last updated:** 2026-07-26 · **Version:** 1.3.0

## Overview

MobileAds is a **library/framework**, not an app. It exposes a thin, singleton-driven public API over the Google Mobile Ads SDK and adjacent third-party SDKs, so a consuming iOS app can integrate monetization, purchases, attribution, and analytics with minimal glue.

## Layering

```
┌──────────────────────────────────────────────────────────────┐
│ Consumer App (AppDelegate/SceneDelegate/ViewControllers)      │
│  - defines AdUnitIdentifiable / IAPProductIdentifiable enums  │
│  - calls AdMobHelper.shared / IAPService.shared / ...         │
└───────────────┬──────────────────────────────────────────────┘
                │ public API (singletons + protocols)
┌───────────────▼──────────────────────────────────────────────┐
│ MobileAds Framework                                            │
│                                                                │
│  Ads facade            Purchases        Growth / Telemetry     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │ AdMobHelper  │  │ IAPService   │  │ ADJustManager        │ │
│  │  +Banner     │  │  +Receipt    │  │ FacebookManager      │ │
│  │  +Interstit. │  │  +Subscrip.  │  │ TikTokManager        │ │
│  │  +Rewarded   │  │  storage:    │  │ FirebaseLogger       │ │
│  │  +AppOpen    │  │   Keychain / │  │ RemoteConfigService  │ │
│  │  +Native(+Cache)│ UserDefaults │  │ AdMetricsTracker     │ │
│  │  BannerAdView│  └──────────────┘  └──────────────────────┘ │
│  │  NativeAdService / NativeAdConfiguration                   │ │
│  │  GoogleMobileAdsConsentManager (UMP)                       │ │
│  └──────────────┘                                             │
└───────────────┬──────────────────────────────────────────────┘
                │ CocoaPods dependencies
┌───────────────▼──────────────────────────────────────────────┐
│ Google-Mobile-Ads-SDK + 7 mediation adapters + PremiumAds     │
│ StoreKit 2 · Firebase (Analytics/Crashlytics/RemoteConfig)    │
│ Adjust · FBSDKCoreKit · TikTokBusinessSDK · GoogleUMP         │
│ SnapKit · SkeletonView · Toast-Swift                          │
└──────────────────────────────────────────────────────────────┘
```

## Key Design Decisions

1. **Singleton facades.** Each concern is a `.shared` singleton (`AdMobHelper`, `IAPService`, `ADJustManager`, `FacebookManager`, `TikTokManager`, `FirebaseLogger`, `RemoteConfigService`, `NativeAdConfiguration`, `GoogleMobileAdsConsentManager`, `AdMetricsTracker`, `AdMetricsWindow`). `AdMobHelper` is `@MainActor`.
2. **Extension-per-format.** `AdMobHelper` is split across `AdMobHelper+Banner/Interstitial/Rewarded/RewardedInterstitial/AppOpen/Native/NativeCache/BannerCache/LoadingViews/FullScreenDelegate/NativeDelegate.swift` to keep files small and single-responsibility (per the 200-LOC modularization rule).
3. **Protocol-driven identifiers.** Consumers supply `AdUnitIdentifiable` (ad unit IDs), `IAPProductIdentifiable` (product IDs), and `RemoteKeyIdentifiable` (remote config keys) — the framework ships no app-specific IDs.
4. **Pluggable IAP storage.** `IAPService` persists subscription state through a storage abstraction (`IAPKeychainStorage` / `IAPUserDefaultsStorage`) with a migration path (`IAPMigration`).
5. **Escape-hatch, not singleton, for multi-instance banners.** `BannerAdView` is a self-contained `UIView` subclass that does *not* touch `AdMobHelper.shared`, avoiding singleton conflicts when many banners coexist (e.g., in collection views).

## Core Data Flows

### Ad initialization (consent-gated)
```
App: AdMobHelper.shared.configAds(from:)
  → GoogleMobileAdsConsentManager.gatherConsent (UMP form)
  → if canRequestAds → MobileAds.shared.start()  [once, isSDKInitialized guard]
  → completion()
```

### Ad revenue → attribution + analytics fan-out
```
Ad paidEventHandler fires (any format)
  → ADJustManager.logRevenue(...)
     → Adjust ad-revenue event
     → FacebookManager logs AD_IMPRESSION
     → TikTokManager reports ad revenue
  → AdMetricsTracker records (visible via AdMetricsWindow overlay in debug)
```

### Native ad preload cache (single-use)
```
Splash: preloadMultipleNativeAds(requests:) → cache by NativeAdCacheKey (1h expiry)
Screen: loadNativeAdWithCache(..., cacheKey:)
  → hasCachedNativeAd? → display instantly, then clear (single-use)
  → else isPreloadingNativeAd? → retry up to ~2.5s
  → else load from network
```
Full detail: `NATIVE_AD_CACHE.md`.

### IAP purchase → validated subscription state
```
IAPService.fetchProducts([IAPProductIdentifiable])  (StoreKit 2)
  → purchase(product) → auto validate receipt with Apple → persist to storage (Keychain/UserDefaults)
  → Transaction.updates listener keeps subscription status current (renew/expire) in background
  → hasActiveSubscription() / isSubscriptionActive(for:) read from local storage
```

## Threading

`AdMobHelper` and UI-facing ad views are `@MainActor`. IAP uses async/await (StoreKit 2) and a long-lived `Transaction.updates` listener task.

## Diagram Maintenance

When redrawing these diagrams as SVG, apply `/ck:tech-graph` layout rules (`.claude/skills/tech-graph/references/svg-layout-best-practices.md`) and self-review with `/ck:preview --diagram`.
