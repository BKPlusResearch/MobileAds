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

        // Track ad revenue
        nativeAd.paidEventHandler = { adValue in
            ADJustManager.shared.logRevenue(adType: .native, adValue: adValue)
        }

        onAdLoaded?(nativeAd)
    }
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        debugPrint("Native ad failed to load with error: \(error.localizedDescription)")
        onAdFailed?(error)
    }
}


