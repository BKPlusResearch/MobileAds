# MobileAds — System Architecture

## 1. High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                              Consumer App                              │
│        ┌─────────────┐                         ┌──────────────┐        │
│        │ AppAdUnitID │                         │ AppRemoteKey │        │
│        │   (enum)    │                         │    (enum)    │        │
│        └──────┬──────┘                         └───────┬──────┘        │
│               │                                        │               │
│      AdUnitIdentifiable                      RemoteKeyIdentifiable     │
│               │                                        │               │
├───────────────┼────────────────────────────────────────┼───────────────┤
│               ▼                                        ▼               │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    MobileAds Framework (Pod)                     │  │
│  │                                                                  │  │
│  │             ┌──────────────────────────────────────┐             │  │
│  │             │ SwiftUI layer (optional entry point) │             │  │
│  │             │ Representables + ViewModifiers       │             │  │
│  │             └───────────────────┬──────────────────┘             │  │
│  │                                 │ forwards to                    │  │
│  │ ┌─────────────┐  ┌──────────────▼─────┐  ┌─────────────────────┐ │  │
│  │ │ AdMobHelper │  │ EntitlementService │  │ RemoteConfigService │ │  │
│  │ │ (Singleton) │  │    (Singleton)     │  │     (Singleton)     │ │  │
│  │ └─────────────┘  └────────────────────┘  └─────────────────────┘ │  │
│  │        │                                                         │  │
│  │        ▼                                                         │  │
│  │ ┌─────────────────────────────────────────┐                      │  │
│  │ │         Revenue Attribution Hub         │                      │  │
│  │ │       (ADJustManager.logRevenue)        │                      │  │
│  │ └─────┬─────────┬─────────┬─────────┬─────┘                      │  │
│  │       │         │         │         │                            │  │
│  │       ▼         ▼         ▼         ▼                            │  │
│  │    Adjust   Firebase   TikTok   Facebook                         │  │
│  │      SDK    Analytics    SDK       SDK                           │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘

External SDKs:
  Google-Mobile-Ads-SDK │ Adjust │ Firebase │ TikTok │ Facebook
```

---

## 2. Module Dependency Graph

```
                    ┌──────────────┐
                    │  Consumer App │
                    └───────┬──────┘
                            │ imports MobileAds
                            ▼
          ┌─────────────────────────────────────┐
          │           AdMobHelper               │
          │  (Core: load/show/delegate ads)      │
          └──┬──────┬──────┬──────┬──────┬──────┘
             │      │      │      │      │
             ▼      │      │      │      │
     NativeAdService│      │      │      │
     BannerAdView   │      │      │      │
             │      │      │      │      │
             └──────┼──────┼──────┼──────┘
                    ▼      ▼      ▼
              ┌──────────────────────┐
              │   ADJustManager      │ ◄── Revenue hub
              └──┬──────┬──────┬────┘
                 │      │      │
        ┌────────┘      │      └────────┐
        ▼               ▼               ▼
  ┌───────────┐  ┌────────────┐  ┌────────────┐
  │ TikTok    │  │ Firebase   │  │ Facebook   │
  │ Manager   │  │ Logger     │  │ Manager    │
  └───────────┘  └────────────┘  └────────────┘

  Independent modules (no cross-dependencies):
  ┌────────────────────┐  ┌──────────────┐
  │ EntitlementService │  │ RemoteConfig │
  └────────────────────┘  └──────────────┘
```

---

## 3. Ad Lifecycle Flow

### 3.1 SDK Initialization

```
Foreground view controller (e.g. splash)
    │
    ▼
AdMobHelper.configAds(from: vc) ─────────── strictly sequential
    │
    ├─1─→ GoogleMobileAdsConsentManager.gatherConsent()
    │         └──→ UMP consent form shown (if needed)
    │
    ├─2─→ resolveTrackingAuthorization()
    │         ├──→ wait until app is .active (prompt cannot present otherwise)
    │         ├──→ ATTrackingManager.requestTrackingAuthorization
    │         └──→ wait until status leaves .notDetermined  ── 30s cap
    │
    ├─3─→ canRequestAds == true?
    │         └──→ MobileAds.shared.start(); isSDKInitialized = true
    │
    └─4─→ completion?()
