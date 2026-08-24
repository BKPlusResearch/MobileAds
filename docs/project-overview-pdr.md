# Project Overview & PDR

**Last updated:** 2026-08-22 · **Version:** 2.0.0

## Product

**MobileAds** is a reusable iOS monetization framework for BKPlus/Apero apps. It packages everything a free, ad-supported app needs — ads, consent, mediation, in-app purchases, attribution, and analytics — behind a small, consistent Swift API so each app avoids re-implementing SDK plumbing.

## Problem

Every ad-supported app must repeatedly wire up: Google Mobile Ads init + UMP consent, all five ad formats with lifecycle callbacks, native ad templates/theming, IAP + subscription validation, and ad-revenue reporting to attribution/analytics SDKs. Doing this per app is error-prone and inconsistent.

## Solution

A single CocoaPods dependency exposing singleton facades and consumer-supplied protocol enums. Apps integrate in a few lines: define their ad-unit/product enums, call `configAds`, then load/show ads and manage purchases.

## Target Users

Internal iOS app teams shipping ad-supported apps that need consistent monetization and Meta/TikTok/Adjust revenue attribution.

## Core Requirements

| # | Requirement | Status |
|---|-------------|--------|
| R1 | Consent-gated SDK init (UMP) | ✅ `configAds` + `GoogleMobileAdsConsentManager` |
| R2 | All display formats: banner, interstitial, rewarded, rewarded-interstitial, app open | ✅ `AdMobHelper+*` |
| R3 | Native ads with reusable templates + global theming | ✅ `NativeAdService`, `NativeAdViewSmall/Medium`, `NativeAdConfiguration` |
| R4 | Native ad preload cache for instant display | ✅ single-use cache, 1h expiry (`NATIVE_AD_CACHE.md`) |
| R5 | Self-managed banner for multi-instance/list contexts | ✅ `BannerAdView` (+ collapsible) |
| R6 | Mediation across major networks | ✅ 7 adapters + PremiumAdsGoogleAdapter |
| R7 | IAP + subscriptions (StoreKit 2), entitlement re-derived from StoreKit on every check | ✅ `EntitlementService` |
| R8 | Ad revenue → Adjust + Facebook AD_IMPRESSION + TikTok | ✅ `ADJustManager`, `FacebookManager`, `TikTokManager` |
| R9 | Typed analytics + remote config | ✅ `FirebaseLogger`, `RemoteConfigService` |
| R10 | App-defined ad unit / product IDs (no hardcoded prod IDs) | ✅ `AdUnitIdentifiable`, `EntitlementConfig.productIDs` |

## Non-Goals

- No SwiftUI API surface (UIKit only).
- No app-specific ad unit IDs or product IDs shipped in the framework.
- No server-side receipt validation backend (client validates with Apple; backend validation recommended to consumers).

## Constraints

- iOS 15.0+ (StoreKit 2 requirement), Swift 5.5, static framework.
- Dependency versions must stay pinned in sync between `Podfile.lock` and `MobileAds.podspec`.

## Success Criteria

- Drop-in integration for a new app in <1 day.
- Ad revenue correctly attributed across Adjust/Meta/TikTok.
- Zero production ad-unit leakage from the framework.

## Open Questions

- The SwiftUI layer has no runtime coverage. The app-open resume rules now live in `AppOpenModifier` as scenePhase logic that only a running app exercises.
