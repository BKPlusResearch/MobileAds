# Plan reconcile — MobileAds — 2026-10-13
Base branch: `new-MobileAds` (`origin/new-MobileAds` @ `9cc819b`, tag `2.0.6`; repo default `origin/HEAD` -> `origin/develop` @ `86f2b44`) · Plans reviewed: 5 · DONE 5 · OBSOLETE 0 · OPEN 0 · UNSURE 0

All 5 plans in `MobileAds` are **DONE** — every deliverable has shipped on `new-MobileAds` (tagged `2.0.0` through `2.0.6`).

| Plan | Old status | Verdict | Evidence | Edited? |
|---|---|---|---|---|
| `plans/260422-1544-swiftui-support/plan.md` | `pending` | DONE | Implemented in `8e8fd86`, `fcf1ac8`, `7fd9015`; compiled into Xcode target in `99fae53`; refined in `3133f05`, `7671891`, `c45e3e0`. All 7 SwiftUI files exist in `MobileAds/SwiftUI/` (`ViewControllerResolver.swift`, `BannerAdSwiftUI.swift`, `NativeAdSwiftUI.swift`, `InterstitialModifier.swift`, `RewardedModifier.swift`, `RewardedInterstitialModifier.swift`, `AppOpenModifier.swift`) and `MobileAds.podspec` includes `"SwiftUI"` in `spec.frameworks`. (Phase 6's `IAPViewModel.swift` shipped in `8e8fd86` and was later removed in `4b47253` when `EntitlementService` replaced `IAPService`.) | Yes (`completed`) |
| `plans/260814-1008-entitlement-base/plan.md` | `completed` | DONE | Implemented in `4521b46` / `62c648d` (`feat(iap): add entitlements-first EntitlementService`), merged in PR `#3`, and present in `MobileAds/IAP/EntitlementService.swift`, `EntitlementConfig.swift`, `EntitlementOutcome.swift`. | No (already `completed`) |
| `plans/260814-1621-remove-legacy-iap/plan.md` | `in-progress` | DONE | P0–P2 recorded as Done in the plan; deliverable commits shipped on `new-MobileAds`: `cecb595` / `d7ae295` (`feat(iap): deliver consumables before finishing transactions`), `c44b53b` / `4b47253` (`feat(iap)!: remove legacy IAPService layer`), `1fbfc0c` (`docs(iap): document EntitlementService as the only IAP layer`). Only the 3 `Entitlement*.swift` files remain in `MobileAds/IAP/` and `MobileAds.podspec` is at `2.0.6`. Downstream app migration and App Store Connect secret rotation (`BKPlusResearch/ios033-gps-camera#1`) were explicitly scoped as Non-goals. | Yes (`completed`) |
| `plans/260821-1659-port-entitlement-iap/plan.md` | `nostatus` (body: `Status: done (2026-08-21)`) | DONE | All 5 acceptance criteria and commits (`62c648d`, `d7ae295`, `4b47253`, `1fbfc0c`, `4b3ad3e`) are in git history on `new-MobileAds` and recorded under `## Kết quả`. | No (no YAML frontmatter) |
| `plans/260822-1043-merge-swiftui-single-branch/plan.md` | `awaiting-approval` | DONE | Phases 1–3 commits (`99fae53`, `3133f05`, `7671891`, `78ff400`) and Phase 4 release deliverables (`18ec145` `feat(ads)!: remove the setEnableShowAds flag`, tag `2.0.0` at `3e7d39e`, followed by tags `2.0.1`–`2.0.6` at `9cc819b` on `origin/new-MobileAds`) have all been pushed and released. | Yes (`completed`) |

## OPEN work (what remains to finish)
None. All 5 plans in this repository have completed their in-repo deliverables.

*(Note on external/non-goal follow-ups documented inside the completed IAP plans: rotating the legacy App Store Connect shared secrets tracked in `BKPlusResearch/ios033-gps-camera#1`, and migrating legacy 1.x consumer apps when they upgrade from tag `1.4.0` to `2.0.x`, were explicitly declared Non-goals of `260814-1621-remove-legacy-iap`.)*

## UNSURE — questions for Quoc
None.
