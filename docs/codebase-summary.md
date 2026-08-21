# Codebase Summary

**Last updated:** 2026-07-26 · **Version:** 1.3.0 (podspec) · **Branch:** new-MobileAds

## What This Is

`MobileAds` — a static, distributable **CocoaPods Swift framework** (`use_frameworks!`, `static_framework = true`) that wraps the Google Mobile Ads SDK and bundles the supporting services a production ad-supported iOS app needs: consent, mediation, IAP, attribution, and analytics. Consumer apps depend on it via `pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git"`.

- Platform: iOS 15.0+ · Swift 5.5 · Xcode 26.0+
- ~7,100 LOC Swift across 47 files
- License: MIT

## Module Map

Source root: `MobileAds/`

| Directory | Responsibility | Key public types |
|-----------|----------------|------------------|
| `AdMobHelper/` | Central ad orchestration (all formats). Split into `AdMobHelper+*` extensions per format. | `AdMobHelper` (singleton), `NativeAdService`, `BannerAdView`, `NativeAdConfiguration`, `NativeAdViewSmall/Medium`, `GoogleMobileAdsConsentManager`, `AdUnitIdentifiable`, status enums |
| `AdMob/` | Ad revenue metrics tracking + in-app debug overlay. | `AdMetrics`, `AdMetricsTracker`, `AdMetricsWindow`, `AdMetricsMonitorView` |
| `IAP/` | StoreKit 2 entitlements-first IAP. Entitlement is derived from `Transaction.currentEntitlements` on every check and never persisted. | `EntitlementService` (singleton, `@MainActor`, `ObservableObject`), `EntitlementConfig`, `EntitlementPurchaseOutcome` / `EntitlementRestoreOutcome` / `EntitlementPurchaseReceipt` |
| `ADJustManager/` | Adjust SDK attribution + ad-revenue logging (fans out to Facebook). | `ADJustManager` (singleton), `AppADJustConfig`, `ADJAdType` |
| `FacebookManager/` | Facebook SDK `AD_IMPRESSION` revenue events. | `FacebookManager` (singleton) |
| `TikTokManager/` | TikTok Business SDK events + ad-revenue reporting. | `TikTokManager` (singleton), `TikTokAppConfig`, `TikTokEventType` |
| `FirebaseLogger/` | Typed Firebase Analytics event logging. | `FirebaseLogger` (singleton), `AnalyticsEvent`, `LogParameter` |
| `RemoteConfig/` | Firebase Remote Config wrapper. | `RemoteConfigService` (singleton), `RemoteKeyIdentifiable` |
| `Extension/` | Shared UIKit helpers + callback typealiases. | `UIView+Extension`, `CallBackDefine` |
| `Assets/`, `*.docc` | Bundled resources + DocC catalog. | — |

## Ad Formats Supported

Banner (incl. collapsible + self-managed `BannerAdView`), Interstitial, Rewarded, Rewarded Interstitial, App Open (App Resume), and Native (small/medium XIB templates, with a single-use preload cache).

## Cross-Cutting Concerns

- **Consent-first init:** `AdMobHelper.configAds(from:)` → `GoogleMobileAdsConsentManager` (UMP) → SDK start only if `canRequestAds`.
- **App-relative ad unit IDs:** consumer apps define an `AdUnitIdentifiable` enum (test vs production via `#if DEBUG`). The framework never hardcodes production IDs.
- **Ad revenue → attribution/analytics:** `paidEventHandler` on ads → `ADJustManager.logRevenue()` → also emits Facebook `AD_IMPRESSION` and TikTok revenue events, plus `AdMetricsTracker`.
- **Mediation:** 7 GoogleMobileAds mediation adapters (AppLovin, IronSource, Vungle, Facebook, Mintegral, Pangle, Unity) + `PremiumAdsGoogleAdapter`.

## Companion Docs

- `README.md` — consumer-facing integration guide (Vietnamese + English, with code samples).
- `NATIVE_AD_CACHE.md` — native ad preload/cache system deep dive.
- `docs/system-architecture.md` — layer diagram + data flows.
- `docs/code-standards.md` — conventions in force.
- `docs/deployment-guide.md` — versioning & pod release.
- `docs/project-roadmap.md` — direction & open items.
