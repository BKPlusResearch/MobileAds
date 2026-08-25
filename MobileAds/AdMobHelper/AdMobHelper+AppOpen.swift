@preconcurrency import GoogleMobileAds
import UIKit

extension AdMobHelper {
    // MARK: - App Open Ad
    
    /// Check if app open ad was loaded less than timeout interval ago.
    private func wasLoadTimeLessThanNHoursAgo(timeoutInterval: TimeInterval) -> Bool {
        if let loadTime = appOpenLoadTime {
            return Date().timeIntervalSince(loadTime) < timeoutInterval
        }
        return false
    }

    /// Check if app open ad is available and not expired.
    private func isAppOpenAdAvailable() -> Bool {
        return appOpenAd != nil
        && wasLoadTimeLessThanNHoursAgo(timeoutInterval: appOpenTimeoutInterval)
    }

    /// Load an app open ad.
    /// - Parameters:
    ///   - adUnitID: The ad unit identifier for app open ads.
    ///   - shouldShowLoadingView: Whether to show loading view during ad load. Default is true.
    public func loadAppOpenAd(
        adUnitID: AdUnitIdentifiable,
        shouldShowLoadingView: Bool = true
    ) async throws {
        // Do not load if another fullscreen ad is already showing
        guard !isInterstitialShowing, !isRewardedShowing, !isRewardedInterstitialShowing else {
            debugPrint("AdMobHelper: Skipping app open ad load — another fullscreen ad is showing.")
            return
        }
        // Do not load ad if there is an unused ad or one is already loading.
        if isAppOpenLoading || isAppOpenAdAvailable() {
            return
        }

        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            throw AdMobHelperError.consentNotGranted
        }

        isAppOpenLoading = true
        // Released on every exit, including the rethrow below. Clearing it only after the
        // do/catch left the flag stuck true after a single failed load, and the guard
        // above then returned without requesting anything for the rest of the process —
        // killing the fallback unit and every later app open ad, splash and resume alike.
        defer { isAppOpenLoading = false }
        AdMetricsTracker.shared.trackRequest(adUnit: adUnitID.adUnitIDString, adType: .appOpen)
        // Show loading view when starting to load ad (if enabled)
        if shouldShowLoadingView {
            showAppOpenAdLoadingView()
        }
        initializeSDK()

        do {
            appOpenAd = try await AppOpenAd.load(
                with: adUnitID.adUnitIDString, request: Request())
            appOpenAd?.fullScreenContentDelegate = self
            appOpenLoadTime = Date()
            if let ad = appOpenAd {
                fullScreenAdUnitIDs[ObjectIdentifier(ad)] = adUnitID.adUnitIDString
            }
            AdMetricsTracker.shared.trackLoaded(adUnit: adUnitID.adUnitIDString)

            // Track ad revenue
            appOpenAd?.paidEventHandler = { adValue in
                AdRevenueManager.shared.logRevenue(adType: .appOpen, adValue: adValue)
            }

            debugPrint("App open ad loaded successfully")
            // Hide loading view when load completes successfully
            // Keep it showing if we're about to show the ad immediately
        } catch {
            debugPrint("App open ad failed to load with error: \(error.localizedDescription)")
            AdMetricsTracker.shared.trackLoadFailed(adUnit: adUnitID.adUnitIDString)
            appOpenAd = nil
            appOpenLoadTime = nil
            // Hide loading view when load fails
            hideAppOpenAdLoadingView()
            throw error
        }
    }

    /// Show an app open ad if available.
    /// - Parameters:
    ///   - viewController: The view controller to present the ad from (can be nil for app open).
    ///   - statusCallback: Optional callback to receive ad status events (didPresent, didFailToPresent, didDismiss).
    /// - Returns: True if ad was shown, false otherwise.

    public func showAppOpenAd(
        from viewController: UIViewController? = nil,
        shouldShowLoadingView: Bool = true,
        statusCallback: ((AppOpenAdStatus) -> Void)? = nil
    ) {
        // If the app open ad is already showing, do not show the ad again.
        if isAppOpenShowing {
            debugPrint("App open ad is already showing.")
            return
        }

        // If any other ad type is showing, skip app open ad
        if isInterstitialShowing {
            debugPrint("Interstitial ad is showing, skipping app open ad.")
            return
        }

        if isRewardedShowing {
            debugPrint("Rewarded ad is showing, skipping app open ad.")
            return
        }

        if isRewardedInterstitialShowing {
            debugPrint("Rewarded interstitial ad is showing, skipping app open ad.")
            return
        }

        // If the app open ad is not available yet, return false.
        if !isAppOpenAdAvailable() {
            debugPrint("App open ad is not ready yet.")
            return
        }

        // Never present while backgrounded — the ad would render half-presented
        // and its loading overlay would get stuck. Hide the overlay, report the
        // failure, and keep the loaded ad for the next foreground attempt.
        guard canPresentFullScreenAd else {
            debugPrint("App is backgrounded, skipping app open ad.")
            hideAppOpenAdLoadingView()
            statusCallback?(.didFailToPresent)
            return
        }

        if let appOpenAd = appOpenAd {
            // Store callback for status events
            appOpenAdStatusCallback = statusCallback
            
            // Loading view should already be showing from loadAppOpenAd
            // Show loading view if enabled and not already showing
            if shouldShowLoadingView && appOpenAdLoadingView == nil {
                showAppOpenAdLoadingView()
            }
            
            appOpenAd.present(from: viewController)
            isAppOpenShowing = true
            return
        }
    }
}


