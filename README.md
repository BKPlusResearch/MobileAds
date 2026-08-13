# MobileAds

A Swift framework for iOS monetization — wraps Google Mobile Ads SDK, StoreKit 2 IAP, and unified revenue attribution (Adjust, Firebase, TikTok, Facebook).

## Features

- **All AdMob formats** — Banner, Interstitial, Rewarded, Rewarded Interstitial, App Open, Native (Small/Medium)
- **UIKit and SwiftUI** — Same ads from either surface; SwiftUI gets `UIViewRepresentable` views, `.interstitialAd`/`.rewardedAd`/`.rewardedInterstitialAd`/`.appOpenAd` modifiers, and `IAPViewModel`
- **AdMob mediation** — AppLovin, IronSource, Vungle, Facebook, Mintegral, Pangle, Unity adapters bundled
- **Self-contained `BannerAdView`** — Drop-in UIView, no singleton conflicts for multiple banners
- **Native Ad Cache** — Preload for instant display with 1-hour auto-expiry
- **In-App Purchases** — StoreKit 2 with async/await, receipt validation, subscription management
- **Unified Revenue Attribution** — Every impression auto-tracked to Adjust, Firebase, TikTok, Facebook
- **Consent Management** — Integrated Google UMP for GDPR/ATT
- **Remote Config** — Type-safe Firebase Remote Config wrapper
- **Debug Metrics** — On-screen ad performance monitor

## Requirements

- iOS 15.0+
- Swift 5.5+
- Xcode 26.0+

## Installation

```ruby
# Latest version
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git"

# Specific version
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git", :tag => '1.3.0'
```

```bash
$ pod install
```

## Quick Start

### 1. Define Ad Unit IDs

```swift
import MobileAds

enum AppAdUnitID: AdUnitIdentifiable {
    case appOpen, bannerHome, interstitialExit, rewardedCoin, nativeFeed

    var adUnitIDString: String {
    #if DEBUG
        return testID
    #else
        return productionID
    #endif
    }

    private var testID: String {
        switch self {
        case .appOpen:          return "ca-app-pub-3940256099942544/5575463023"
        case .bannerHome:       return "ca-app-pub-3940256099942544/6300978111"
        case .interstitialExit: return "ca-app-pub-3940256099942544/4411468910"
        case .rewardedCoin:     return "ca-app-pub-3940256099942544/5224354917"
        case .nativeFeed:       return "ca-app-pub-3940256099942544/2247696110"
        }
    }

    private var productionID: String {
        switch self {
        case .appOpen:          return "ca-app-pub-xxxx/yyyy_appopen"
        case .bannerHome:       return "ca-app-pub-xxxx/yyyy_banner_home"
        case .interstitialExit: return "ca-app-pub-xxxx/yyyy_interstitial_exit"
        case .rewardedCoin:     return "ca-app-pub-xxxx/yyyy_rewarded_coin"
        case .nativeFeed:       return "ca-app-pub-xxxx/yyyy_native_feed"
        }
    }
}
```

### 2. Initialize SDK

`configAds` runs three steps in order and only calls `completion` once all of them finish:

```
UMP consent  →  ATT  →  initialize SDK  →  completion
```

UMP must come before ATT: the UMP IDFA explainer message can only load while the tracking status is still `.notDetermined`, so requesting ATT first would permanently suppress it.

`completion` fires when ATT has actually resolved — not when `requestTrackingAuthorization`'s callback fires. Those differ: the callback returns immediately, reporting `.notDetermined` and presenting nothing, when the app is not yet `.active` or when a prompt queued by an earlier session is still unanswered. Trusting it would let the SDK initialize and ad requests start while the alert is still on screen. A 30s cap keeps a launch from stalling forever if the prompt never presents.

**Call it from a foreground view controller (e.g. your splash), not from `didFinishLaunching`** — both the UMP form and the ATT prompt need a live presenter:

```swift
final class SplashViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        AdMobHelper.shared.configAds(from: self) {
            // Consent gathered, ATT resolved, SDK initialized.
            // Only now is it safe to load ads or read Remote Config.
        }
    }
}
```

