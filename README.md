# MobileAds

A Swift framework for iOS monetization — wraps Google Mobile Ads SDK, StoreKit 2 IAP, and unified revenue attribution (Adjust, Firebase, TikTok, Facebook).

## Features

- **All AdMob formats** — Banner, Interstitial, Rewarded, Rewarded Interstitial, App Open, Native (Small/Medium)
- **UIKit and SwiftUI** — Same ads from either surface; SwiftUI gets `UIViewRepresentable` views, `.interstitialAd`/`.rewardedAd`/`.rewardedInterstitialAd`/`.appOpenAd` modifiers, and `IAPViewModel` (legacy IAP layer — see [In-App Purchases](#in-app-purchases) before gating ads on it)
- **AdMob mediation** — AppLovin, IronSource, Vungle, Facebook, Mintegral, Pangle, Unity adapters bundled
- **Self-contained `BannerAdView`** — Drop-in UIView, no singleton conflicts for multiple banners
- **Native Ad Cache** — Preload for instant display with 1-hour auto-expiry
- **In-App Purchases** — Two layers: `EntitlementService` (entitlements-first, recommended for new apps) and the legacy `IAPService`. Pick one per app; never both
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

The pod ships **two independent IAP layers**. Choose one per app.

| Layer | Use when | Status |
|---|---|---|
| `EntitlementService` | New apps | Recommended. **Not yet exercised on a device** — see below |
| `IAPService` / `IAPViewModel` | The four apps already on it | Frozen. Entitlement is read from `UserDefaults` — **premium is lost on reinstall**, and Ask to Buy is reported as an error |

> **Never use both in one app.** Simply creating an `IAPViewModel` constructs `IAPService.shared` and starts its own `Transaction.updates` listener, so the two layers end up with two sources of truth that drift apart and finish each other's transactions.

### EntitlementService (recommended)

Entitlement is derived from `Transaction.currentEntitlements` on every check, so reinstalls, device changes, refunds, grace periods and Family Sharing are all handled by StoreKit rather than by local storage. The layer is generic: it holds no product IDs of its own and never presents UI — the host supplies configuration and builds its own paywall.

> **Status: not verified on a device.** This layer is written against the StoreKit 2 documentation, and no app has run it yet. It has been through a red-team pass and a code review, both of which found real defects by reading alone — so assume the ones that only surface at runtime are still there. There is no StoreKit test configuration in this repo, which makes the checklist below the only control that exists. **If you are the first integrator, please run it and report the results.**

#### 1. Configure — once, before `bootstrap()`

```swift
EntitlementService.shared.configure(
    EntitlementConfig(productIDs: ["your.weekly", "your.yearly"],
                      subscriptionGroupID: "your_group")
)
```

`productIDs` is required and has no default. There is no "empty means accept everything" mode: `currentEntitlements` also emits unfinished consumables and expired non-renewing purchases, so a permissive set would let a coin pack grant permanent access.

If product IDs come from Remote Config, **fetch first, then configure** — the service decides nothing until it is configured, and it refuses to be reconfigured afterwards.

#### 2. Bootstrap at launch

```swift
EntitlementService.shared.bootstrap()   // NOT async — deliberately
```

It returns immediately so the first frame can never block on StoreKit. Observe `verification` instead of awaiting anything.

#### 3. Refresh on foreground

```swift
await EntitlementService.shared.refresh()   // 30s debounce built in
```

#### Reading state

```swift
@ObservedObject private var entitlements = EntitlementService.shared

var body: some View {
    Group {
        if entitlements.verification == .verified && entitlements.isEntitled {
            PremiumContent()
        } else {
            FreeContent()
                .appOpenAd(adUnitID: AppAdUnitID.appOpen,
                           isEnabled: !entitlements.isEntitled)
        }
    }
}
```

| Property | Meaning |
|---|---|
| `verification` | `.pending` / `.verified` / `.timedOut` — has StoreKit answered? |
| `isEntitled` | Holds a configured product. Only meaningful once `.verified` |
| `activeProductID` | Which configured product granted access |
| `expiryDate` | `nil` for lifetime/non-consumable — **`nil` is not "expired"** |
| `isIntroOfferEligible` | `false` until the catalog loads and eligibility resolves. Still check the specific product's `introductoryOffer` before printing trial copy |
| `products` | Loaded `Product`s by ID; `displayPrice(for:)` for the localized price |
| `shouldProactivelyPromptRestore` | Whether to *suggest* restoring — **not** whether to show the button |

```swift
switch await EntitlementService.shared.purchase("your.yearly") {
case .purchased:        dismissPaywall()
case .cancelled:        break
case .pending:          showAwaitingApprovalMessage()   // Ask to Buy — not an error
case .failed(let why):  log(why)
}

switch await EntitlementService.shared.restore() {
case .restored:          dismissPaywall()
case .nothingToRestore:  showNothingToRestore()
case .cancelled:         break                          // sign-in dismissed — not an error
case .failed(let why):   showError(why)
}
```

#### Five traps

1. **Unlock only when `verification == .verified`.** `.pending` means *not known yet*; `.timedOut` means StoreKit did not answer within 5s. **Recommended default at `.timedOut`: treat the user as free and show ads.** That favors revenue; the cost is that a subscriber on a bad network sees ads for a few seconds until `verify()` answers, then they disappear. Choose differently only with a reason.
2. **Nothing is cached — anywhere.** There is no stored entitlement and no "last known" state. `isEntitled` is `false` until verification completes, even for a long-standing subscriber. **Do not add a cache on the host side to smooth this over** — that is precisely the defect the legacy layer has.
3. **With `@Observable` (iOS 17+), mirror — do not forward.** `var isPremium: Bool { base.isEntitled }` compiles but the UI **never updates**, because `@Observable` does not track an `ObservableObject`'s `objectWillChange`. Sink the `@Published` values into stored properties instead.
4. **Do not mix with `IAPService` / `IAPViewModel`.** See the warning above — constructing `IAPViewModel` alone is enough to start the second listener.
5. **The Restore button must always be visible.** `shouldProactivelyPromptRestore` only answers "should I proactively suggest it". Gating the button itself on that flag is a direct path to a Guideline 3.1.1 rejection. Call `markRestorePrompted()` after showing your own suggestion UI.

#### Sandbox checklist for the first integrator

| # | Case | Expected |
|---|---|---|
| 1 | Purchase | Entitled immediately, UI updates without restart |
| 2 | Kill and relaunch | Still entitled |
| 3 | Delete app, reinstall, tap nothing | Entitled within ~1s |
| 4 | Refund via StoreKit Transaction Manager | Access lost after refresh |
| 5 | Ask to Buy | Outcome `.pending`, not an error |
| 6 | Sign in with a different Apple ID | Access lost |
| 7 | Restore in case 6 | Sign-in prompt appears |
| 8 | Airplane mode, device **had** verified before | Still entitled — `currentEntitlements` is served from StoreKit's on-device transaction cache |
| 9 | Airplane mode + **fresh install** | `verification` becomes `.timedOut` after 5s; by the default policy the host shows ads |
| 10 | Non-consumable / lifetime | Entitled permanently, `expiryDate` is `nil` |
| 11 | **Consumable** (if the app sells one) | Grants **no** entitlement, yet `purchase()` still returns `.purchased` |
| 12 | **Intro offer** — 2+ products, only one with a trial | `isIntroOfferEligible` answers for the right product, consistently across runs |
| 13 | **Purchase while a verify is in flight** | Access is not lost once the purchase completes |
| 14 | **Second launch as a subscriber** | Free UI for a few tens of ms, then premium. Report back if the flicker is objectionable |
| 15 | **Subscription group where no product has an introductory offer** | `isIntroOfferEligible` stays `false` — never a trial badge on a plan that bills immediately |
| 16 | **Launch offline, reconnect, then open the paywall immediately** (inside the 30s debounce) | **All** prices appear and `purchase()` works. Buying one plan must not leave the others priceless for the rest of the session |

Case 3 is the reason this layer exists. Cases 11–13 are defects the red-team pass found and 15–16 are defects the code review found; dropping any of them discards the value of those reviews. Case 14 measures the cost of having no cache.

Two further cases need a host that can cancel: calling `refresh()` from a `.task {}` that is cancelled mid-flight must not drop a subscriber to free, and calling `bootstrap()` before `configure()` must leave `bootstrap()` still usable afterwards rather than wedging `verification` at `.pending`.

### IAPService (legacy)

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

> **Note:** Subscription status is stored locally, so **premium is lost on reinstall or on a new device** until the user taps "Restore Purchases", and a `.pending` (Ask to Buy) purchase is surfaced as an error. New apps should use `EntitlementService` instead.

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
