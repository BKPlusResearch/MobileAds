@preconcurrency import GoogleMobileAds
import UIKit

// MARK: - NativeAdDelegate

extension AdMobHelper: NativeAdDelegate {
    public func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
        print("Native ad recorded a click")
        
        // Mark ad click (will verify in background handler if app actually leaves)
        markAdClick()
    }
    
    public func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
        print("Native ad recorded an impression")
    }
    
    public func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {
        print("Native ad will present screen")
    }
    
    public func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {
        print("Native ad will dismiss screen")
    }
    
    public func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {
        print("Native ad dismissed screen")
        
        // If dismissed in-app screen without going to background, clear the pending flag
        clearPendingAdClick()
    }
}

