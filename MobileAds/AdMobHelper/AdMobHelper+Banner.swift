@preconcurrency import GoogleMobileAds
import UIKit

extension AdMobHelper: BannerViewDelegate {
    // MARK: - Banner Ad
    /// Load and return a banner ad view.
    /// - Parameters:
    ///   - adUnitID: The Ad Unit ID enum for banner ads.
    ///   - rootViewController: The view controller that will present the ad.
    ///   - statusCallback: Optional callback to receive ad status events (didLoad, didFailToLoad, didRecordImpression, etc.).
    /// - Returns: A configured BannerView ready to load ads.
    public func loadBannerAd(
        adUnitID: AdUnitID,
        rootViewController: UIViewController,
        statusCallback: ((BannerAdStatus) -> Void)? = nil
    ) -> BannerView {
        let bannerView = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: 375))
        bannerView.adUnitID = adUnitID.rawValue
        bannerView.rootViewController = rootViewController
        
        // Store banner view and callbacks
        self.bannerAd = bannerView
        self.bannerAdStatusCallback = statusCallback
        
        // Set self as delegate to track events
        bannerView.delegate = self

        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            print("Cannot load banner ad: Consent not granted")
            isBannerLoading = false
            statusCallback?(.didFailToLoad)
            return bannerView
        }

        isBannerLoading = true
        initializeSDK()
        bannerView.load(Request())
        return bannerView
    }
    
    // MARK: - BannerViewDelegate
    
    public func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("Banner ad loaded successfully")
        isBannerLoading = false
        bannerAdStatusCallback?(.didLoad)
    }
    
    public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("Banner ad failed to load with error: \(error.localizedDescription)")
        isBannerLoading = false
        bannerAdStatusCallback?(.didFailToLoad)
    }
    
    public func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        print("Banner ad recorded an impression")
        bannerAdStatusCallback?(.didRecordImpression)
    }
    
    public func bannerViewDidRecordClick(_ bannerView: BannerView) {
        print("Banner ad recorded a click")
        bannerAdStatusCallback?(.didRecordClick)
    }
    
    public func bannerViewWillPresentScreen(_ bannerView: BannerView) {
        print("Banner ad will present screen")
        bannerAdStatusCallback?(.willPresentScreen)
    }
    
    public func bannerViewWillDismissScreen(_ bannerView: BannerView) {
        print("Banner ad will dismiss screen")
        bannerAdStatusCallback?(.willDismissScreen)
    }
    
    public func bannerViewDidDismissScreen(_ bannerView: BannerView) {
        print("Banner ad dismissed screen")
        bannerAdStatusCallback?(.didDismissScreen)
    }
}


