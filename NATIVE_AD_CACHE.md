# Native Ad Cache System

The MobileAds framework includes a powerful native ad caching system that allows you to preload native ads for instant display, eliminating loading delays and improving user experience.

## Features

- ✅ **Preload multiple ads** at once
- ✅ **Type-safe cache keys** defined per app
- ✅ **Automatic cache expiration** (1 hour)
- ✅ **Instant ad display** from cache
- ✅ **Fallback to network** if cache unavailable
- ✅ **Full styling support** via `NativeAdConfiguration`

## Quick Start

### 1. Define Your Cache Keys

In your app's `AppDelegate.swift` or a shared constants file:

```swift
import MobileAds

extension NativeAdCacheKey {
    static let firstLanguage = "firstLanguage"
    static let onboarding1 = "onboarding1"
    static let onboarding2 = "onboarding2"
    static let homeScreen = "homeScreen"
    static let settingsScreen = "settingsScreen"
    // Add as many keys as needed for your app
}
```

### 2. Preload Ads Early

Preload ads as early as possible (e.g., in SplashVC or AppDelegate):

```swift
func preloadAdsForNewUser() {
    AdMobHelper.shared.preloadMultipleNativeAds(
        requests: [
            (adUnitID: AppAdUnitID.native_onboarding, cacheKey: NativeAdCacheKey.firstLanguage),
            (adUnitID: AppAdUnitID.native_onboarding, cacheKey: NativeAdCacheKey.onboarding1),
            (adUnitID: AppAdUnitID.native_onboarding, cacheKey: NativeAdCacheKey.onboarding2),
            (adUnitID: AppAdUnitID.native_onboarding, cacheKey: NativeAdCacheKey.onboarding3)
        ]
    ) { successCount in
        print("✅ Preloaded \(successCount)/4 native ads")
    }
}
```

### 3. Display Cached Ads

Use `loadNativeAdWithCache` to automatically use cached ads or fallback to network:

```swift
AdMobHelper.shared.loadNativeAdWithCache(
    containerView: adsView,
    adUnitID: AppAdUnitID.native_onboarding,
    rootViewController: self,
    viewType: .medium,
    configuration: nil, // Uses NativeAdConfiguration.shared
    cacheKey: NativeAdCacheKey.firstLanguage
) { success in
    if success {
        print("✅ Ad displayed")
    }
}
```

## API Reference

### Preloading

```swift
// Preload multiple ads at once
func preloadMultipleNativeAds(
    requests: [(adUnitID: AdUnitIdentifiable, cacheKey: String)],
    completion: ((Int) -> Void)? = nil
)
```

### Checking Cache

```swift
// Check if ad is cached and valid
func hasCachedNativeAd(for cacheKey: String) -> Bool

// Check if ad is currently being preloaded
func isPreloadingNativeAd(for cacheKey: String) -> Bool
```

### Loading with Cache

```swift
// Load ad with automatic cache fallback
func loadNativeAdWithCache(
    containerView: UIView,
    adUnitID: AdUnitIdentifiable,
    rootViewController: UIViewController,
    viewType: NativeAdService.NativeAdViewType,
    configuration: NativeAdConfiguration? = nil,
    cacheKey: String?,
    statusCallback: ((Bool) -> Void)? = nil
)
```

### Cache Management

```swift
// Clear specific cached ad
func clearCachedNativeAd(for cacheKey: String)

// Clear all cached ads
func clearAllCachedNativeAds()
```

## Best Practices

### 1. Preload at the Right Time

**✅ Good:**
```swift
// Preload in splash screen for instant display on next screens
class SplashVC {
    override func viewDidLoad() {
        super.viewDidLoad()
        preloadAdsForNewUser()
    }
}
```

**❌ Bad:**
```swift
// Don't preload right before showing - defeats the purpose
func showFirstLanguageScreen() {
    AdMobHelper.shared.preloadMultipleNativeAds(...) // Too late!
    navigationController?.pushViewController(vc, animated: true)
}
```

### 2. Use Meaningful Cache Keys

