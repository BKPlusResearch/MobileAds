# Code Standards

**Last updated:** 2026-07-26 · Derived from the existing codebase, not aspirational.

## Language & Tooling

- Swift 5.5, iOS 15.0+ deployment target.
- UIKit-based (no SwiftUI). Layout via SnapKit; skeleton/shimmer loading via SkeletonView.
- Distributed as a static CocoaPods framework (`MobileAds.podspec`). `spec.version` is the source of truth for releases.

## File & Type Naming

- **Swift files: PascalCase**, matching the primary type (`AdMobHelper.swift`, `NativeAdService.swift`).
- **Format/concern extensions use `Type+Concern.swift`**: `AdMobHelper+Banner.swift`, `IAPService+Receipt.swift`, `IAPService+Subscription.swift`. Prefer adding a new `+Concern` extension over growing a base type.
- One primary public type per file.

## Modularization (enforced)

- Keep files focused; split when a file grows past ~200 LOC or mixes concerns. `AdMobHelper` (326 LOC base) and `IAPService` are deliberately fragmented into `+` extensions for this reason.
- The largest files (`NativeAdService` 557, `AdMobHelper+NativeCache` 470, `TikTokManager` 422) are candidates for further splitting if extended.

## Public API Conventions

- **Facades are singletons:** `Type.shared`, private `init`, `@MainActor` for UI-touching types (`AdMobHelper`).
- **Access control is explicit:** public surface uses `public`; internal mutable state uses `public internal(set)` so consumers can read flags (`isInterstitialLoading`, `bannerAd`) but not mutate them.
- **Consumer extensibility via protocols, not subclassing:** `AdUnitIdentifiable`, `IAPProductIdentifiable`, `RemoteKeyIdentifiable`. The framework ships no app-specific ad unit or product IDs.
- **Status via enums + callbacks:** each ad format exposes a status enum (`BannerAdStatus`, `InterstitialAdStatus`, `RewardedAdStatus`, `AppOpenAdStatus`, `NativeAdStatus`) delivered through `statusCallback` closures. Errors via typed `Error` enums (`AdMobHelperError`, `IAPError`).
- **Test vs production IDs** are the consumer's responsibility, gated with `#if DEBUG` in their `AdUnitIdentifiable` enum.

## Concurrency

- StoreKit 2 IAP uses `async`/`await`; wrap calls in `do/catch` against the typed error enum.
- A persistent `Transaction.updates` listener maintains subscription state — consumers do not poll.
- Ad UI code runs on the main actor.

## Dependencies

- Add third-party SDKs through **both** `Podfile` (dev/integration) and `MobileAds.podspec` (`spec.dependency`, pinned to match `Podfile.lock`). Keep the two in sync — a recent commit (`de31b9e`) exists specifically to pin versions across them.

## Logging & Debug

- `debugPrint` for framework diagnostics; emoji-prefixed tags for scannable logs (e.g. `[VUNT_CACHE]` in the native cache path).
- Ad revenue metrics surface through an in-app debug overlay (`AdMetricsWindow` / `AdMetricsMonitorView`) — keep debug-only surfaces out of release UX.

## Commit Conventions

- Conventional Commits, no AI references: `feat(banner): ...`, `fix(ads): ...`, `chore(podspec): ...`.
- Do **not** use `chore`/`docs` types for changes under `.claude/`.
- Keep commits focused; never commit secrets, tokens, or credentials.

## Comments

- Doc comments (`///`) on public API describing behavior and lifecycle. Retain the Google Apache-2.0 header on files derived from Google sample code.