```

Three ordering decisions are load-bearing here:

1. **UMP before ATT.** The UMP IDFA explainer message can only load while the tracking status is still `.notDetermined`. Requesting ATT first permanently suppresses that message.
2. **Status, not callback, is the authority.** `requestTrackingAuthorization`'s callback returns immediately — reporting `.notDetermined` and presenting nothing — when the app is not yet `.active`, or when a prompt queued by an earlier session is still unanswered. Treating it as "resolved" lets the SDK initialize and ad requests start while the alert is on screen.
3. **The caller must be a foreground view controller.** Both the UMP form and the ATT prompt need a live presenter, so `didFinishLaunching` is too early.

### 3.2 Full-Screen Ad Flow (Interstitial/Rewarded/AppOpen)

```
1. LOAD
   loadInterstitialAd(adUnitID:)
       │
       ├── Check: isInterstitialLoading? → return
       ├── Check: consent granted? → throw
       ├── isInterstitialLoading = true
       ├── AdMetricsTracker.trackRequest()
       │
       ├── InterstitialAd.load(adUnitID:request:)
       │       │
       │       ├── Success:
       │       │    interstitialAd = ad
       │       │    ad.fullScreenContentDelegate = self
       │       │    ad.paidEventHandler = { ADJustManager.logRevenue() }
       │       │    fullScreenAdUnitIDs[ObjectIdentifier(ad)] = adUnitID
       │       │    AdMetricsTracker.trackLoaded()
       │       │
       │       └── Failure:
       │            isInterstitialLoading = false
       │            AdMetricsTracker.trackLoadFailed()
       │            throw error
       │
       └── isInterstitialLoading = false

2. SHOW
   showInterstitialAd(from: vc, statusCallback:)
       │
       ├── Check: ad loaded? → throw .adNotLoaded
       ├── Check: app foregrounded? → hide overlay, throw .appInBackground
       │      (keeps the loaded ad for the next attempt — see note below)
       ├── isInterstitialShowing = true
       ├── Show loading overlay
       │
       ├── interstitialAd.present(from: vc)
       │       │
       │       ├── adWillPresentFullScreenContent()
       │       │    → hide loading, callback(.didPresent)
       │       │    → AdMetricsTracker.trackShow()
       │       │
       │       ├── adDidRecordImpression()
       │       │    → AdMetricsTracker.trackImpression()
       │       │
       │       ├── adDidRecordClick()
       │       │    → AdMetricsTracker.trackClick()
       │       │    → markAdClick() (for App Resume skip)
       │       │
       │       ├── adWillDismissFullScreenContent()
       │       │    → callback(.willDismiss)
       │       │
       │       └── adDidDismissFullScreenContent()
       │            → callback(.didDismiss)
       │            → cleanup (nil ad, reset flags)
       │
       └── On failure: callback(.didFailToPresent), cleanup
