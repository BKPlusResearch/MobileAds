//
//  AdMobHelper+NativeCache.swift
//  MobileAds
//
//  Created by Claude on 1/21/26.
//

import Foundation
import GoogleMobileAds
import UIKit
import SnapKit

// MARK: - Internal Ad Loader Delegate for Caching
private class CacheNativeAdLoaderDelegate: NSObject, NativeAdLoaderDelegate {
    var onAdLoaded: ((NativeAd) -> Void)?
    var onAdFailed: ((Error) -> Void)?
    let cacheKey: String

    init(cacheKey: String) {
        self.cacheKey = cacheKey
        super.init()
        debugPrint("🆕 [VUNT_CACHE] Delegate created for key: \(cacheKey)")
    }

    deinit {
        debugPrint("💀 [VUNT_CACHE] Delegate deallocated for key: \(cacheKey)")
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        debugPrint("🎉 [VUNT_CACHE] Delegate didReceive called for key: \(cacheKey)!")
        debugPrint("🎉 [VUNT_CACHE] onAdLoaded closure is nil? \(onAdLoaded == nil)")
        onAdLoaded?(nativeAd)
        debugPrint("🎉 [VUNT_CACHE] onAdLoaded closure executed for key: \(cacheKey)")
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        debugPrint("💥 [VUNT_CACHE] Delegate didFail called for key: \(cacheKey)!")
        debugPrint("💥 [VUNT_CACHE] Error: \(error.localizedDescription)")
        debugPrint("💥 [VUNT_CACHE] onAdFailed closure is nil? \(onAdFailed == nil)")
        onAdFailed?(error)
        debugPrint("💥 [VUNT_CACHE] onAdFailed closure executed for key: \(cacheKey)")
    }
}

// MARK: - Native Ad Cache Keys
/// Example cache keys - Apps should define their own keys in their project
///
/// Example usage in your app:
/// ```swift
/// extension NativeAdCacheKey {
///     static let firstLanguage = "firstLanguage"
///     static let onboarding1 = "onboarding1"
///     static let homeScreen = "homeScreen"
///     static let settingsScreen = "settingsScreen"
/// }
/// ```
public struct NativeAdCacheKey {
    // No predefined keys - apps define their own
    private init() {}
}

// MARK: - Cached Native Ad Model
class CachedNativeAd {
    let ad: NativeAd
    let loadedTime: Date
    let cacheKey: String

    init(ad: NativeAd, cacheKey: String) {
        self.ad = ad
        self.loadedTime = Date()
        self.cacheKey = cacheKey
    }

    /// Check if cached ad is still valid (within 1 hour)
    var isValid: Bool {
        let timeInterval = Date().timeIntervalSince(loadedTime)
        return timeInterval < 3600 // 1 hour
    }
}

// MARK: - AdMobHelper Extension for Native Ad Caching
extension AdMobHelper {

    private static var cachedNativeAds: [String: CachedNativeAd] = [:]
    private static var preloadingKeys: Set<String> = []
    private static var activeDelegates: [String: CacheNativeAdLoaderDelegate] = [:]
    private static var activeAdLoaders: [String: AdLoader] = [:]

    // Track which cache key is associated with currently showing native ad
    // This allows us to clear cache on impression
    private static var nativeAdCacheKeyMap: [NativeAd: String] = [:]

    /// Get cached native ad for a specific key
    /// - Parameter cacheKey: The cache key to retrieve
    /// - Returns: Cached native ad if available and valid
    public func getCachedNativeAd(for cacheKey: String) -> NativeAd? {
        guard let cached = AdMobHelper.cachedNativeAds[cacheKey],
              cached.isValid else {
            // Remove invalid cache
            AdMobHelper.cachedNativeAds.removeValue(forKey: cacheKey)
            return nil
        }
        return cached.ad
    }

    /// Check if ad is cached and valid
    /// - Parameter cacheKey: The cache key to check
    /// - Returns: True if cached ad exists and is valid
    public func hasCachedNativeAd(for cacheKey: String) -> Bool {
        guard let cached = AdMobHelper.cachedNativeAds[cacheKey],
              cached.isValid else {
            debugPrint("🔍 [VUNT_CACHE] Check cache for '\(cacheKey)': ❌ NOT FOUND or EXPIRED")
            return false
        }
        debugPrint("🔍 [VUNT_CACHE] Check cache for '\(cacheKey)': ✅ FOUND (age: \(Int(Date().timeIntervalSince(cached.loadedTime)))s)")
        return true
    }

