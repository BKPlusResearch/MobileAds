//
//  NativeAdsServices.swift
//  MobileAds
//
//  Created by diep on 12/8/24.
//

import Foundation
import GoogleMobileAds

open class NativeAdsServices: NSObject {
    var onSuccessed: AdsNativeLoadSuccess?
    var onFailed: AdsNativeLoadFailure?
    
    public func loadAdsNative(with normalAdsID: String, rootVC: UIViewController, numberOfAds: Int, onSuccess: AdsNativeLoadSuccess?, onFail: AdsNativeLoadFailure?) {
        print("Diepnn \(#function)")
        self.onSuccessed = onSuccess
        self.onFailed = onFail
        let multipleAdsOptions = GADMultipleAdsAdLoaderOptions()
        multipleAdsOptions.numberOfAds = numberOfAds
        let adLoader = GADAdLoader(adUnitID: normalAdsID,
            rootViewController: rootVC,
            adTypes: [ .native ],
            options: [multipleAdsOptions])
        adLoader.delegate = self
        adLoader.load(GADRequest())
    }
}

extension NativeAdsServices: GADNativeAdLoaderDelegate {
    
    public func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        print("Diepnn \(#function)")
        onSuccessed?(adLoader.adUnitID, nativeAd)
    }
    
    public func adLoaderDidFinishLoading(_ adLoader: GADAdLoader) {
        //
    }
    
    public func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: any Error) {
        print("Diepnn \(#function)")
        onFailed?(adLoader.adUnitID, error)
    }
}
