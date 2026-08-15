@preconcurrency import GoogleMobileAds
import UIKit

extension AdMobHelper {
    // MARK: - Interstitial Ad
    
    /// Load an interstitial ad.
    /// - Parameters:
    ///   - adUnitID: The ad unit identifier for interstitial ads.
    ///   - shouldShowLoadingView: Whether to show loading view during ad load. Default is true.
    public func loadInterstitialAd(
        adUnitID: AdUnitIdentifiable,
        shouldShowLoadingView: Bool = true
    ) async throws {
        guard !isInterstitialLoading, interstitialAd == nil else {
            return
        }

        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            throw AdMobHelperError.consentNotGranted
        }

        isInterstitialLoading = true
        // Released on every exit, including the rethrow below. Clearing it only after the
        // do/catch left the flag stuck true after a single failed load, so the guard above
        // then declined every later interstitial in the process — including the fallback
        // unit callers request straight after a highfloor failure.
        defer { isInterstitialLoading = false }
        AdMetricsTracker.shared.trackRequest(adUnit: adUnitID.adUnitIDString, adType: .interstitial)
        // Show loading view when starting to load ad (if enabled)
        if shouldShowLoadingView {
            showInterstitialAdLoadingView()
        }
        initializeSDK()

        do {
            interstitialAd = try await InterstitialAd.load(
                with: adUnitID.adUnitIDString, request: Request())
            interstitialAd?.fullScreenContentDelegate = self
            if let ad = interstitialAd {
                fullScreenAdUnitIDs[ObjectIdentifier(ad)] = adUnitID.adUnitIDString
            }
            AdMetricsTracker.shared.trackLoaded(adUnit: adUnitID.adUnitIDString)

            // Track ad revenue
            interstitialAd?.paidEventHandler = { adValue in
                ADJustManager.shared.logRevenue(adType: .interstitial, adValue: adValue)
            }

            debugPrint("Interstitial ad loaded successfully")
        } catch {
            debugPrint("Interstitial ad failed to load with error: \(error.localizedDescription)")
            AdMetricsTracker.shared.trackLoadFailed(adUnit: adUnitID.adUnitIDString)
            interstitialAd = nil
            // Hide loading view when load fails
            hideInterstitialAdLoadingView()
            throw error
        }
    }
    
    /// Show an interstitial ad from the specified view controller.
    /// - Parameters:
    ///   - viewController: The view controller to present the ad from.
    ///   - shouldShowLoadingView: Whether to show loading view if not already showing. Default is true.
    ///   - statusCallback: Optional callback to receive ad status events (didPresent, didFailToPresent, didDismiss).
    public func showInterstitialAd(
        from viewController: UIViewController,
        shouldShowLoadingView: Bool = true,
        statusCallback: ((InterstitialAdStatus) -> Void)? = nil
    ) throws {
        guard !isInterstitialShowing else {
            throw AdMobHelperError.adAlreadyShowing
        }

        guard let interstitialAd = interstitialAd else {
            throw AdMobHelperError.adNotLoaded
        }

        // Never present while backgrounded — the ad would render half-presented
        // and its loading overlay would get stuck. Hide the overlay and keep the
        // loaded ad so it can present on the next attempt once foregrounded.
        guard canPresentFullScreenAd else {
            hideInterstitialAdLoadingView()
            throw AdMobHelperError.appInBackground
        }

        // Store callback for status events
        interstitialAdStatusCallback = statusCallback

        // Loading view should already be showing from loadInterstitialAd
        // If not showing, show it now (in case ad was pre-loaded) only if enabled
        if shouldShowLoadingView && interstitialAdLoadingView == nil {
            showInterstitialAdLoadingView()
        }

        // Skip next app resume ad since interstitial is showing
        shouldSkipNextAppResume = true

        isInterstitialShowing = true
        interstitialAd.present(from: viewController)
    }
}


