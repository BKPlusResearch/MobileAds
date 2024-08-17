//
//  AdMobManager+Native.swift
//  MobileAds
//
//  Created by macbook on 29/08/2021.
//

import Foundation
import GoogleMobileAds
import SkeletonView
import FirebaseAnalytics

public enum OptionAdType {
    case option_1
    case option_2
}

public enum NativeAdType {
    case small
    case medium
    case unified(OptionAdType)
    case freeSize
    
    var nibName: String {
        switch self {
        case .small:
            return "SmallNativeAdView"
        case .medium:
            return "MediumNativeAdView"
        case .unified(let option):
            switch option {
            case .option_1:
                return "UnifiedNativeAdView"
            case .option_2:
                return "UnifiedNativeAdView_2"
            }
        case .freeSize:
            return  "FreeSizeNativeAdView"
            
        }
    }
}

// MARK: - GADUnifiedNativeAdView
extension AdMobManager {
   
    public func getNativeAdLoader(unitId: AdUnitID) -> GADAdLoader? {
        return listLoader.object(forKey: unitId.rawValue) as? GADAdLoader
    }

    public func getAdNative(unitId: String) -> [GADNativeAdView] {
        if let adNativeView = listAd.object(forKey: unitId) as? [GADNativeAdView] {
            return adNativeView
        }
        return []
    }
    
    public func createAdNativeView(unitId: String, type: NativeAdType = .small, views: [UIView]) {
        let adNativeViews = getAdNative(unitId: unitId)
        removeAd(unitId: unitId)
        if !adNativeViews.isEmpty {
            adNativeViews.forEach { adNativeView in
                adNativeView.removeFromSuperview()
            }
        }
        var nativeViews: [GADNativeAdView] = []
        views.forEach { view in
            guard
                let nibObjects = Bundle.main.loadNibNamed(type.nibName, owner: nil, options: nil),
                let adNativeView = nibObjects.first as? GADNativeAdView else {
                    return
                }
            view.addSubview(adNativeView)
            adNativeView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            adNativeView.layoutIfNeeded()
            nativeViews.append(adNativeView)
        }
        
        listAd.setObject(nativeViews, forKey: unitId as NSCopying)
    }
    
    public func reloadAdNative(unitId: AdUnitID) {
        if let loader = self.getNativeAdLoader(unitId: unitId) {
            loader.load(GADRequest())
        }
    }
    
    public func addAdNative(unitId: String, rootVC: UIViewController, views: [UIView], type: NativeAdType = .small) {
        views.forEach{$0.tag = 0}
        createAdNativeView(unitId: unitId, type: type, views: views)
        loadAdNative(unitId: unitId, rootVC: rootVC, numberOfAds: views.count)
    }
    
    public func addAdNativeWithPreloadedAds(unitId: String, preloadedAds: GADNativeAd, rootVC: UIViewController, views: [UIView], type: NativeAdType = .small) {
        views.forEach{$0.tag = 0}
        createAdNativeView(unitId: unitId, type: type, views: views)
        renderAdNative(adUnitID: unitId, ads: preloadedAds)
    }
    
    public func loadAdNative(unitId: String, rootVC: UIViewController, numberOfAds: Int) {
        let multipleAdsOptions = GADMultipleAdsAdLoaderOptions()
        multipleAdsOptions.numberOfAds = numberOfAds
        let adLoader = GADAdLoader(adUnitID: unitId,
            rootViewController: rootVC,
            adTypes: [ .native ],
            options: [multipleAdsOptions])
        listLoader.setObject(adLoader, forKey: unitId as NSCopying)
        adLoader.delegate = self
        adLoader.load(GADRequest())
    }
    
    public func renderAdNative(adUnitID: String, ads: GADNativeAd) {
        guard let nativeAdView = self.getAdNative(unitId: adUnitID).first(where: {$0.tag == 0}) else {return}
        nativeAdView.tag = 2
        ads.mediaContent.videoController.delegate = self
        if let nativeAdView = nativeAdView as? UnifiedNativeAdView {
            nativeAdView.adUnitID = adUnitID
//            nativeAdView.hideSkeleton()
            nativeAdView.hideLoadingView()
            nativeAdView.bindingData(nativeAd: ads)
        } else if let nativeAdView = nativeAdView as? UnifiedNativeAdView_2 {
            nativeAdView.adUnitID = adUnitID
//            nativeAdView.hideSkeleton()
            nativeAdView.hideLoadingView()
            nativeAdView.bindingData(nativeAd: ads)
        } else if let nativeAdView = nativeAdView as? SmallNativeAdView {
            nativeAdView.adUnitID = adUnitID
            nativeAdView.bindingData(nativeAd: ads)
        } else if let nativeAdView = nativeAdView as? MediumNativeAdView {
            nativeAdView.adUnitID = adUnitID
            nativeAdView.bindingData(nativeAd: ads)
        } else if let nativeAdView = nativeAdView as? FreeSizeNativeAdView {
            nativeAdView.adUnitID = adUnitID
            nativeAdView.bindingData(nativeAd: ads)
        }
    }
}

// MARK: - GADUnifiedNativeAdDelegate
extension AdMobManager: GADNativeAdDelegate {
    public func nativeAdDidRecordClick(_ nativeAd: GADNativeAd) {
        print("ad==> nativeAdDidRecordClick ")
        logEvenClick(format: "ad_native")
    }
}

// MARK: - GADAdLoaderDelegate
extension AdMobManager: GADAdLoaderDelegate {
    
    
    public func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        self.blockNativeFaild?(adLoader.adUnitID)
        self.removeAd(unitId: adLoader.adUnitID)
    }
    
    public func adLoaderDidFinishLoading(_ adLoader: GADAdLoader) {
        print("ad==> adLoaderDidFinishLoading \(adLoader)")
    }
}

// MARK: - GADUnifiedNativeAdLoaderDelegate
extension AdMobManager: GADNativeAdLoaderDelegate {
    public func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        nativeAd.delegate = self
        nativeAd.paidEventHandler = {[weak self] value in
            let responseInfo = nativeAd.responseInfo.loadedAdNetworkResponseInfo
            self?.blockLogNativeLoadSuccess?(adLoader.adUnitID,
                                             value.precision.rawValue,
                                             Int(truncating: value.value),
                                             responseInfo?.adSourceID ?? "",
                                             responseInfo?.adSourceName ?? "")
        }
        self.renderAdNative(adUnitID: adLoader.adUnitID, ads: nativeAd)
    }
    
    public func nativeAdDidRecordImpression(_ nativeAd: GADNativeAd) {
        print("ad==> nativeAdDidRecordImpression")
    }
    
}

// MARK: - GADVideoControllerDelegate
extension AdMobManager: GADVideoControllerDelegate {
    
}
