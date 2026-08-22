# System Architecture

**Last updated:** 2026-08-21 · **Version:** 2.0.0

## Overview

MobileAds is a **library/framework**, not an app. It exposes a thin, singleton-driven public API over the Google Mobile Ads SDK and adjacent third-party SDKs, so a consuming iOS app can integrate monetization, purchases, attribution, and analytics with minimal glue.

## Layering

```
┌──────────────────────────────────────────────────────────────┐
│ Consumer App (AppDelegate/SceneDelegate/ViewControllers)      │
│  - defines AdUnitIdentifiable enums + EntitlementConfig       │
│  - calls AdMobHelper.shared / EntitlementService.shared / ...  │
└───────────────┬──────────────────────────────────────────────┘
                │ public API (singletons + protocols)
┌───────────────▼──────────────────────────────────────────────┐
│ MobileAds Framework                                            │
│                                                                │
│  Ads facade            Purchases        Growth / Telemetry     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │ AdMobHelper  │  │ Entitlement- │  │ ADJustManager        │ │
│  │  +Banner     │  │  Service     │  │ FacebookManager      │ │
│  │  +Interstit. │  │  (no cache;  │  │ TikTokManager        │ │
│  │  +Rewarded   │  │   derives    │  │ FirebaseLogger       │ │
│  │  +AppOpen    │  │   from Store-│  │ RemoteConfigService  │ │
│  │  +Native(+Cache)│ Kit each check)│ AdMetricsTracker     │ │
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

1. **Singleton facades.** Each concern is a `.shared` singleton (`AdMobHelper`, `EntitlementService`, `ADJustManager`, `FacebookManager`, `TikTokManager`, `FirebaseLogger`, `RemoteConfigService`, `NativeAdConfiguration`, `GoogleMobileAdsConsentManager`, `AdMetricsTracker`, `AdMetricsWindow`). `AdMobHelper` is `@MainActor`.
2. **Extension-per-format.** `AdMobHelper` is split across `AdMobHelper+Banner/Interstitial/Rewarded/RewardedInterstitial/AppOpen/Native/NativeCache/BannerCache/LoadingViews/FullScreenDelegate/NativeDelegate.swift` to keep files small and single-responsibility (per the 200-LOC modularization rule).
3. **Consumer-supplied identifiers.** Consumers supply `AdUnitIdentifiable` (ad unit IDs), `RemoteKeyIdentifiable` (remote config keys), and `EntitlementConfig.productIDs` (IAP product IDs) — the framework ships no app-specific IDs.
4. **No IAP persistence.** `EntitlementService` stores no entitlement at all; it re-derives from `Transaction.currentEntitlements` on every check, so reinstalls, device changes, refunds and Family Sharing are handled by StoreKit. Its only `UserDefaults` key records whether a restore has been proactively suggested.
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

### IAP purchase → entitlement state
```
configure(EntitlementConfig(productIDs:))  → bootstrap()  (StoreKit 2)
  → verify() reads Transaction.currentEntitlements, filters consumables by productType
  → publishes isEntitled / verification / activeProductID / expiryDate — NOTHING is persisted
  → purchase(id) judges the returned transaction, offers consumables to onUnfinished, then finishes
  → Transaction.updates listener re-verifies on renew/expire/refund and re-offers unfinished work
  → refresh() on foreground (30s debounce); every check re-derives from StoreKit
```
No entitlement value is stored anywhere, so there is no cached state to tamper with and none to
go stale. The cost is that `isEntitled` is `false` until `verification == .verified`, including for
an existing subscriber at launch — gates must distinguish "not entitled" from "not known yet".

## Threading

`AdMobHelper` and UI-facing ad views are `@MainActor`. `EntitlementService` is `@MainActor` and an `ObservableObject`; it uses async/await (StoreKit 2) and owns the app's single long-lived `Transaction.updates` listener task. A generation counter guards against a stale `verify()` overwriting a newer result.

## Diagram Maintenance

The diagrams above are hand-maintained ASCII. Redraw them whenever a box no longer
matches the module list in `codebase-summary.md`, and keep them at the level of
components and data flow — never individual types or method names.
