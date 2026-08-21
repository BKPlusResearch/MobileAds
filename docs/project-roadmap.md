# Project Roadmap

**Last updated:** 2026-08-13 · **Version:** 1.3.0 · **Branch:** ver/swiftUI-merge

## Recently Shipped (from git history)

- **SwiftUI layer** — `UIViewRepresentable` wrappers and view modifiers for Banner, Native, Interstitial, Rewarded, Rewarded Interstitial, and App Open.
- **ATT & presentation safety** — `configAds` runs UMP → ATT → SDK init in order and waits for the tracking status to actually resolve; full-screen ads refuse to present while backgrounded (`AdMobHelperError.appInBackground`).
- **Mediation & SDK upgrade** — Google-Mobile-Ads-SDK → v13.3.0, Firebase → v12.13.0; added 7 mediation adapters (AppLovin, IronSource, Vungle, Facebook, Mintegral, Pangle, Unity); `PremiumAdsGoogleAdapter` replaces `PremiumAdmobAdapter`; podspec versions pinned to `Podfile.lock`.
- **Facebook AD_IMPRESSION tracking** — auto ad-revenue events to Meta via `ADJustManager.logRevenue()`.
- **Native ad cache** — single-use preload cache with metrics tracking; fixed dummy VC retention.
- **Banner revenue** — `paidEventHandler` on banners; `BannerAdView` collapsible support.
- **TikTok** — TikTok Business SDK integration.
- **Ad metrics overlay** — in-app `AdMetricsWindow` debug monitor.

## Current Focus (branch `ver/swiftUI-merge`)

- Stabilizing the GMA 13.x + mediation adapter set.
- Resolving the `EXCLUDED_ARCHS[sdk=iphonesimulator*]` conflict between the Facebook and IronSource adapters.
- Documentation baseline (this `docs/` set).

## Near-Term / Open Items

1. **Version & source alignment (P1)** — reconcile podspec `1.3.0` vs README tag `1.0.19`; confirm canonical repo (`AperoVN` vs `BKPlusResearch/MobileAds`) in podspec `homepage`/`source`. See `project-overview-pdr.md` open questions.
2. **Privacy manifests (P1)** — verify `PrivacyInfo.xcprivacy` coverage for the framework and each mediation network (App Store requirement).
3. **Modularization debt (P2)** — `NativeAdService.swift` (557 LOC) and `AdMobHelper+NativeCache.swift` (470 LOC) exceed the 200-LOC guideline; split when next touched.
4. **README accuracy (P2)** — reflect current install tag and any API deltas from recent commits.

## Candidate / Longer-Term

- Version bump + migration note for the `configAds` behavior change (completion now fires after ATT resolves, and the call must come from a foreground view controller).
- Consumer-facing guidance on server-side receipt validation.
- Automated podspec lint in CI on tag.

## Notes

Roadmap reflects git history + current podspec/README state as of 2026-08-13. Update after each release cut.
