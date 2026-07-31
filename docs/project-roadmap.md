# Project Roadmap

**Last updated:** 2026-07-26 · **Version:** 1.3.0 · **Branch:** new-MobileAds

## Recently Shipped (from git history)

- **Mediation & SDK upgrade** — Google-Mobile-Ads-SDK → v13.2.0; added 7 mediation adapters (AppLovin, IronSource, Vungle, Facebook, Mintegral, Pangle, Unity); `PremiumAdsGoogleAdapter` shim; podspec versions pinned to `Podfile.lock`.
- **Facebook AD_IMPRESSION tracking** — auto ad-revenue events to Meta via `ADJustManager.logRevenue()`.
- **Native ad cache** — single-use preload cache with metrics tracking; fixed dummy VC retention.
- **Banner revenue** — `paidEventHandler` on banners; `BannerAdView` collapsible support.
- **IAP storage migration** — Keychain → UserDefaults path (`IAPMigration`).
- **TikTok** — TikTok Business SDK integration.
- **Ad metrics overlay** — in-app `AdMetricsWindow` debug monitor.

## Current Focus (branch `new-MobileAds`)

- Stabilizing the GMA 13.x + mediation adapter set.
- Documentation baseline (this `docs/` set).

## Near-Term / Open Items

1. **Version & source alignment (P1)** — reconcile podspec `1.3.0` vs README tag `1.0.19`; confirm canonical repo (`AperoVN` vs `BKPlusResearch/MobileAds`) in podspec `homepage`/`source`. See `project-overview-pdr.md` open questions.
2. **Privacy manifests (P1)** — verify `PrivacyInfo.xcprivacy` coverage for the framework and each mediation network (App Store requirement).
3. **Modularization debt (P2)** — `NativeAdService.swift` (557 LOC) and `AdMobHelper+NativeCache.swift` (470 LOC) exceed the 200-LOC guideline; split when next touched.
4. **README accuracy (P2)** — reflect current install tag and any API deltas from recent commits.

## Candidate / Longer-Term

- Optional SwiftUI wrappers for ad views (currently UIKit-only; non-goal today).
- Consumer-facing guidance on server-side receipt validation.
- Automated podspec lint in CI on tag.

## Notes

Roadmap reflects git history + current podspec/README state as of 2026-07-26. Update after each release cut.
