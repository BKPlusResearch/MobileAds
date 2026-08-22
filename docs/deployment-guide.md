# Deployment Guide

**Last updated:** 2026-08-22 · Applies to: MobileAds framework release via CocoaPods (git-based).

MobileAds is distributed as a **git-tagged CocoaPods pod**, not to the public trunk. Consumers pin by tag or track the default branch.

## Consumer Integration

```ruby
# Pin to a released tag (recommended). 2.0.0 serves both UIKit and SwiftUI apps:
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git", :tag => '2.0.0'

# Or track latest on the default branch:
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git"
```
Then `pod install`.

> `spec.source` and `spec.homepage` point at `BKPlusResearch/MobileAds`, matching the `origin` remote and the README install snippets. A commented-out alternate source for `AperoVN-iOS` remains in the podspec; it is inert.

> Apps that tracked the `ver/swiftUI` branch unpinned should move to `:tag => '2.0.0'`. That branch still exists and now carries the merged content, but only a pinned tag gives a reproducible build.

## Release Checklist (maintainers)

1. **Sync dependency versions.** Ensure every `spec.dependency` in `MobileAds.podspec` matches the resolved versions in `Podfile.lock`. Add any new SDK to both `Podfile` and the podspec.
2. **Bump `spec.version`** in `MobileAds.podspec`. This value drives the git tag via `spec.source`, so a version with no matching tag on `origin` cannot be installed pinned.
3. **Lint the spec:**
   ```bash
   pod spec lint MobileAds.podspec --allow-warnings
   # or, for git/private specs that need the local tree:
   pod lib lint MobileAds.podspec --allow-warnings
   ```
4. **Update README** install snippets and `NATIVE_AD_CACHE.md` if the public API changed.
5. **Commit** with a conventional message (`chore(podspec): bump to x.y.z` / `feat(...)`).
6. **Tag & push** to match the podspec version:
   ```bash
   git tag "$(grep -m1 spec.version MobileAds.podspec | cut -d'"' -f2)"
   git push origin new-MobileAds --tags
   ```
7. Consumer apps update their `Podfile` tag and run `pod update MobileAds`.

## Runtime Configuration (consumer app side)

Required setup in the host app before ads/telemetry work:

- **Info.plist:** `GADApplicationIdentifier` (AdMob app ID), SKAdNetwork items, `NSUserTrackingUsageDescription` for ATT, Facebook (`FacebookAppID`, `FacebookClientToken`), and any mediation network keys.
- **Firebase:** add `GoogleService-Info.plist`.
- **Adjust / TikTok / Facebook:** initialize with app tokens via `AppADJustConfig` / `TikTokAppConfig` and the respective managers.
- **Consent:** call `AdMobHelper.shared.configAds(from:)` early (AppDelegate/SceneDelegate `didFinishLaunching`).

## Build Notes

- `use_frameworks!` + `static_framework = true`. Bundled resources (`xcassets`, `xib`, images) ship via `spec.resources`.
- Minimum iOS 15.0; Swift 5.5.
- Mediation adapters are heavy — expect increased binary size and additional privacy-manifest requirements from each network.

## Rollback

If a release regresses a consumer app, pin that app's `Podfile` back to the previous known-good tag and `pod update MobileAds`. Framework tags are immutable — cut a new patch tag rather than moving an existing one.
