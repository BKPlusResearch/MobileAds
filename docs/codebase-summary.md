# Codebase Summary

**Last updated:** 2026-08-25 · **Version:** `spec.version` in `MobileAds.podspec` · **Branch:** new-MobileAds

## What This Is

`MobileAds` — a static, distributable **CocoaPods Swift framework** (`use_frameworks!`, `static_framework = true`) that wraps the Google Mobile Ads SDK and bundles the supporting services a production ad-supported iOS app needs: consent, mediation, IAP, attribution, and analytics. Consumer apps depend on it via `pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git"`.

- Platform: iOS 15.0+ · Swift 5.5 · Xcode 26.0+ (`spec.platform` / `spec.swift_version`)
- Size: `find MobileAds -name '*.swift' | xargs wc -l`
- License: MIT

## Module Map

Source root: `MobileAds/`

| Directory | Responsibility | Key public types |
|-----------|----------------|------------------|
| `AdMobHelper/` | Central ad orchestration (all formats). Split into `AdMobHelper+*` extensions per format. | `AdMobHelper` (singleton), `NativeAdService`, `BannerAdView`, `NativeAdConfiguration`, `NativeAdViewSmall/Medium`, `GoogleMobileAdsConsentManager`, `AdUnitIdentifiable`, status enums |
| `AdMob/` | Ad revenue metrics tracking + in-app debug overlay. | `AdMetrics`, `AdMetricsTracker`, `AdMetricsWindow`, `AdMetricsMonitorView` |
| `IAP/` | StoreKit 2 entitlements-first IAP. Entitlement is derived from `Transaction.currentEntitlements` on every check and never persisted. | `EntitlementService` (singleton, `@MainActor`, `ObservableObject`), `EntitlementConfig`, `EntitlementPurchaseOutcome` / `EntitlementRestoreOutcome` / `EntitlementPurchaseReceipt` |
| `AdRevenue/` | Ad-revenue fan-out to Firebase Analytics, TikTok and Facebook. | `AdRevenueManager` (singleton), `AdType` |
| `FacebookManager/` | Facebook SDK `AD_IMPRESSION` revenue events. | `FacebookManager` (singleton) |
| `TikTokManager/` | TikTok Business SDK events + ad-revenue reporting. | `TikTokManager` (singleton), `TikTokAppConfig`, `TikTokEventType` |
| `FirebaseLogger/` | Typed Firebase Analytics event logging. | `FirebaseLogger` (singleton), `AnalyticsEvent`, `LogParameter` |
| `RemoteConfig/` | Firebase Remote Config wrapper. | `RemoteConfigService` (singleton), `RemoteKeyIdentifiable` |
| `SwiftUI/` | Optional SwiftUI entry point over the same `AdMobHelper`. Nothing here holds ad state; every call delegates to the facade. | `BannerAdSwiftUI`, `NativeAdSwiftUI` (both `UIViewRepresentable`), `.interstitialAd` / `.rewardedAd` / `.rewardedInterstitialAd` / `.appOpenAd` view modifiers, `ViewControllerResolver` |
| `Extension/` | Shared UIKit helpers + callback typealiases. | `UIView+Extension`, `CallBackDefine` |
| `Assets/`, `*.docc` | Bundled resources + DocC catalog. | — |

## Ad Formats Supported

Banner (incl. collapsible + self-managed `BannerAdView`), Interstitial, Rewarded, Rewarded Interstitial, App Open (App Resume), and Native (small/medium XIB templates, with a single-use preload cache).

## Cross-Cutting Concerns

- **Consent-first init:** `AdMobHelper.configAds(from:)` → `GoogleMobileAdsConsentManager` (UMP) → SDK start only if `canRequestAds`.
- **App-relative ad unit IDs:** consumer apps define an `AdUnitIdentifiable` enum (test vs production via `#if DEBUG`). The framework never hardcodes production IDs.
- **Ad revenue → attribution/analytics:** `paidEventHandler` on ads → `AdRevenueManager.logRevenue()` → Firebase `ad_impression_ios`, Facebook `AD_IMPRESSION` and TikTok revenue events, plus `AdMetricsTracker`.
- **Mediation:** 7 GoogleMobileAds mediation adapters (AppLovin, IronSource, Vungle, Facebook, Mintegral, Pangle, Unity) + `PremiumAdsGoogleAdapter`.

## Companion Docs

- `README.md` — consumer-facing entry point: install + everything UIKit and SwiftUI share.
- `docs/ads-uikit.md` — UIKit ad call sites.
- `docs/ads-swiftui.md` — SwiftUI views and modifiers.
- `docs/in-app-purchases.md` — `EntitlementService`, consumables, 1.x → 2.0 migration.
- `NATIVE_AD_CACHE.md` — native ad preload/cache system deep dive.
- `docs/system-architecture.md` — layer diagram + data flows.
- `docs/code-standards.md` — conventions in force.
- `docs/deployment-guide.md` — versioning & pod release.
- `docs/project-roadmap.md` — direction & open items.
- `MobileAds/AdRevenue/README.md` — ad-revenue fan-out + 2.0.0 → 2.0.1 migration.
- `MobileAds/TikTokManager/TIKTOK_README.md` — TikTok Business SDK setup.
