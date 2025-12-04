@preconcurrency import GoogleMobileAds
import UIKit

extension AdMobHelper {
    // MARK: - Interstitial Ad
    
    /// Load an interstitial ad.
    /// - Parameter adUnitID: The Ad Unit ID enum for interstitial ads.
    public func loadInterstitialAd(adUnitID: AdUnitID) async throws {
        guard !isInterstitialLoading, interstitialAd == nil else {
            return
        }

        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            throw AdMobHelperError.consentNotGranted
        }

        isInterstitialLoading = true
        // Show loading view when starting to load ad
        showInterstitialAdLoadingView()
        initializeSDK()

        do {
            interstitialAd = try await InterstitialAd.load(
                with: adUnitID.rawValue, request: Request())
            interstitialAd?.fullScreenContentDelegate = self
            print("Interstitial ad loaded successfully")
        } catch {
            print("Interstitial ad failed to load with error: \(error.localizedDescription)")
            interstitialAd = nil
            // Hide loading view when load fails
            hideInterstitialAdLoadingView()
            throw error
        }

        isInterstitialLoading = false
    }
    
    /// Show an interstitial ad from the specified view controller.
    /// - Parameters:
    ///   - viewController: The view controller to present the ad from.
    ///   - statusCallback: Optional callback to receive ad status events (didPresent, didFailToPresent, didDismiss).
    public func showInterstitialAd(
        from viewController: UIViewController,
        statusCallback: ((InterstitialAdStatus) -> Void)? = nil
    ) throws {
        guard !isInterstitialShowing else {
            throw AdMobHelperError.adAlreadyShowing
        }

        guard let interstitialAd = interstitialAd else {
            throw AdMobHelperError.adNotLoaded
        }

        // Store callback for status events
        interstitialAdStatusCallback = statusCallback
        
        // Loading view should already be showing from loadInterstitialAd
        // If not showing, show it now (in case ad was pre-loaded)
        if interstitialAdLoadingView == nil {
            showInterstitialAdLoadingView()
        }

        isInterstitialShowing = true
        interstitialAd.present(from: viewController)
    }
}


