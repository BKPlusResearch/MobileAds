@preconcurrency import GoogleMobileAds
import UIKit

// MARK: - Banner Ad Cache Keys

/// Type-safe cache keys for banner ads
/// Apps define their own keys in extensions:
///
/// extension BannerAdCacheKey {
///     static let homeScreen = "homeScreen"
///     static let detailScreen = "detailScreen"
///     static let settingsFooter = "settingsFooter"
/// }
public struct BannerAdCacheKey {
    private init() {}
}

// MARK: - Cached Banner Ad Model

class CachedBannerAd {
    let bannerView: BannerView
    let loadedTime: Date
    let cacheKey: String
    let adUnitID: String

    init(bannerView: BannerView, cacheKey: String, adUnitID: String) {
        self.bannerView = bannerView
        self.loadedTime = Date()
        self.cacheKey = cacheKey
        self.adUnitID = adUnitID

        // Remove from superview before caching to avoid view hierarchy issues
        bannerView.removeFromSuperview()
    }

    /// Check if cached ad is still valid (within 1 hour)
    var isValid: Bool {
        let timeInterval = Date().timeIntervalSince(loadedTime)
        return timeInterval < 3600 // 1 hour
    }
}

// MARK: - Banner Cache Storage

extension AdMobHelper {
    // Static storage for cached banner ads
    private static var cachedBannerAds: [String: CachedBannerAd] = [:]

    // Track which cache key is associated with currently showing banner
    // This allows us to clear cache on impression
    private static var bannerCacheKeyMap: [BannerView: String] = [:]
}

// MARK: - Banner Cache Management

extension AdMobHelper {

    /// Get cached banner ad for a specific key
    /// - Parameter cacheKey: The cache key to retrieve
    /// - Returns: The cached BannerView if available and valid, nil otherwise
    public func getCachedBannerAd(for cacheKey: String) -> BannerView? {
        guard let cached = AdMobHelper.cachedBannerAds[cacheKey],
              cached.isValid else {
            // Remove invalid cache
            AdMobHelper.cachedBannerAds.removeValue(forKey: cacheKey)
            return nil
        }
        return cached.bannerView
    }

    /// Check if banner ad is cached and valid
    /// - Parameter cacheKey: The cache key to check
    /// - Returns: True if a valid cached banner exists for this key
    public func hasCachedBannerAd(for cacheKey: String) -> Bool {
        guard let cached = AdMobHelper.cachedBannerAds[cacheKey],
              cached.isValid else {
            debugPrint("🔍 [BANNER_CACHE] Check cache for '\(cacheKey)': ❌ NOT FOUND or EXPIRED")
            return false
        }

        let age = Int(Date().timeIntervalSince(cached.loadedTime))
        debugPrint("🔍 [BANNER_CACHE] Check cache for '\(cacheKey)': ✅ FOUND (age: \(age)s)")
        return true
    }

    /// Cache a banner ad (called internally after successful load)
    /// - Parameters:
    ///   - bannerView: The banner view to cache
    ///   - cacheKey: The cache key to store under
    ///   - adUnitID: The ad unit ID for reference
    func cacheBannerAd(_ bannerView: BannerView, for cacheKey: String, adUnitID: String) {
        let cached = CachedBannerAd(bannerView: bannerView, cacheKey: cacheKey, adUnitID: adUnitID)
        AdMobHelper.cachedBannerAds[cacheKey] = cached
        debugPrint("✅ [BANNER_CACHE] Cached banner for key: '\(cacheKey)'")
    }

    /// Clear cached banner for specific key
    /// - Parameter cacheKey: The cache key to clear
    public func clearCachedBannerAd(for cacheKey: String) {
        if let cached = AdMobHelper.cachedBannerAds.removeValue(forKey: cacheKey) {
            // Clean up tracking
            AdMobHelper.bannerCacheKeyMap.removeValue(forKey: cached.bannerView)
            debugPrint("🗑️ [BANNER_CACHE] Cleared cache for key: '\(cacheKey)'")
        }
    }

    /// Clear all cached banner ads
    public func clearAllCachedBannerAds() {
        AdMobHelper.cachedBannerAds.removeAll()
        AdMobHelper.bannerCacheKeyMap.removeAll()
        debugPrint("🗑️ [BANNER_CACHE] Cleared all cached banner ads")
    }

    /// Store cache key association for a banner view
    /// - Parameters:
    ///   - bannerView: The banner view
    ///   - cacheKey: The cache key to associate
    func associateCacheKey(_ cacheKey: String, with bannerView: BannerView) {
        AdMobHelper.bannerCacheKeyMap[bannerView] = cacheKey
    }

    /// Get cache key associated with a banner view
    /// - Parameter bannerView: The banner view
    /// - Returns: The associated cache key if any
    func getCacheKey(for bannerView: BannerView) -> String? {
        return AdMobHelper.bannerCacheKeyMap[bannerView]
    }
}
