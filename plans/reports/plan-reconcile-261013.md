# Plan reconcile — MobileAds — 2026-10-13
Base branch: `new-MobileAds` (`origin/new-MobileAds` @ `9cc819b`, tag `2.0.6`; repo default `origin/HEAD` -> `origin/develop` @ `86f2b44`) · Plans reviewed: 5 · DONE 5 · OBSOLETE 0 · OPEN 0 · UNSURE 0

All 5 plans in `MobileAds` are **DONE** (confirming the hypothesis: 100% of plans in this repository have shipped on `new-MobileAds` across tags `1.4.0` through `2.0.6`, and 0 are truly OPEN).

| Plan | Old status | Verdict | Evidence | Edited? |
|---|---|---|---|---|
| `plans/260422-1544-swiftui-support/plan.md` | `pending` (now `completed` from pass 1) | DONE | Shipped in commits `8e8fd86` (`feat(swiftui): implement SwiftUI wrappers and modifiers for mobile ads`), `fcf1ac8`, `7fd9015`; merged into single-branch line in `6615b7c`, added to Xcode framework target in `99fae53`, and refined in `3133f05`, `7671891`, `c45e3e0`. All 7 SwiftUI files exist in `MobileAds/SwiftUI/` (`ViewControllerResolver.swift`, `BannerAdSwiftUI.swift`, `NativeAdSwiftUI.swift`, `InterstitialModifier.swift`, `RewardedModifier.swift`, `RewardedInterstitialModifier.swift`, `AppOpenModifier.swift`) and `MobileAds.podspec` declares `"SwiftUI"` in `spec.frameworks`. (Phase 6's `IAPViewModel.swift` shipped in `8e8fd86` and was later removed in `4b47253` when `EntitlementService` replaced `IAPService`.) | Yes (pass 1 -> `completed`) |
| `plans/260814-1008-entitlement-base/plan.md` | `completed` | DONE | Shipped in `4521b46` (`feat(iap): add entitlements-first EntitlementService`) and `c3bb450` (tag `1.4.0`), merged via PR `#3`, and ported to `new-MobileAds` in `62c648d`. Present in `MobileAds/IAP/EntitlementService.swift`, `EntitlementConfig.swift`, `EntitlementOutcome.swift`. | No (already `completed`) |
| `plans/260814-1621-remove-legacy-iap/plan.md` | `in-progress` (now `completed` from pass 1) | DONE | Phases 0–2 recorded as Done in `plan.md`; deliverable commits shipped in `cecb595` / `d7ae295` (`feat(iap): deliver consumables before finishing transactions`), `c44b53b` / `4b47253` (`feat(iap)!: remove legacy IAPService layer`), and `1fbfc0c` (`docs(iap): document EntitlementService as the only IAP layer`), merged in `6de0d61`. Only the 3 `Entitlement*.swift` files remain in `MobileAds/IAP/` and `MobileAds.podspec` is at `2.0.6`. Consumer app migration and App Store Connect secret rotation (`BKPlusResearch/ios033-gps-camera#1`) were explicitly declared Non-goals. | Yes (pass 1 -> `completed`) |
| `plans/260821-1659-port-entitlement-iap/plan.md` | `nostatus` (inline `Status: done (2026-08-21)`) | DONE | All 5 acceptance criteria and commits (`62c648d`, `d7ae295`, `4b47253`, `1fbfc0c`, `4b3ad3e`) are in git history on `new-MobileAds` and documented under `## Kết quả`. | No (no YAML frontmatter) |
| `plans/260822-1043-merge-swiftui-single-branch/plan.md` | `awaiting-approval` (now `completed` from pass 1) | DONE | Phases 1–3 commits (`6615b7c`, `99fae53`, `3133f05`, `7671891`, `78ff400`) and Phase 4 release deliverables (`18ec145` `feat(ads)!: remove the setEnableShowAds flag` and `3e7d39e` tagged `2.0.0`, followed by tags `2.0.1`–`2.0.6` at `9cc819b` on `origin/new-MobileAds`) have all been pushed and released. | Yes (pass 1 -> `completed`) |

## Disputed earlier edits
None. All status updates made in the first reconcile pass (`11d40be`) accurately reflect shipped commits and current repository state.

## OPEN work (what remains to finish)
None. All 5 plans in this repository have completed their in-repo deliverables.

*(Note on external/non-goal follow-ups documented inside the completed IAP plans: rotating the legacy App Store Connect shared secrets tracked in `BKPlusResearch/ios033-gps-camera#1`, and migrating legacy 1.x consumer apps when they upgrade from tag `1.4.0` to `2.0.x`, were explicitly scoped as Non-goals of `260814-1621-remove-legacy-iap`.)*

## UNSURE — questions for Quoc
None.