    /// Check if ad is currently preloading
    /// - Parameter cacheKey: The cache key to check
    /// - Returns: True if ad is being preloaded
    public func isPreloadingNativeAd(for cacheKey: String) -> Bool {
        return AdMobHelper.preloadingKeys.contains(cacheKey)
    }

    /// Cache a native ad
    /// - Parameters:
    ///   - ad: The native ad to cache
    ///   - cacheKey: The cache key to store
    func cacheNativeAd(_ ad: NativeAd, for cacheKey: String) {
        let cached = CachedNativeAd(ad: ad, cacheKey: cacheKey)
        AdMobHelper.cachedNativeAds[cacheKey] = cached
        debugPrint("✅ [NATIVE_CACHE] Cached ad for key: \(cacheKey)")
    }

    /// Clear cached ad for specific key
    /// - Parameter cacheKey: The cache key to clear
    public func clearCachedNativeAd(for cacheKey: String) {
        if let cached = AdMobHelper.cachedNativeAds.removeValue(forKey: cacheKey) {
            // Clean up tracking
            AdMobHelper.nativeAdCacheKeyMap.removeValue(forKey: cached.ad)
            debugPrint("🗑️ [NATIVE_CACHE] Cleared cache for key: '\(cacheKey)'")
        }
    }

    /// Clear all cached native ads
    public func clearAllCachedNativeAds() {
        AdMobHelper.cachedNativeAds.removeAll()
        AdMobHelper.preloadingKeys.removeAll()
        AdMobHelper.activeDelegates.removeAll()
        AdMobHelper.activeAdLoaders.removeAll()
        AdMobHelper.nativeAdCacheKeyMap.removeAll()
        debugPrint("🗑️ [VUNT_CACHE] Cleared all cached native ads")
    }

    /// Store cache key association for a native ad
    /// - Parameters:
    ///   - cacheKey: The cache key to associate
    ///   - nativeAd: The native ad instance
    func associateNativeAdCacheKey(_ cacheKey: String, with nativeAd: NativeAd) {
        AdMobHelper.nativeAdCacheKeyMap[nativeAd] = cacheKey
    }

    /// Get cache key associated with a native ad
    /// - Parameter nativeAd: The native ad instance
    /// - Returns: The associated cache key if any
    func getNativeAdCacheKey(for nativeAd: NativeAd) -> String? {
        return AdMobHelper.nativeAdCacheKeyMap[nativeAd]
    }

