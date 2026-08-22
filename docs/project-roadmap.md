# Project Roadmap

**Last updated:** 2026-08-22 · **Version:** 2.0.0 · **Branch:** new-MobileAds

## Recently Shipped (from git history)

- **Mediation & SDK upgrade** — added 7 mediation adapters (AppLovin, IronSource, Vungle, Facebook, Mintegral, Pangle, Unity) plus the vendored `PremiumAdsGoogleAdapter` pod, which replaced the earlier `PremiumAdmobAdapter` dependency and the local adapter shim. Exact SDK versions live in `MobileAds.podspec` and `Podfile.lock`; the podspec pins match the lockfile.
- **Facebook AD_IMPRESSION tracking** — auto ad-revenue events to Meta via `ADJustManager.logRevenue()`.
- **Native ad cache** — single-use preload cache with metrics tracking; fixed dummy VC retention.
- **Banner revenue** — `paidEventHandler` on banners; `BannerAdView` collapsible support.
- **Entitlements-first IAP (2.0.0, breaking)** — `EntitlementService` derives entitlement from `Transaction.currentEntitlements` on every check and persists nothing; `onUnfinished` hook credits consumables before a transaction is finished. The legacy `IAPService` layer was removed.
- ~~**IAP storage migration** — Keychain → UserDefaults path (`IAPMigration`).~~ Superseded by 2.0.0: the storage layer it migrated between no longer exists.
- **SwiftUI layer merged into the UIKit line (2.0.0)** — `ver/swiftUI` and `new-MobileAds` converged into one branch, so a single pod and a single tag serve both surfaces. No subspec: deployment target is iOS 15 and every SwiftUI type is `@available(iOS 15.0, *)`. The merge kept this line's newer SDK pins and the `defer { is*Loading = false }` fix that the SwiftUI line lacked, and added the seven SwiftUI sources to the framework target — they had never been compiled by this repo, only shipped through the podspec glob.
- **TikTok** — TikTok Business SDK integration.
- **Ad metrics overlay** — in-app `AdMetricsWindow` debug monitor.

## Current Focus (branch `new-MobileAds` — now the only release line)

- Stabilizing the GMA 13.x + mediation adapter set.
- Documentation baseline (this `docs/` set).
- **Verifying `EntitlementService` on a device.** It has never been run; the sandbox checklist in the README is the only control that exists. No StoreKit test configuration in this repo.

## Near-Term / Open Items

1. **SwiftUI app-resume flag handling (P1)** — the `.appOpenAd` modifier checks `shouldSkipNextAppResume` only when deciding to preload, never before showing, and never resets it. Result: an app-open ad can stack right after an interstitial, and background preloading stops for good once the flag latches true. See `project-overview-pdr.md` open questions.
2. **Privacy manifests (P1)** — verify `PrivacyInfo.xcprivacy` coverage for the framework and each mediation network (App Store requirement).
3. **Modularization debt (P2)** — `NativeAdService.swift` (557 LOC) and `AdMobHelper+NativeCache.swift` (470 LOC) exceed the 200-LOC guideline; split when next touched.
4. **SwiftUI layer has no test or demo coverage (P2)** — the seven sources now compile in CI-reachable form, but nothing exercises them at runtime. A demo SwiftUI target would be the cheapest way to catch modifier regressions.

## Candidate / Longer-Term

- Consumer-facing guidance on server-side receipt validation.
- Automated podspec lint in CI on tag.

## Notes

Roadmap reflects git history + current podspec/README state as of the **Last updated** date above. Update after each release cut.
