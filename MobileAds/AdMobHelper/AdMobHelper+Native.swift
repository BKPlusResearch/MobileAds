@preconcurrency import GoogleMobileAds
import UIKit

extension AdMobHelper {
    // MARK: - Native Advanced Ad
    
    /// Load a native advanced ad using AdLoader.
    /// - Parameters:
    ///   - adUnitID: The Ad Unit ID enum for native advanced ads.
    ///   - rootViewController: The view controller that will present the ad.
    ///   - delegate: The native ad loader delegate.
    /// - Returns: An AdLoader instance configured to load native ads.
    public func loadNativeAd(
        adUnitID: AdUnitID,
        rootViewController: UIViewController,
        delegate: NativeAdLoaderDelegate
    ) -> AdLoader {
        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            print("Cannot load native ad: Consent not granted")
            return AdLoader(
                adUnitID: adUnitID.rawValue, rootViewController: rootViewController,
                adTypes: [.native], options: nil)
        }

        initializeSDK()
        let adLoader = AdLoader(
            adUnitID: adUnitID.rawValue, rootViewController: rootViewController,
            adTypes: [.native], options: nil)
        adLoader.delegate = delegate
        adLoader.load(Request())
        return adLoader
    }
}