    /// Preload multiple native ads for later use
    /// - Parameters:
    ///   - requests: Array of tuples containing ad unit ID and cache key
    ///   - completion: Callback with number of successfully preloaded ads
    public func preloadMultipleNativeAds(
        requests: [(adUnitID: AdUnitIdentifiable, cacheKey: String)],
        completion: ((Int) -> Void)? = nil
    ) {
        guard !requests.isEmpty else {
            debugPrint("⚠️ [VUNT_CACHE] No ads to preload")
            completion?(0)
            return
        }

        debugPrint("🚀 [VUNT_CACHE] Starting preload for \(requests.count) ads")
        var successCount = 0
        let totalCount = requests.count
        let dispatchGroup = DispatchGroup()

        for request in requests {
            // Skip if already cached or preloading
            if hasCachedNativeAd(for: request.cacheKey) {
                debugPrint("ℹ️ [VUNT_CACHE] Ad already cached for key: \(request.cacheKey)")
                successCount += 1
                continue
            }

            if isPreloadingNativeAd(for: request.cacheKey) {
                debugPrint("ℹ️ [VUNT_CACHE] Ad already preloading for key: \(request.cacheKey)")
                continue
            }

            dispatchGroup.enter()
            AdMobHelper.preloadingKeys.insert(request.cacheKey)

            debugPrint("⏳ [VUNT_CACHE] Preloading ad for key: \(request.cacheKey)")

            // Create ad loader delegate and store it to prevent deallocation
            let delegateHelper = CacheNativeAdLoaderDelegate(cacheKey: request.cacheKey)
            AdMobHelper.activeDelegates[request.cacheKey] = delegateHelper

            delegateHelper.onAdLoaded = { [weak self] (nativeAd: NativeAd) in
                guard let self = self else {
                    dispatchGroup.leave()
                    return
                }

                debugPrint("✅ [VUNT_CACHE] onAdLoaded closure executing for key: \(request.cacheKey)")

                // Cache the ad
                self.cacheNativeAd(nativeAd, for: request.cacheKey)
                AdMobHelper.preloadingKeys.remove(request.cacheKey)
                AdMobHelper.activeDelegates.removeValue(forKey: request.cacheKey)
                AdMobHelper.activeAdLoaders.removeValue(forKey: request.cacheKey)
                successCount += 1
                dispatchGroup.leave()
            }

            delegateHelper.onAdFailed = { (error: Error) in
                debugPrint("❌ [VUNT_CACHE] onAdFailed closure executing for key: \(request.cacheKey)")
                debugPrint("❌ [VUNT_CACHE] Failed to preload ad for key: \(request.cacheKey) - \(error.localizedDescription)")
                AdMobHelper.preloadingKeys.remove(request.cacheKey)
                AdMobHelper.activeDelegates.removeValue(forKey: request.cacheKey)
                AdMobHelper.activeAdLoaders.removeValue(forKey: request.cacheKey)
                dispatchGroup.leave()
            }

            // Load the ad (use a dummy root VC for preloading)
            let dummyVC = UIViewController()
            let adLoader = self.loadNativeAd(
                adUnitID: request.adUnitID,
                rootViewController: dummyVC,
                delegate: delegateHelper
            )

            // Store AdLoader to prevent it from being deallocated
            AdMobHelper.activeAdLoaders[request.cacheKey] = adLoader
            debugPrint("📡 [VUNT_CACHE] AdLoader created and retained for key: \(request.cacheKey), loading request sent")
        }

        // Wait for all preloads to complete
        dispatchGroup.notify(queue: .main) {
            debugPrint("✅ [VUNT_CACHE] Preload completed: \(successCount)/\(totalCount) ads")
            completion?(successCount)
        }
    }

    /// Load native ad with auto-cache support (simplified API)
    /// - Parameters:
    ///   - containerView: The view container to add the native ad view to
    ///   - adUnitID: The ad unit identifier
    ///   - rootViewController: The view controller that will present the ad
    ///   - viewType: The type of native ad view template to use
    ///   - configuration: Optional configuration for customizing appearance
    ///   - enableCache: Enable auto-caching using adUnitID as key (default: true)
    ///   - statusCallback: Optional callback to notify success or failure
    public func loadNativeAd(
        containerView: UIView,
        adUnitID: AdUnitIdentifiable,
        rootViewController: UIViewController,
        viewType: NativeAdService.NativeAdViewType,
        configuration: NativeAdConfiguration? = nil,
        enableCache: Bool = true,
        statusCallback: ((Bool) -> Void)? = nil
    ) {
        // Auto-generate cache key from ad unit ID if cache is enabled
        let cacheKey = enableCache ? adUnitID.adUnitIDString : nil

        // Use the existing loadNativeAdWithCache implementation
        loadNativeAdWithCache(
            containerView: containerView,
            adUnitID: adUnitID,
            rootViewController: rootViewController,
            viewType: viewType,
            configuration: configuration,
            cacheKey: cacheKey,
            statusCallback: statusCallback
        )
    }