Full-screen ads (App Open, Interstitial, Rewarded, Rewarded Interstitial) refuse to present while the app is backgrounded — the show methods throw `AdMobHelperError.appInBackground` and keep the loaded ad for the next foreground attempt, instead of leaving a stuck loading overlay.

### 3. Banner

```swift
// Option A: Singleton-based
AdMobHelper.shared.loadBannerAd(
    into: bannerContainer,
    adUnitID: AppAdUnitID.bannerHome,
    rootViewController: self,
    statusCallback: { status in print("Banner: \(status)") }
)

// Option B: Self-contained (recommended for multiple banners)
let bannerAdView = BannerAdView()
bannerAdView.loadAd(adUnitID: AppAdUnitID.bannerHome, rootViewController: self)

// Collapsible banner
bannerAdView.loadAd(
    adUnitID: AppAdUnitID.bannerHome,
    rootViewController: self,
    isCollapsible: true,
    collapsiblePlacement: .bottom
)
```

### 4. Interstitial

```swift
try await AdMobHelper.shared.loadInterstitialAd(adUnitID: AppAdUnitID.interstitialExit)
try AdMobHelper.shared.showInterstitialAd(from: vc) { status in
    print("Interstitial: \(status)")
}
```

### 5. Rewarded

```swift
try await AdMobHelper.shared.showRewardedAd(
    from: vc,
    adUnitID: AppAdUnitID.rewardedCoin,
    statusCallback: { status in print("Rewarded: \(status)") },
    completion: { reward in print("Earned: \(reward.amount)") }
)
```

### 6. Native Ads

```swift
let nativeService = NativeAdService()
nativeService.loadNativeAd(
    containerView: nativeContainerView,
    adUnitID: AppAdUnitID.nativeFeed,
    rootViewController: self,
    viewType: .small,  // or .medium
    configuration: nil
) { success in print("Native loaded: \(success)") }

// Global theming
NativeAdConfiguration.shared.headlineFont = .systemFont(ofSize: 16, weight: .bold)
NativeAdConfiguration.shared.useGradientForCallToAction = true
NativeAdConfiguration.shared.callToActionGradientStartColor = .systemPurple
NativeAdConfiguration.shared.callToActionGradientEndColor = .systemPink
```

## In-App Purchases

```swift
// Define product IDs
enum AppProductID: String, IAPProductIdentifiable {
    case premiumMonthly = "com.yourapp.premium.monthly"
    var productIDString: String { rawValue }
}

// Fetch, purchase, restore
let products = try await IAPService.shared.fetchProducts([AppProductID.premiumMonthly])
let result = try await IAPService.shared.purchase(AppProductID.premiumMonthly)
let restored = try await IAPService.shared.restorePurchases()

// Check subscription
let isActive = IAPService.shared.isSubscriptionActive(for: AppProductID.premiumMonthly)
```

> **Note:** Subscription status is stored locally. Users must tap "Restore Purchases" on new devices.

## Revenue Attribution Setup

```swift
// Adjust
let adjConfig = AppADJustConfig(impressionToken: "TOKEN", token: "APP_TOKEN")
ADJustManager.shared.configure(with: adjConfig)

// TikTok
let ttConfig = TikTokAppConfig(appId: "APP_ID", tiktokAppId: "TT_APP_ID")
TikTokManager.shared.configure(with: ttConfig)

// Facebook & Firebase — auto-configured via Firebase/FB SDK setup
// Revenue tracking is automatic via paidEventHandler on all ad formats
```

## Documentation

| Document | Description |
|---|---|
| [Project Overview & PDR](docs/project-overview-pdr.md) | Product requirements and feature overview |
| [Codebase Summary](docs/codebase-summary.md) | Module map — where each concern lives |
| [Code Standards](docs/code-standards.md) | Naming conventions, architecture patterns, style guide |
| [System Architecture](docs/system-architecture.md) | Dependency graph, ad lifecycle flows, threading model |
| [Design Guidelines](docs/design-guidelines.md) | Native ad theming and loading UX |
| [Deployment Guide](docs/deployment-guide.md) | Release checklist, consumer setup, rollback |
| [Project Roadmap](docs/project-roadmap.md) | Shipped work and open items |
| [Native Ad Cache](NATIVE_AD_CACHE.md) | Native ad caching system details |

## License

MobileAds is released under the MIT license. See LICENSE for details.
