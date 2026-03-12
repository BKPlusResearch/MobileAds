@preconcurrency import GoogleMobileAds
import UIKit

// MARK: - NativeAdDelegate

extension AdMobHelper: NativeAdDelegate {
    nonisolated public func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
        debugPrint("Native ad recorded a click")

        // Track metrics + Mark ad click
        Task { @MainActor in
            AdMobHelper.shared.nativeAdStatusCallback?(.didRecordClick)
            // Use ad unit ID for metrics (matches request/loaded tracking key)
            if let adUnitID = AdMobHelper.nativeAdUnitIDMap[nativeAd] {
                AdMetricsTracker.shared.trackClick(adUnit: adUnitID)
            }
            markAdClick()
        }
    }

    nonisolated public func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
        debugPrint("Native ad recorded an impression")

        // Track metrics + Clear cache AFTER impression fires
        Task { @MainActor in
            AdMobHelper.shared.nativeAdStatusCallback?(.didRecordImpression)
            // Use ad unit ID for metrics (matches request/loaded tracking key)
            if let adUnitID = AdMobHelper.nativeAdUnitIDMap[nativeAd] {
                AdMetricsTracker.shared.trackImpression(adUnit: adUnitID)
                // Clean up mapping
                AdMobHelper.nativeAdUnitIDMap.removeValue(forKey: nativeAd)
            }
            if let cacheKey = getNativeAdCacheKey(for: nativeAd) {
                clearCachedNativeAd(for: cacheKey)
                debugPrint("🗑️ [NATIVE_CACHE] Cache cleared after impression for '\(cacheKey)'")
            }
        }
    }

    nonisolated public func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {
        debugPrint("Native ad will present screen")
        Task { @MainActor in
            AdMobHelper.shared.nativeAdStatusCallback?(.willPresentScreen)
        }
    }

    nonisolated public func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {
        debugPrint("Native ad will dismiss screen")
        Task { @MainActor in
            AdMobHelper.shared.nativeAdStatusCallback?(.willDismissScreen)
        }
    }

    nonisolated public func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {
        debugPrint("Native ad dismissed screen")

        // If dismissed in-app screen without going to background, clear the pending flag
        Task { @MainActor in
            AdMobHelper.shared.nativeAdStatusCallback?(.didDismissScreen)
            clearPendingAdClick()
        }
    }
}

