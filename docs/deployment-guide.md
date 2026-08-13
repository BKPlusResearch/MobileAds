# Deployment Guide

**Last updated:** 2026-07-26 · Applies to: MobileAds framework release via CocoaPods (git-based).

MobileAds is distributed as a **git-tagged CocoaPods pod**, not to the public trunk. Consumers pin by tag or track the default branch.

## Consumer Integration

```ruby
# Pin to a released tag (recommended):
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git", :tag => '1.3.0'

# Or track latest on the default branch:
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git"
```
Then `pod install`.

> ⚠️ Verify the canonical repo/org before publishing — `MobileAds.podspec` `spec.source` currently points at `github.com/AperoVN` while README uses `BKPlusResearch/MobileAds`. See open questions in `project-overview-pdr.md`.

## Release Checklist (maintainers)

1. **Sync dependency versions.** Ensure every `spec.dependency` in `MobileAds.podspec` matches the resolved versions in `Podfile.lock`. Add any new SDK to both `Podfile` and the podspec.
2. **Bump `spec.version`** in `MobileAds.podspec` (currently `1.3.0`). This value drives the git tag via `spec.source`.
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
   git tag 1.3.0
   git push origin HEAD --tags
   ```
7. Consumer apps update their `Podfile` tag and run `pod update MobileAds`.

## Runtime Configuration (consumer app side)

Required setup in the host app before ads/telemetry work:

- **Info.plist:** `GADApplicationIdentifier` (AdMob app ID), SKAdNetwork items, `NSUserTrackingUsageDescription` for ATT, Facebook (`FacebookAppID`, `FacebookClientToken`), and any mediation network keys.
- **Firebase:** add `GoogleService-Info.plist`.
- **Adjust / TikTok / Facebook:** initialize with app tokens via `AppADJustConfig` / `TikTokAppConfig` and the respective managers.
- **Consent + ATT:** call `AdMobHelper.shared.configAds(from:)` from a foreground view controller (e.g. a splash screen), **not** from `didFinishLaunching` — both the UMP form and the ATT prompt need a live presenter, and iOS silently declines to present ATT while the app is not yet `.active`. See the Initialize SDK section in `README.md`.

## Build Notes

- `use_frameworks!` + `static_framework = true`. Bundled resources (`xcassets`, `xib`, images) ship via `spec.resources`.
- Minimum iOS 15.0; Swift 5.5.
- Mediation adapters are heavy — expect increased binary size and additional privacy-manifest requirements from each network.

## Rollback

If a release regresses a consumer app, pin that app's `Podfile` back to the previous known-good tag and `pod update MobileAds`. Framework tags are immutable — cut a new patch tag rather than moving an existing one.
