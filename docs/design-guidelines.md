# Design Guidelines

**Last updated:** 2026-07-26 · Scope: native ad visual theming and loading UX exposed by the framework.

MobileAds is a code framework, but it ships opinionated, themeable native ad UI. This doc covers the visual surface consumers can customize.

## Native Ad Theming — `NativeAdConfiguration.shared`

A single global configuration singleton drives the look of **all** native ads (cached and network). Set it once, typically in `AppDelegate`.

Customizable properties include:

- **Typography:** `headlineFont`, `bodyFont`.
- **Colors:** `backgroundColor`, text colors, `borderColor`, `borderWidth`.
- **Call-to-action button:** solid color, or gradient via `useGradientForCallToAction`, `callToActionGradientStartColor`, `callToActionGradientEndColor`.

```swift
NativeAdConfiguration.shared.headlineFont = .systemFont(ofSize: 16, weight: .bold)
NativeAdConfiguration.shared.useGradientForCallToAction = true
NativeAdConfiguration.shared.callToActionGradientStartColor = .systemPurple
NativeAdConfiguration.shared.callToActionGradientEndColor = .systemPink
```

Per-load overrides are possible via the `configuration:` parameter on `NativeAdService.loadNativeAd` / `loadNativeAdWithCache` (pass `nil` to use the shared config).

## Native Ad Templates

XIB-backed `NativeAdView` subclasses, selected via `NativeAdService.NativeAdViewType`:

| Type | View | Use |
|------|------|-----|
| `.small` | `NativeAdViewSmall` | Compact row: icon/media + headline + body + CTA (`mainStackView` layout). |
| `.medium` | `NativeAdViewMedium` | Larger card with media view. |

## Loading / Skeleton UX

Every format ships a loading state so ad slots never show empty:

- **Banner:** `BannerAdView` embeds shimmer loading (`BannerAdLoadingView`) automatically; skip-if-loaded prevents double loads; `clearAd()` hides on premium/cell-reuse.
- **Native:** `NativeAdSmallLoadingView`, `NativeAdMediumLoadingView`, `NativeAdLoadingView` (SkeletonView shimmer).
- **Full-screen:** `AppOpenAdLoadingView` overlay reused for interstitial/rewarded transitions.

## UX Principles Baked In

1. **No empty slots** — always show a loading placeholder while fetching.
2. **Instant native display** — preload cache eliminates visible loading on key screens (onboarding, first language). See `NATIVE_AD_CACHE.md`.
3. **Premium respect** — `BannerAdView.clearAd()`, `AdMobHelper.clearAllAds()` and the SwiftUI `isEnabled:` parameters let apps cleanly suppress ads for paying users. The pod owns no global on/off flag; the app gates its own call sites.
4. **Consistent theming** — one `NativeAdConfiguration` keeps every native ad on-brand app-wide.

## Notes

Consumers own overall app design; this framework only styles ad units. Keep ad theming aligned with host-app brand tokens by mirroring app colors/fonts into `NativeAdConfiguration` at launch.