```

**Why the background check exists.** Presenting while backgrounded — e.g. an on-demand ad finishes loading after the user has left the app — leaves the ad half-presented: `adWillPresentFullScreenContent` never fires, so the loading overlay is never removed and the `is*Showing` flag stays stuck. The user returns to an ad they cannot dismiss. `.inactive` is deliberately still allowed, because resume App-Open ads present during that brief foreground transition.

### 3.3 Banner Ad Flow (BannerAdView — Self-Contained)

```
BannerAdView.loadAd(adUnitID:rootViewController:isCollapsible:)
    │
    ├── Already showing non-collapsible? → trackShow, return
    ├── Consent check → hide if denied
    │
    ├── Cache check (non-collapsible only):
    │    └── Cache hit + valid (<1hr)? → displayCached(), return
    │
    ├── Cache miss / Collapsible:
    │    ├── Show shimmer loading
    │    ├── Create new BannerView
    │    ├── Set paidEventHandler → ADJustManager.logRevenue()
    │    ├── AdMetricsTracker.trackRequest()
    │    ├── banner.load(request)
    │    │
    │    ├── bannerViewDidReceiveAd()
    │    │    → Cache banner entry
    │    │    → trackLoaded() + trackShow()
    │    │    → Hide shimmer
    │    │
    │    ├── bannerViewDidRecordImpression()
    │    │    → trackImpression()
    │    │    → Clear cache (force fresh on next load)
    │    │
    │    └── bannerView(didFailToReceiveAd:)
    │         → trackLoadFailed()
    │         → Clear cache, hide view
    │
    └── clearAd() → cleanup, hide (cache preserved)
```

### 3.4 Native Ad Flow

```
NativeAdService.loadNativeAd(containerView:adUnitID:viewType:)
    │
    ├── Clear container subviews
    ├── Show loading view (Small or Medium shimmer)
    │
    ├── Create NativeAdLoaderDelegateHelper
    │    ├── onAdLoaded: { nativeAd in
    │    │    → Remove shimmer
    │    │    → Load XIB (NativeAdViewSmall or NativeAdViewMedium)
    │    │    → setupNativeAdView() (populate data + apply config)
    │    │    → Add to container
    │    │    → Optional: cache with key
    │    │    → statusCallback?(true)
    │    │ }
    │    └── onAdFailed: { error in
    │         → Remove shimmer
    │         → statusCallback?(false)
    │     }
    │
    └── AdMobHelper.loadNativeAd() → returns AdLoader
```

---

## 4. Revenue Attribution Pipeline

```
┌──────────────────────────────────────────────────┐
│           Ad Impression Received                  │
│   (paidEventHandler / bannerPaidEventHandler)     │
└─────────────────────┬────────────────────────────┘
                      │
                      ▼
         ADJustManager.logRevenue(adType, adValue)
                      │
         ┌────────────┼────────────┬────────────┐
         │            │            │            │
         ▼            ▼            ▼            ▼
    ┌─────────┐  ┌─────────┐  ┌────────┐  ┌─────────┐
    │ Adjust  │  │Firebase │  │ TikTok │  │Facebook │
    │ SDK     │  │Analytics│  │ SDK    │  │ SDK     │
    ├─────────┤  ├─────────┤  ├────────┤  ├─────────┤
    │ADJAdRev │  │logEvent │  │InApp   │  │AD_IMPR  │
    │+ Event  │  │ad_impr  │  │ADImpr  │  │event    │
    │(token)  │  │         │  │+AdRev  │  │         │
    └─────────┘  └─────────┘  └────────┘  └─────────┘
```

---

## 5. Entitlement Verification Flow

```
Host: configure(productIDs:)          required, once, before bootstrap
  │
Host: bootstrap()                     returns immediately — NOT async
  │
  ├── timeout armed first (5s) ───────────────┐
  │                                           │
  ├── loadProducts()  ‖  verify()             │  concurrent
  │                        │                  │
  │                        ▼                  │
  │        Transaction.currentEntitlements    │
  │        drop: unverified, revoked,         │
  │              unconfigured productID,      │
  │              consumable, expired          │
  │                        │                  │
  │                        ▼                  │
  │        publish() → verification = .verified
  │                                           │
  └── still .pending at 5s ───────────────────┴──► verification = .timedOut
                                                   (host policy; default: treat
                                                    as free and show ads)

Transaction.updates listener (process-lifetime)
  ├── .verified   → finish() → refresh(force:)
  └── .unverified → log → finish()   (grants nothing either way)
