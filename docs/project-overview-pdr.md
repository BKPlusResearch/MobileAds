# MobileAds — Project Overview & PDR

## 1. Product Summary

**MobileAds** is an internal iOS Swift framework (CocoaPod) that wraps the Google Mobile Ads SDK, StoreKit 2 In-App Purchases, and multiple attribution/analytics SDKs into a single, easy-to-integrate package. It is designed for BKPlus/Apero apps to rapidly add monetization capabilities without re-implementing boilerplate ad lifecycle management, consent handling, or revenue tracking.

| Attribute | Value |
|---|---|
| **Name** | MobileAds |
| **Version** | 1.3.0 |
| **Platform** | iOS 15.0+ |
| **Language** | Swift 5.5+ |
| **Distribution** | CocoaPods (private git repo) |
| **License** | MIT |
| **Repository** | `github.com/BKPlusResearch/MobileAds` |
| **Organization** | BKPlus / AperoVN |

---

## 2. Problem Statement

Building iOS apps with ad-based monetization requires integrating multiple SDKs (AdMob, Adjust, TikTok, Facebook, Firebase) with significant boilerplate for consent management, ad lifecycle handling, revenue attribution, and in-app purchases. Each new app would otherwise duplicate this work, leading to inconsistencies and maintenance overhead.

## 3. Goals

1. **Single integration point** — One `pod install` brings all monetization infrastructure.
2. **Type-safe ad management** — Protocol-based ad unit IDs, enum status callbacks.
3. **Unified revenue tracking** — Every ad impression automatically flows to Adjust, Firebase, TikTok, and Facebook.
4. **In-App Purchase support** — StoreKit 2 with async/await, Keychain storage, receipt validation.
5. **Configurable Native Ads** — XIB-based templates (small/medium) with global theming via `NativeAdConfiguration`.
6. **Debug tooling** — Built-in `AdMetricsTracker` and on-screen monitor view for development.

## 4. Non-Goals

- Server-side ad mediation or custom ad network integration (relies on AdMob mediation).
- SwiftUI-native views (current implementation is UIKit-based).
- Support for platforms other than iOS (no macOS, tvOS, watchOS).

---

## 5. Target Users

| User | Use Case |
|---|---|
| **iOS Developers (BKPlus team)** | Integrate ads + IAP into new/existing apps with minimal code |
| **Product Managers** | Control ad formats, A/B testing via Remote Config |
| **Growth/Marketing** | Leverage unified ad revenue attribution across Adjust, TikTok, Facebook |

---

## 6. Key Features (PDR)

### 6.1 Ad Format Support

| Format | Load API | Show API | Status Enum |
|---|---|---|---|
| Banner | `loadBannerAd(into:...)` | Auto-display | `BannerAdStatus` |
| Banner (Self-contained) | `BannerAdView.loadAd(...)` | Auto-display | Via delegate |
| Interstitial | `loadInterstitialAd(...)` | `showInterstitialAd(...)` | `InterstitialAdStatus` |
| Rewarded | `loadRewardedAd(...)` | `showRewardedAd(...)` | `RewardedAdStatus` |
| Rewarded Interstitial | `loadRewardedInterstitialAd(...)` | `showRewardedInterstitialAd(...)` | — |
| App Open | `loadAppOpenAd(...)` | `showAppOpenAd(...)` | `AppOpenAdStatus` |
| Native (Small) | `NativeAdService.loadNativeAd(...)` | Auto-display | `NativeAdStatus` |
| Native (Medium) | `NativeAdService.loadNativeAd(...)` | Auto-display | `NativeAdStatus` |

### 6.2 Native Ad Cache System

- Preload native ads for instant display.
- Cache auto-expires after 1 hour (AdMob policy).
- Type-safe cache keys defined per-app.
- Automatic fallback to network if cache unavailable.

### 6.3 In-App Purchase (StoreKit 2)

- Fetch products, purchase, restore with async/await.
- Receipt validation with Apple server.
- Subscription status stored in UserDefaults (migrated from Keychain).
- Auto transaction listener via `Transaction.updates`.

### 6.4 Revenue Attribution Pipeline

Every ad impression is automatically tracked across:
- **Adjust** — Ad revenue + event tracking
- **Firebase Analytics** — `ad_impression` event
- **TikTok Business SDK** — `InAppADImpr` + `ImpressionLevelAdRevenue`
- **Facebook SDK** — `AD_IMPRESSION` event

### 6.5 Consent Management

- Integrated Google UMP (User Messaging Platform) for GDPR/ATT consent.
- SDK initialization gated by consent status.

### 6.6 Remote Config

- Firebase Remote Config wrapper with type-safe key protocol (`RemoteKeyIdentifiable`).
- Support for Bool, Int, Double, String, and JSON-decodable values.

### 6.7 Ad Metrics (Debug)

- In-memory per-session tracker (`AdMetricsTracker`).
- On-screen floating monitor view (`AdMetricsMonitorView`) for debugging.
- Tracks: Request → Loaded → Show → Impression → Click per ad unit.

---

## 7. Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| `Google-Mobile-Ads-SDK` | ~> 13.0 | Core ad display |
| `GoogleUserMessagingPlatform` | ~> 3.0.0 | Consent management (UMP) |
| `Firebase` | ~> 11.15.0 | Core Firebase |
| `FirebaseCrashlytics` | ~> 11.15.0 | Crash reporting |
| `FirebaseAnalytics` | ~> 11.15.0 | Analytics & revenue logging |
| `Firebase/RemoteConfig` | ~> 11.15.0 | Remote configuration |
| `Adjust` | ~> 5.5.0 | Attribution & revenue tracking |
| `TikTokBusinessSDK` | ~> 1.3.0 | TikTok attribution |
| `FBSDKCoreKit` | ~> 18.0 | Facebook ad impression tracking |
| `SnapKit` | ~> 5.7.1 | Auto Layout DSL |
| `SkeletonView` | ~> 1.29.2 | Loading shimmer animations |
| `Toast-Swift` | ~> 5.0.1 | Toast notifications |
| `PremiumAdmobAdapter` | latest | Premium mediation adapter |

---

## 8. Success Metrics

- **Integration time** < 1 hour for a new app.
- **Ad format coverage** — All standard AdMob formats supported.
- **Revenue attribution** — 100% of impressions tracked across all attribution platforms.
- **Crash-free** — No framework-caused crashes in production.
