@preconcurrency import GoogleMobileAds
import UIKit

// MARK: - NativeAdDelegate

extension AdMobHelper: NativeAdDelegate {
    nonisolated public func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
        debugPrint("Native ad recorded a click")

        // Mark ad click (will verify in background handler if app actually leaves)
        Task { @MainActor in
            markAdClick()
        }
    }

    nonisolated public func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
        debugPrint("Native ad recorded an impression")

        // Clear cache AFTER impression fires (critical for show rate optimization)
        Task { @MainActor in
            if let cacheKey = getNativeAdCacheKey(for: nativeAd) {
                clearCachedNativeAd(for: cacheKey)
                debugPrint("🗑️ [NATIVE_CACHE] Cache cleared after impression for '\(cacheKey)'")
            }
        }
    }

    nonisolated public func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {
        debugPrint("Native ad will present screen")
    }

    nonisolated public func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {
        debugPrint("Native ad will dismiss screen")
    }

    nonisolated public func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {
        debugPrint("Native ad dismissed screen")

        // If dismissed in-app screen without going to background, clear the pending flag
        Task { @MainActor in
            clearPendingAdClick()
        }
    }
}

