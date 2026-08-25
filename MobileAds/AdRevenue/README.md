# AdRevenue

`AdRevenueManager` is the single place an AdMob paid event fans out to every analytics/attribution
surface the pod integrates. Source: `MobileAds/AdRevenue/AdRevenueManager.swift`.

## Why it exists

Each ad format's `paidEventHandler` would otherwise have to call three SDKs by hand, with three
chances to drift. One call site per format keeps the destinations — and the value/currency
conversion — identical across banner, interstitial, rewarded, rewarded interstitial, app open and
native.

Destinations (see the methods each name points at):

| Destination | Owner |
|---|---|
| Firebase Analytics | `FirebaseLogger.logEvent(.adImpression, ...)` |
| TikTok Business SDK | `TikTokManager.trackAdRevenue` / `trackAdRevenueEvent` |
| Facebook SDK `AD_IMPRESSION` | `FacebookManager.logAdImpression` |

Nothing here is configured. Each destination SDK is initialized by its own manager, so the pod has
no attribution tokens and no init order to get wrong.

## Using it

Already wired: `AdMobHelper+*` and `BannerAdView` attach `paidEventHandler` on every format, so a
consumer app gets revenue tracking without writing any code.

Ads loaded outside the facade attach it themselves:

```swift
interstitialAd?.paidEventHandler = { adValue in
    AdRevenueManager.shared.logRevenue(adType: .interstitial, adValue: adValue)
}
```

Prefer the `adUnitId:responseInfo:` overload where a `ResponseInfo` is available — it forwards
mediation source and A/B test metadata that TikTok uses for attribution. `NativeAdLoaderDelegateHelper`
shows the pattern.

`AdType` is also the ad-type key used by `AdMetricsTracker`, `TikTokManager` and `FacebookManager`.

## Migrating from 2.0.0

2.0.1 removed the Adjust SDK integration. The pod no longer depends on Adjust; an app that still
uses it adds `pod 'Adjust'` to its own Podfile and calls the SDK directly.

| 2.0.0 | 2.0.1 |
| --- | --- |
| `ADJustManager.shared` | `AdRevenueManager.shared` |
| `ADJAdType` | `AdType` |
| `AppADJustConfig` | removed |
| `configure(with:delegate:)` | removed — nothing to configure |
| `trackEvent(_:revenue:currency:)` | removed — call the Adjust SDK from the app |
| `trackPurchase(...)` | removed (never did anything but log) |
