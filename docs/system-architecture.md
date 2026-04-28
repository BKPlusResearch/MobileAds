# MobileAds — System Architecture

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Consumer App                             │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ AppAdUnitID   │  │ AppProductID │  │ AppRemoteKey      │  │
│  │ (enum)        │  │ (enum)       │  │ (enum)            │  │
│  └──────┬───────┘  └──────┬───────┘  └─────────┬─────────┘  │
│         │                 │                     │            │
│    AdUnitIdentifiable  IAPProductIdentifiable  RemoteKeyIdentifiable
│         │                 │                     │            │
├─────────┼─────────────────┼─────────────────────┼────────────┤
│         ▼                 ▼                     ▼            │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              MobileAds Framework (Pod)                  │ │
│  │                                                         │ │
│  │  ┌─────────────┐  ┌──────────┐  ┌──────────────────┐   │ │
│  │  │ AdMobHelper  │  │IAPService│  │RemoteConfigService│  │ │
│  │  │  (Singleton) │  │(Singleton)│  │   (Singleton)    │   │ │
│  │  └──────┬──────┘  └──────────┘  └──────────────────┘   │ │
│  │         │                                               │ │
│  │         ▼                                               │ │
│  │  ┌──────────────────────────────────────────────┐       │ │
│  │  │         Revenue Attribution Hub              │       │ │
│  │  │         (ADJustManager.logRevenue)            │       │ │
│  │  └──┬──────┬──────────┬───────────┬─────────────┘       │ │
│  │     │      │          │           │                     │ │
│  │     ▼      ▼          ▼           ▼                     │ │
│  │  Adjust  Firebase   TikTok    Facebook                  │ │
│  │  Manager  Logger    Manager   Manager                   │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

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
  ┌──────────────┐  ┌──────────┐
  │ IAPService   │  │RemoteConfig│
  └──────────────┘  └──────────┘
```

---

## 3. Ad Lifecycle Flow

### 3.1 SDK Initialization

```
App Launch
    │
    ▼
AdMobHelper.configAds(from: vc)
    │
    ├──→ GoogleMobileAdsConsentManager.gatherConsent()
    │        │
    │        ├──→ UMP consent form shown (if needed)
    │        │
    │        └──→ canRequestAds == true?
    │                  │
    │                  ▼
    │             MobileAds.shared.start()
    │             isSDKInitialized = true
    │
    └──→ completion?()
```

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

## 5. Data Storage

| Data | Storage | Module |
|---|---|---|
| Subscription status | UserDefaults (migrated from Keychain) | IAP |
| Subscription info (legacy) | Keychain | IAP |
| Remote config values | Firebase Remote Config cache | RemoteConfig |
| Ad cache (banner) | In-memory static dictionary | BannerAdView |
| Ad cache (native) | In-memory dictionary | AdMobHelper+NativeCache |
| Ad metrics | In-memory dictionary | AdMetricsTracker |
| Consent status | UMP SDK internal | ConsentManager |

---

## 6. Threading Model

```
┌─────────────────────────────────────┐
│            Main Thread              │
│  @MainActor                         │
│                                     │
│  AdMobHelper.shared                 │
│  NativeAdService                    │
│  NativeAdConfiguration.shared       │
│  IAPService.shared                  │
│  AdMetricsTracker.shared            │
│  All UIView subclasses              │
│  All ad lifecycle callbacks         │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│          Background Thread          │
│                                     │
│  IAPService transaction listener    │
│  (Task.detached for                 │
│   Transaction.updates)              │
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

## 7. Integration Points

### App → Framework

| Integration | Entry Point |
|---|---|
| SDK initialization | `AdMobHelper.shared.configAds(from:)` |
| Load/show ads | `AdMobHelper.shared.load{Type}Ad(...)` / `.show{Type}Ad(...)` |
| Self-contained banner | `BannerAdView().loadAd(...)` |
| Native ads | `NativeAdService().loadNativeAd(...)` |
| Native ad theming | `NativeAdConfiguration.shared.{property} = ...` |
| IAP | `IAPService.shared.purchase(...)` |
| Remote Config | `RemoteConfigService.shared.fetchCloudValues(...)` |
| Adjust setup | `ADJustManager.shared.configure(with:)` |
| TikTok setup | `TikTokManager.shared.configure(with:)` |
| Ad enable/disable | `AdMobHelper.shared.setEnableShowAds(false)` |

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
