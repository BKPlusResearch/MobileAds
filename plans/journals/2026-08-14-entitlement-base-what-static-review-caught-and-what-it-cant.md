---
title: "Entitlement base: what static review caught, and what it can't"
date: 2026-08-14
summary: "Shipped EntitlementService to feat/entitlement-base (unmerged); two review rounds found 5 High defects by reading, three from the plan's own pseudocode."
---

# Entitlement base: what static review caught, and what it can't

## What happened

Implemented both phases of plan `260814-1008-entitlement-base` in the MobileAds pod: a generic entitlements-first IAP layer (`EntitlementService`, `EntitlementConfig`, `EntitlementOutcome`) added alongside the frozen `IAPService`, plus README/docs. Branch `feat/entitlement-base`, PR #3 (draft, deliberately unmergeable). Builds clean on iOS 15 sim, arm64 + x86_64.

The plan was unusually well-prepared — already red-teamed (12 findings) and validated (4 decisions). It still shipped three High-severity defects in its own pseudocode.

## What the reviews found

Two rounds against the same reviewer. Round 1: 10/12 criteria, one failing, 5 High + 4 Medium + 6 Low. Round 2 on the delta: 12/12, but my fix for H5 introduced two new Mediums.

Three Highs traced straight to the plan's spec:

- **H2** — plan step 14 wrote `?? candidates.first` for intro-offer eligibility. `isEligibleForIntroOffer` answers a *group-level* question, so an offer-free product returns `true` and the paywall promises a trial on a plan that bills immediately. That is precisely the bug the same step claimed to be fixing. The pattern came from `ios033/TrialLedger.swift`, where a single known group makes it survivable.
- **H1** — nothing checked `Task.isCancelled` before `publish()`. `refresh()` is public and async, so it inherits cancellation; `.task { await refresh() }` — the spelling the README recommends — is cancelled on view disappear. Truncated read, `active == false`, published as `.verified`. A paying subscriber drops to free.
- **H3** — eligibility was computed only at the tail of `verify()`, which reads the on-device cache and almost always beats the `loadProducts()` network call. So it resolved against an empty catalog, concluded `false`, and never recomputed; the 30s debounce then blocked recovery.

The plan's red-team section had *already written down* the meta-lesson: "bê pattern từ ios033 vào ngữ cảnh thư viện iOS 15 không ai chạy, mà không điều chỉnh." It named the failure mode and then repeated it three more times in the pseudocode it was correcting.

## Decision

Implemented the plan's intent over its literal text where they conflicted, and logged each divergence in `plan.md`:

- `(error as? StoreKitError) == .userCancelled` does not compile — `StoreKitError` is not `Equatable`. Replaced with a typed `mapFailure(_:)`.
- Registered the three files in `project.pbxproj` (+12 lines), outside the plan's file list. Explicit file references mean the target otherwise never compiles them, and "the pod builds clean" would have been unverifiable.
- Checklist grew 14 → 16 cases. The plan's own argument for keeping cases 11–13 ("cắt chúng là vứt luôn vòng review") applies identically to the two new fail-open paths.
- Did **not** revisit V2 (finishing unverified transactions) despite a reviewer concern about consumables — that was a settled user decision, so I scoped the comment instead of reversing behavior.

Kept the branch unmerged per V4. Merge condition is the checklist passing, not review approval.

## What this doesn't establish

Five High defects found by reading is evidence about what remains, not reassurance. The repo has zero test files, no `.storekit` configuration, and a `TEST_HOST` pointing at an app target that no longer exists. Nothing catches runtime-only failures, and the layer ships having never executed.

R4 is the live risk: the base is unmerged by design, so if no app volunteers to integrate, the 16-case checklist — the only control — never runs, and this is dead code.

## Next steps

- Find the first integrator; point their Podfile at the branch and record results on PR #3.
- Add a `.storekit` configuration before that integration. Cases 15 and 16 are both trivially testable with one and need no App Store Connect round-trip.
- Two cancellation-shaped cases still have no checklist entry because they need a host that can cancel: `refresh()` in a cancelled `.task {}`, and `bootstrap()` before `configure()`.

> Historical work record — not durable authority. Prefer docs/specs/ADRs for current decisions.
