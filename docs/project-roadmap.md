# Project Roadmap

**Last updated:** 2026-08-21 · **Version:** 2.0.0 · **Branch:** new-MobileAds

## Recently Shipped (from git history)

- **Mediation & SDK upgrade** — added 7 mediation adapters (AppLovin, IronSource, Vungle, Facebook, Mintegral, Pangle, Unity) plus the vendored `PremiumAdsGoogleAdapter` pod, which replaced the earlier `PremiumAdmobAdapter` dependency and the local adapter shim. Exact SDK versions live in `MobileAds.podspec` and `Podfile.lock`; the podspec pins match the lockfile.
- **Facebook AD_IMPRESSION tracking** — auto ad-revenue events to Meta via `ADJustManager.logRevenue()`.
- **Native ad cache** — single-use preload cache with metrics tracking; fixed dummy VC retention.
- **Banner revenue** — `paidEventHandler` on banners; `BannerAdView` collapsible support.
- **Entitlements-first IAP (2.0.0, breaking)** — `EntitlementService` derives entitlement from `Transaction.currentEntitlements` on every check and persists nothing; `onUnfinished` hook credits consumables before a transaction is finished. The legacy `IAPService` layer was removed.
- ~~**IAP storage migration** — Keychain → UserDefaults path (`IAPMigration`).~~ Superseded by 2.0.0: the storage layer it migrated between no longer exists.
- **TikTok** — TikTok Business SDK integration.
- **Ad metrics overlay** — in-app `AdMetricsWindow` debug monitor.

## Current Focus (branch `new-MobileAds`)

- Stabilizing the GMA 13.x + mediation adapter set.
- Documentation baseline (this `docs/` set).
- **Verifying `EntitlementService` on a device.** It has never been run; the sandbox checklist in the README is the only control that exists. No StoreKit test configuration in this repo.

## Near-Term / Open Items

1. **Version & source alignment (P1)** — podspec declares `2.0.0` but `1.4.0` is the only tag on `origin`, so 2.0.0 is installable only unpinned; cut the tag or drop the claim. Also confirm the canonical repo (`AperoVN` in podspec `homepage`/`source` vs `BKPlusResearch/MobileAds` in the README install snippet and the `origin` remote). See `project-overview-pdr.md` open questions.
2. **Privacy manifests (P1)** — verify `PrivacyInfo.xcprivacy` coverage for the framework and each mediation network (App Store requirement).
3. **Modularization debt (P2)** — `NativeAdService.swift` (557 LOC) and `AdMobHelper+NativeCache.swift` (470 LOC) exceed the 200-LOC guideline; split when next touched.
4. **README accuracy (P2)** — re-check API deltas from recent commits; the install snippets now match the published tag set.

## Candidate / Longer-Term

- Optional SwiftUI wrappers for ad views (currently UIKit-only; non-goal today).
- Consumer-facing guidance on server-side receipt validation.
- Automated podspec lint in CI on tag.

## Notes

Roadmap reflects git history + current podspec/README state as of the **Last updated** date above. Update after each release cut.