**✅ Good:**
```swift
extension NativeAdCacheKey {
    static let onboardingWelcome = "onboarding_welcome"
    static let onboardingFeatures = "onboarding_features"
    static let homeTopBanner = "home_top_banner"
}
```

**❌ Bad:**
```swift
extension NativeAdCacheKey {
    static let ad1 = "ad1"  // Not descriptive
    static let ad2 = "ad2"  // Hard to maintain
}
```

### 3. Handle Cache Miss Gracefully

The cache system automatically falls back to network loading if cache is unavailable:

```swift
AdMobHelper.shared.loadNativeAdWithCache(
    containerView: adsView,
    adUnitID: AppAdUnitID.native_onboarding,
    rootViewController: self,
    viewType: .medium,
    cacheKey: NativeAdCacheKey.firstLanguage
) { success in
    // If cached: instant display
    // If not cached: loads from network
    // Either way, ad will be displayed if available
}
```

### 4. Consider Cache Expiration

Cached ads expire after **1 hour** (per AdMob policy). If you need fresh ads:

```swift
// Clear expired ads periodically
AdMobHelper.shared.clearCachedNativeAd(for: NativeAdCacheKey.homeScreen)

// Or clear all
AdMobHelper.shared.clearAllCachedNativeAds()
```

## Advanced Usage

### Wait for Cache Without Loading Indicator

The system automatically retries cache checks for up to 2.5 seconds if ads are being preloaded:

```swift
private func getAdsNative() {
    let hasCachedAd = AdMobHelper.shared.hasCachedNativeAd(for: cacheKey)
    let isPreloading = AdMobHelper.shared.isPreloadingNativeAd(for: cacheKey)

    if hasCachedAd {
        // Ad ready - no loading needed
    } else if isPreloading && retryCount < maxRetries {
        // Wait for preload to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.getAdsNative()
        }
        return
    } else {
        // Load from network
    }
}
```

### Custom Ad Styling

Apply custom styling using `NativeAdConfiguration`:

```swift
// In AppDelegate
NativeAdConfiguration.shared.borderWidth = 1
NativeAdConfiguration.shared.borderColor = UIColor.gray
NativeAdConfiguration.shared.backgroundColor = UIColor.white
NativeAdConfiguration.shared.useGradientForCallToAction = true
NativeAdConfiguration.shared.callToActionGradientStartColor = UIColor.blue
NativeAdConfiguration.shared.callToActionGradientEndColor = UIColor.purple

// Configuration automatically applied to all ads (cached and network)
```

## Debugging

Enable debug logs by checking console output:

```
🚀 [VUNT_CACHE] Starting preload for 4 ads
🔍 [VUNT_CACHE] Check cache for 'firstLanguage': ❌ NOT FOUND or EXPIRED
⏳ [VUNT_CACHE] Preloading ad for key: firstLanguage
✅ [VUNT_CACHE] Cached ad for key: firstLanguage
✅ [VUNT_CACHE] Preload completed: 4/4 ads
🔍 [VUNT_CACHE] Check cache for 'firstLanguage': ✅ FOUND (age: 12s)
✅ [VUNT_CACHE] Using cached ad for key: firstLanguage
✅ [VUNT_CACHE] Displayed cached ad with all data populated
```

## Migration from Old System

If you're migrating from `NativeAdCacheManager` or `AdMobHelper+Preload`:

**Before:**
```swift
NativeAdCacheManager.shared.cacheAd(ad, forKey: "key", adUnitID: "id")
let ad = NativeAdCacheManager.shared.getCachedAd(forKey: "key")
```

**After:**
```swift
// Use preloadMultipleNativeAds for preloading
AdMobHelper.shared.preloadMultipleNativeAds(requests: [...])

// Use loadNativeAdWithCache for display (handles cache automatically)
AdMobHelper.shared.loadNativeAdWithCache(..., cacheKey: NativeAdCacheKey.key)
```

## Support

For issues or questions:
- Check console logs for `[VUNT_CACHE]` messages
- Verify cache keys are properly defined in your app
- Ensure ads are preloaded before display
- Check network connectivity if preload fails

## License

Part of MobileAds framework - Copyright © 2024-2026
