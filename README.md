# MobileAds

A Swift framework for iOS monetization — wraps Google Mobile Ads SDK, StoreKit 2 IAP, and unified revenue attribution (Adjust, Firebase, TikTok, Facebook).

## Features

- **All AdMob formats** — Banner, Interstitial, Rewarded, Rewarded Interstitial, App Open, Native (Small/Medium)
- **UIKit and SwiftUI** — Same ads from either surface; SwiftUI gets `UIViewRepresentable` views and `.interstitialAd`/`.rewardedAd`/`.rewardedInterstitialAd`/`.appOpenAd` modifiers
- **AdMob mediation** — AppLovin, IronSource, Vungle, Facebook, Mintegral, Pangle, Unity adapters bundled
- **Self-contained `BannerAdView`** — Drop-in UIView, no singleton conflicts for multiple banners
- **Native Ad Cache** — Preload for instant display with 1-hour auto-expiry
- **In-App Purchases** — `EntitlementService`: entitlement derived from StoreKit on every check, never cached, with an `onUnfinished` delivery hook for consumables
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
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git", :tag => '2.0.0'

# Last release with the legacy IAPService layer (see "Upgrading from 1.x to 2.0")
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git", :tag => '1.4.0'
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

`EntitlementService` is the pod's only IAP layer. The legacy `IAPService` / `IAPViewModel`
layer was **removed in 2.0.0** — see [Upgrading from 1.x to 2.0](#upgrading-from-1x-to-20).

### EntitlementService

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
case .purchased(let receipt):
    // Do NOT credit consumables here — `onUnfinished` has already been offered this
    // transaction and is the one place to credit. See "Consumables".
    dismissPaywall()
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
2. **Nothing is cached — anywhere.** There is no stored entitlement and no "last known" state. `isEntitled` is `false` until verification completes, even for a long-standing subscriber. **Do not add a cache on the host side to smooth this over** — that is precisely the defect the removed 1.x layer had, and the reason it was removed.
3. **With `@Observable` (iOS 17+), mirror — do not forward.** `var isPremium: Bool { base.isEntitled }` compiles but the UI **never updates**, because `@Observable` does not track an `ObservableObject`'s `objectWillChange`. Sink the `@Published` values into stored properties instead.
4. **One `Transaction.updates` listener per app.** This layer runs one. If the app keeps its own — a subscription tracker, an analytics observer — the two finish each other's transactions and drift apart. Retire the app's listener, or route it through `onUnfinished`.
5. **The Restore button must always be visible.** `shouldProactivelyPromptRestore` only answers "should I proactively suggest it". Gating the button itself on that flag is a direct path to a Guideline 3.1.1 rejection. Call `markRestorePrompted()` after showing your own suggestion UI.

#### Consumables — you must supply `onUnfinished`

An app selling only subscriptions or non-consumables can stop reading here. An app
selling coin packs, credits, or lives **must** supply `onUnfinished`, or it will charge
customers and deliver nothing.

**Why crediting at the `purchase()` return is not enough.** It is tempting to credit coins
where `purchase()` returns and call it done. But StoreKit delivers consumables through
`Transaction.updates` — where no `purchase()` call is waiting — in at least four ordinary
situations:

- the app was killed or crashed between payment and delivery;
- Ask to Buy was approved by a parent minutes or days later;
- the purchase started on another device on the same Apple ID;
- a previous delivery attempt was interrupted.

In every one of those the library sees a transaction the host never sees. Without the
hook it finishes and discards it. **A consumable never enters `currentEntitlements`**, so
unlike a subscription there is nothing left to re-derive from: the money is gone and the
coins never existed.

`onUnfinished` covers **both** routes: `purchase()` offers its transaction to the same
hook before finishing it. So there is exactly one place to credit, and it catches
everything.

```swift
EntitlementService.shared.configure(
    EntitlementConfig(
        // Coin SKUs must be listed here too — purchase() rejects anything absent.
        // Listing them does NOT let them grant premium; verify() filters consumables
        // by Transaction.productType.
        productIDs: ["your.weekly", "your.yearly", "your.coins.100"],
        subscriptionGroupID: "your_group",
        onUnfinished: { receipt in
            // Write the credit BEFORE returning true, and de-duplicate on transactionID.
            await CoinLedger.creditOnce(receipt.transactionID, productID: receipt.productID)
        }
    )
)
```

The contract, and each clause is load-bearing:

| Rule | What goes wrong otherwise |
|---|---|
| Persist the credit **before** returning `true` | Crash between the two and you have reintroduced the exact loss the hook prevents |
| De-duplicate on `receipt.transactionID` | StoreKit redelivers; crediting per delivery double-credits |
| Credit **only** here | Every consumable is offered to this hook exactly once, including the ones bought in the foreground through `purchase()`. Also crediting at the `purchase()` return credits twice |
| Make the credit write atomic | A read-then-write across an actor hop or an App Group `UserDefaults` shared with a widget loses concurrent credits |
| Return `false` **only** when the write genuinely failed | It is not an error channel. A permanent `false` means permanent redelivery |

The hook is deliberately **not** called for:

| Not called for | Why |
|---|---|
| Subscriptions and non-consumables | Entitlement re-derives from `currentEntitlements`, so finishing them loses nothing. If the hook saw renewals, a host rejecting an unrecognized product would wedge that renewal in permanent redelivery |
| Revoked / refunded transactions | Delivering goods for a refund is a giveaway. `refresh()` still runs, so the entitlement drops correctly |
| Transactions that fail verification | Honoring them grants goods against unverifiable proof |

**Known gap:** because of the last row, a charged-but-unverifiable consumable is still
lost. Closing that properly requires server-side receipt validation, which this library
does not do.

Two behaviors worth knowing:

- **Transactions arriving before `configure()` are left unfinished**, not discarded, and
  are retried once the app configures. Finishing them would be unrecoverable.
- **`bootstrap()` re-offers anything still unfinished** from previous sessions, so
  returning `false` is a retry rather than a one-way trip.

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
| 11 | **Consumable** (if the app sells one) | Grants **no** entitlement, yet `purchase()` still returns `.purchased(receipt)` |
| 12 | **Intro offer** — 2+ products, only one with a trial | `isIntroOfferEligible` answers for the right product, consistently across runs |
| 13 | **Purchase while a verify is in flight** | Access is not lost once the purchase completes |
| 14 | **Second launch as a subscriber** | Free UI for a few tens of ms, then premium. Report back if the flicker is objectionable |
| 15 | **Subscription group where no product has an introductory offer** | `isIntroOfferEligible` stays `false` — never a trial badge on a plan that bills immediately |
| 16 | **Launch offline, reconnect, then open the paywall immediately** (inside the 30s debounce) | **All** prices appear and `purchase()` works. Buying one plan must not leave the others priceless for the rest of the session |
| 17 | **Consumable bought in the foreground** (consumable sellers only) | `onUnfinished` fires once; coins credited once; `purchase()` returns `.purchased(receipt)` |
| 18 | **Consumable, app killed mid-purchase** | Coins credited on the next launch via `onUnfinished`, exactly once |
| 19 | **Consumable via Ask to Buy, approved after relaunch** | Coins credited once approval arrives, exactly once |
| 20 | **`onUnfinished` returns `false`** | Transaction NOT finished; re-offered at the next `bootstrap()` |
| 21 | **Refund a consumable via StoreKit Transaction Manager** | `onUnfinished` does **not** fire again; no extra coins credited |
| 22 | **Subscription renews while `onUnfinished` is supplied** | Hook does **not** fire; renewal finishes; `expiryDate` updates |
| 23 | **Transaction arrives before `configure()`** | Left unfinished, then credited after `configure()` + `bootstrap()` |

Case 3 is the reason this layer exists. Cases 11–13 are defects the red-team pass found, 15–16 came from the first code review, and 17–23 from the review of the 2.0 delivery hook — each one is a specific way money went missing on paper; dropping any of them discards the value of those reviews. Case 14 measures the cost of having no cache.

Two further cases need a host that can cancel: calling `refresh()` from a `.task {}` that is cancelled mid-flight must not drop a subscriber to free, and calling `bootstrap()` before `configure()` must leave `bootstrap()` still usable afterwards rather than wedging `verification` at `.pending`.

### Upgrading from 1.x to 2.0

**2.0.0 removed the legacy IAP layer.** `IAPService`, `IAPViewModel`,
`IAPProductIdentifiable`, `IAPError`, `ProductType`, and the Keychain/UserDefaults
storage behind them no longer exist. An app on 1.x will not compile against 2.0 until it
migrates. Staying on 1.x is a valid choice — pin `:tag => '1.4.0'`.

Why it went: entitlement was read from local storage, so **premium was lost on reinstall
or on a new device** until the user found "Restore Purchases", and Ask to Buy was
reported to the user as an error.

API mapping:

| 1.x | 2.0 |
|---|---|
| `IAPService.shared.hasActiveSubscription()` | `EntitlementService.shared.isEntitled` |
| `IAPService.shared.fetchProducts(_:)` | `configure()` + `bootstrap()`, then read `products` |
| `IAPService.shared.purchase(_:)` | `EntitlementService.shared.purchase(id)` → outcome |
| `IAPService.shared.restorePurchases()` | `EntitlementService.shared.restore()` |
| `IAPService.shared.sharedSecret = …` | Removed. Rotating the secret is a separate task — deleting this line does not invalidate it |
| `catch IAPError.purchaseCancelled` | `case .cancelled` |
| `catch let e as IAPError` | `case .failed(let failure)` |
| `ProductType` | Declare it app-side; the pod no longer vends one |

**Already on `EntitlementService` from 1.4.0?** One source-breaking change affects you too:
`EntitlementPurchaseOutcome.purchased` now carries a payload.

| 1.4.0 | 2.0 |
|---|---|
| `case .purchased` | `case .purchased(let receipt)` — the payload-less pattern still compiles, but `outcome == .purchased` no longer does |
| `EntitlementConfig(productIDs:subscriptionGroupID:)` | Unchanged; `onUnfinished:` is a new optional third parameter |

**The trap that will cost you a day: `isEntitled` is not synchronous.**
`hasActiveSubscription()` read `UserDefaults`, so it always had an answer immediately.
`isEntitled` is `false` until verification completes. Every ad gate and paywall check
that runs at launch will see `false` and show ads to a paying subscriber.

A `-> Bool` shim cannot fix this. The gate has to distinguish "not premium" from "don't
know yet", and something has to notify the UI when the answer arrives:

```swift
// Gate must be able to say "unknown"
static func premiumState() -> (isPremium: Bool, isKnown: Bool) {
    let service = EntitlementService.shared
    return (service.isEntitled, service.verification == .verified)
}

// Without a bridge the UI reads once and never updates again
static func startBridge() {
    cancellable = EntitlementService.shared.$isEntitled
        .removeDuplicates()
        .sink { _ in NotificationCenter.default.post(name: .premiumStatusDidChange, object: nil) }
}
```

`startBridge()` must be called explicitly — a `static` on an `enum` is a lazy global and
never runs if nothing touches it.

Bridging to RxSwift: sink `$isEntitled`. Do **not** use `objectWillChange` — it fires in
`willSet` and carries no value, so the relay stays one step behind. It compiles cleanly,
so no build check will catch it.

Selling consumables? Read [Consumables](#consumables--you-must-supply-onunfinished)
before starting; `onUnfinished` is mandatory there.

Per-app migration notes, including known traps in each existing consumer, are in the pod
repo under `plans/260814-1621-remove-legacy-iap/plan.md` ("Migration notes").

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
