//
//  NativeAdLoaderDelegateHelper.swift
//  AppTheme
//
//  Created by Auto on 2024.
//

import UIKit
@preconcurrency import GoogleMobileAds

/// Helper class to handle NativeAdLoaderDelegate callbacks
class NativeAdLoaderDelegateHelper: NSObject, NativeAdLoaderDelegate {
    
    /// Callback when native ad is loaded successfully
    var onAdLoaded: ((NativeAd) -> Void)?
    
    /// Callback when native ad fails to load
    var onAdFailed: ((Error) -> Void)?
    
    // MARK: - NativeAdLoaderDelegate
    
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        debugPrint("Native ad loaded successfully")
        let adUnit = adLoader.adUnitID
        Task { @MainActor in
            AdMetricsTracker.shared.trackLoaded(adUnit: adUnit)
        }

        // Store ad unit ID for metrics tracking in delegate callbacks
        AdMobHelper.nativeAdUnitIDMap[nativeAd] = adUnit

        // Track ad revenue
        nativeAd.paidEventHandler = { adValue in
            ADJustManager.shared.logRevenue(adType: .native, adValue: adValue)
        }

        onAdLoaded?(nativeAd)
    }
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        debugPrint("Native ad failed to load with error: \(error.localizedDescription)")
        let adUnit = adLoader.adUnitID
        Task { @MainActor in
            AdMetricsTracker.shared.trackLoadFailed(adUnit: adUnit)
        }
        onAdFailed?(error)
    }
}