    /// Load native ad with cache support (manual cache key)
    /// - Parameters:
    ///   - containerView: The view container to add the native ad view to
    ///   - adUnitID: The ad unit identifier
    ///   - rootViewController: The view controller that will present the ad
    ///   - viewType: The type of native ad view template to use
    ///   - configuration: Optional configuration for customizing appearance
    ///   - cacheKey: Optional cache key for storing/retrieving cached ad
    ///   - statusCallback: Optional callback to notify success or failure
    public func loadNativeAdWithCache(
        containerView: UIView,
        adUnitID: AdUnitIdentifiable,
        rootViewController: UIViewController,
        viewType: NativeAdService.NativeAdViewType,
        configuration: NativeAdConfiguration? = nil,
        cacheKey: String?,
        statusCallback: ((Bool) -> Void)? = nil
    ) {
        // Try to use cached ad first if cache key provided
        if let cacheKey = cacheKey,
           let cachedAd = getCachedNativeAd(for: cacheKey) {
            debugPrint("✅ [VUNT_CACHE] Using cached ad for key: \(cacheKey)")
            displayCachedNativeAd(
                cachedAd,
                in: containerView,
                viewType: viewType,
                configuration: configuration,
                cacheKey: cacheKey,
                statusCallback: statusCallback
            )
            return
        }

        // No cached ad available, load from network
        if let cacheKey = cacheKey {
            debugPrint("⏳ [VUNT_CACHE] No cached ad for key: '\(cacheKey)', loading from network...")
        }

        let nativeService = NativeAdService()
        nativeService.loadNativeAdFromNetworkWithCache(
            containerView: containerView,
            adUnitID: adUnitID,
            rootViewController: rootViewController,
            viewType: viewType,
            configuration: configuration,
            cacheKey: cacheKey,
            statusCallback: statusCallback
        )
    }

    /// Display a cached native ad in container view
    private func displayCachedNativeAd(
        _ nativeAd: NativeAd,
        in containerView: UIView,
        viewType: NativeAdService.NativeAdViewType,
        configuration: NativeAdConfiguration?,
        cacheKey: String,
        statusCallback: ((Bool) -> Void)?
    ) {
        // Clear existing subviews
        containerView.subviews.forEach { $0.removeFromSuperview() }

        // Load native ad view from xib
        let xibName: String
        switch viewType {
        case .small:
            xibName = "NativeAdViewSmall"
        case .medium:
            xibName = "NativeAdViewMedium"
        }

        guard let nativeAdView = Bundle.main.loadNibNamed(xibName, owner: nil, options: nil)?.first as? NativeAdView else {
            debugPrint("❌ [VUNT_CACHE] Failed to load native ad view from xib: \(xibName)")
            statusCallback?(false)
            return
        }

        // Set native ad to view
        nativeAdView.nativeAd = nativeAd

        // Set delegate to track native ad clicks
        nativeAd.delegate = AdMobHelper.shared

        // Use provided configuration or fall back to shared singleton
        let configToUse = configuration ?? NativeAdConfiguration.shared

        // Apply configuration using the view's built-in applyConfiguration method
        // This ensures all styling (border, background, gradient, fonts, colors, etc.) is applied correctly
        if let mediumView = nativeAdView as? NativeAdViewMedium {
            mediumView.applyConfiguration(configToUse)
        } else if let smallView = nativeAdView as? NativeAdViewSmall {
            smallView.applyConfiguration(configToUse)
        }

        // Populate the views with ad data
        // Headline
        if let headlineView = nativeAdView.headlineView as? UILabel {
            headlineView.text = nativeAd.headline
        }

        // Body
        if let bodyView = nativeAdView.bodyView as? UILabel {
            bodyView.text = nativeAd.body
        }

        // Call to action button
        if let callToActionView = nativeAdView.callToActionView as? UIButton {
            callToActionView.setTitle(nativeAd.callToAction, for: .normal)
        }

        // Icon
        if let iconView = nativeAdView.iconView as? UIImageView,
           let icon = nativeAd.icon?.image {
            iconView.image = icon
        }

        // Media view
        if let mediaView = nativeAdView.mediaView {
            mediaView.mediaContent = nativeAd.mediaContent
        }

        // Add view to container
        containerView.addSubview(nativeAdView)
        nativeAdView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Force layout update
        containerView.setNeedsLayout()
        containerView.layoutIfNeeded()
        nativeAdView.setNeedsLayout()
        nativeAdView.layoutIfNeeded()

        debugPrint("✅ [VUNT_CACHE] Displayed cached ad with all data populated")

        // Store cache key association for impression tracking
        associateNativeAdCacheKey(cacheKey, with: nativeAd)
        debugPrint("📦 [NATIVE_CACHE] Native ad displayed, waiting for impression to clear cache")

        statusCallback?(true)
    }
}