```

Two invariants worth preserving:

- `verification = .verified` is assigned in exactly one function, `publish()`, and only after `currentEntitlements` has been read to completion. A timeout never stamps "verified" onto an unchecked value.
- No entitlement value is persisted anywhere, so there is nothing on disk to tamper with and no unverified value that can reach a decision. The cost is that a subscriber sees free UI for a few tens of ms on each launch.

`verify()` carries a generation token: `@MainActor` does not serialize across `await`, so without it a stale verification could overwrite the result of a purchase that just completed.

---

## 6. Data Storage

| Data | Storage | Module |
|---|---|---|
| Entitlement (`EntitlementService`) | **Not stored** — re-derived from `Transaction.currentEntitlements` on every check | IAP |
| Restore-prompt flag | UserDefaults (`mobileads.entitlement.restorePrompted`) | IAP |
| Remote config values | Firebase Remote Config cache | RemoteConfig |
| Ad cache (banner) | In-memory static dictionary | BannerAdView |
| Ad cache (native) | In-memory dictionary | AdMobHelper+NativeCache |
| Ad metrics | In-memory dictionary | AdMetricsTracker |
| Consent status | UMP SDK internal | ConsentManager |

---

## 7. Threading Model

```
┌─────────────────────────────────────┐
│            Main Thread              │
│  @MainActor                         │
│                                     │
│  AdMobHelper.shared                 │
│  NativeAdService                    │
│  NativeAdConfiguration.shared       │
│  EntitlementService.shared          │
│  (listener runs here too —          │
│   process-lifetime, never           │
│   cancelled)                        │
│  AdMetricsTracker.shared            │
│  All UIView subclasses              │
│  All ad lifecycle callbacks         │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│    Any Thread (Thread-Safe)         │
│                                     │
│  ADJustManager.shared               │
│  TikTokManager.shared               │
│  FacebookManager.shared             │
│  FirebaseLogger.shared              │
│  RemoteConfigService.shared         │
└─────────────────────────────────────┘
```

---

## 8. Integration Points

### App → Framework

| Integration | Entry Point |
|---|---|
| SDK initialization | `AdMobHelper.shared.configAds(from:)` |
| Load/show ads | `AdMobHelper.shared.load{Type}Ad(...)` / `.show{Type}Ad(...)` |
| Self-contained banner | `BannerAdView().loadAd(...)` |
| Native ads | `NativeAdService().loadNativeAd(...)` |
| Native ad theming | `NativeAdConfiguration.shared.{property} = ...` |
| IAP | `EntitlementService.shared.configure(...)` → `.bootstrap()` → `.purchase(...)` |
| Remote Config | `RemoteConfigService.shared.fetchCloudValues(...)` |
| Adjust setup | `ADJustManager.shared.configure(with:)` |
| TikTok setup | `TikTokManager.shared.configure(with:)` |
| Ad enable/disable | `AdMobHelper.shared.setEnableShowAds(false)` |

### SwiftUI → Framework

| Integration | Entry Point |
|---|---|
| Banner / Native | `BannerAdSwiftUI(...)` / `NativeAdSwiftUI(...)` |
| Full-screen formats | `.interstitialAd(...)`, `.rewardedAd(...)`, `.rewardedInterstitialAd(...)`, `.appOpenAd(...)` |
| Presenter lookup | `ViewControllerResolver` (used internally by the modifiers) |
| IAP state | `@StateObject EntitlementService.shared` |

These are wrappers, not a parallel implementation: they resolve to the same singletons above, so cache, metrics, and revenue attribution behave identically from either surface.

### Framework → External SDKs

| Direction | SDK | Purpose |
|---|---|---|
| Out | Google Mobile Ads | Ad loading, display, consent |
| Out | Adjust | Revenue attribution, event tracking |
| Out | Firebase Analytics | Ad impression events, user properties |
| Out | Firebase Remote Config | Feature flags, A/B testing |
| Out | Firebase Crashlytics | Crash reporting (dependency only) |
| Out | TikTok Business SDK | Attribution, ad revenue postback |
| Out | Facebook SDK | AD_IMPRESSION event logging |
| Out | Apple StoreKit | In-app purchases, transaction verification |
