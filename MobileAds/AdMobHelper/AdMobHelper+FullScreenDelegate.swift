@preconcurrency import GoogleMobileAds
import UIKit

// MARK: - FullScreenContentDelegate

extension AdMobHelper: FullScreenContentDelegate {
    public func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        debugPrint("Ad recorded an impression.")
        if let adUnit = fullScreenAdUnitIDs[ObjectIdentifier(ad)] {
            AdMetricsTracker.shared.trackImpression(adUnit: adUnit)
        }
    }

    public func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        debugPrint("Ad recorded a click.")
        if let adUnit = fullScreenAdUnitIDs[ObjectIdentifier(ad)] {
            AdMetricsTracker.shared.trackClick(adUnit: adUnit)
        }
        
        // Mark ad click (will verify in background handler if app actually leaves)
        markAdClick()
    }

    public func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        debugPrint("Ad will be presented.")
        if let adUnit = fullScreenAdUnitIDs[ObjectIdentifier(ad)] {
            AdMetricsTracker.shared.trackShow(adUnit: adUnit)
        }
        
        // Hide loading view when ad is about to be presented (success case)
        if ad === appOpenAd {
            trackFullScreenAd(kind: "aoa", action: "show", screen: appOpenTrackingScreen, params: appOpenTrackingParams)
            hideAppOpenAdLoadingView()
            // Notify that ad was presented successfully
            appOpenAdStatusCallback?(.didPresent)
        } else if ad === interstitialAd {
            trackFullScreenAd(kind: "inter", action: "show", screen: interstitialTrackingScreen, params: interstitialTrackingParams)
            hideInterstitialAdLoadingView()
            // Notify that ad was presented successfully
            interstitialAdStatusCallback?(.didPresent)
        } else if ad === rewardedAd {
            hideRewardedAdLoadingView()
            // Notify that ad was presented successfully
            rewardedAdStatusCallback?(.didPresent)
        } else if ad === rewardedInterstitialAd {
            rewardedInterstitialAdStatusCallback?(.didPresent)
        }
    }

    public func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        debugPrint("Ad will be dismissed.")
        
        // Notify that ad will be dismissed
        if ad === appOpenAd {
            appOpenAdStatusCallback?(.willDismiss)
        } else if ad === interstitialAd {
            interstitialAdStatusCallback?(.willDismiss)
        } else if ad === rewardedAd {
            rewardedAdStatusCallback?(.willDismiss)
        } else if ad === rewardedInterstitialAd {
            rewardedInterstitialAdStatusCallback?(.willDismiss)
        }
    }

    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        debugPrint("Ad was dismissed.")

        // Clean up ad unit ID mapping
        fullScreenAdUnitIDs.removeValue(forKey: ObjectIdentifier(ad))
        ScreenTracker.endFullScreenAd()

        // Clear the ad and reset showing state
        if ad === interstitialAd {
            trackFullScreenAd(kind: "inter", action: "close", screen: interstitialTrackingScreen, params: interstitialTrackingParams)
            interstitialTrackingScreen = nil
            interstitialTrackingParams = nil
            // Notify that ad was dismissed
            interstitialAdStatusCallback?(.didDismiss)
            interstitialAdStatusCallback = nil
            
            interstitialAd = nil
            isInterstitialShowing = false
        } else if ad === rewardedAd {
            // Notify based on whether reward was earned
            if didEarnRewardForCurrentAd {
                rewardedAdStatusCallback?(.didEarnRewardAndDismiss)
            } else {
                rewardedAdStatusCallback?(.didDismiss)
            }
            rewardedAdStatusCallback = nil
            didEarnRewardForCurrentAd = false  // Reset flag
            
            rewardedAd = nil
            isRewardedShowing = false
        } else if ad === rewardedInterstitialAd {
            rewardedInterstitialAdStatusCallback?(.didDismiss)
            rewardedInterstitialAdStatusCallback = nil
            rewardedInterstitialAd = nil
            isRewardedInterstitialShowing = false
        } else if ad === appOpenAd {
            trackFullScreenAd(kind: "aoa", action: "close", screen: appOpenTrackingScreen, params: appOpenTrackingParams)
            appOpenTrackingScreen = nil
            appOpenTrackingParams = nil
            // Notify that ad was dismissed
            appOpenAdStatusCallback?(.didDismiss)
            appOpenAdStatusCallback = nil
            
            appOpenAd = nil
            appOpenLoadTime = nil
            isAppOpenShowing = false
        }
    }

    public func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        debugPrint("Ad failed to present with error: \(error.localizedDescription)")

        // Clean up ad unit ID mapping
        fullScreenAdUnitIDs.removeValue(forKey: ObjectIdentifier(ad))
        ScreenTracker.endFullScreenAd()

        // Clear the ad and reset showing state
        if ad === interstitialAd {
            trackFullScreenAd(kind: "inter", action: "show_fail", screen: interstitialTrackingScreen,
                              params: interstitialTrackingParams, error: error)
            interstitialTrackingScreen = nil
            interstitialTrackingParams = nil
            // Hide loading view
            hideInterstitialAdLoadingView()
            
            // Notify that ad failed to present
            interstitialAdStatusCallback?(.didFailToPresent)
            interstitialAdStatusCallback = nil
            
            interstitialAd = nil
            isInterstitialShowing = false
        } else if ad === rewardedAd {
            // Hide loading view
            hideRewardedAdLoadingView()
            
            // Notify that ad failed to present
            rewardedAdStatusCallback?(.didFailToPresent)
            rewardedAdStatusCallback = nil
            didEarnRewardForCurrentAd = false  // Reset flag
            
            rewardedAd = nil
            isRewardedShowing = false
        } else if ad === rewardedInterstitialAd {
            rewardedInterstitialAdStatusCallback?(.didFailToPresent)
            rewardedInterstitialAdStatusCallback = nil
            rewardedInterstitialAd = nil
            isRewardedInterstitialShowing = false
        } else if ad === appOpenAd {
            trackFullScreenAd(kind: "aoa", action: "show_fail", screen: appOpenTrackingScreen,
                              params: appOpenTrackingParams, error: error)
            appOpenTrackingScreen = nil
            appOpenTrackingParams = nil
            // Hide loading view
            hideAppOpenAdLoadingView()
            
            // Notify that ad failed to present
            appOpenAdStatusCallback?(.didFailToPresent)
            appOpenAdStatusCallback = nil
            
            appOpenAd = nil
            appOpenLoadTime = nil
            isAppOpenShowing = false
        }
    }
}

// MARK: - Standard tracking

extension AdMobHelper {
    /// Logs `{app}_{screen}_{aoa|inter}_{show|close|show_fail}`. The screen was captured at show
    /// time; it falls back to the current screen only if a presentation callback arrives without one.
    fileprivate func trackFullScreenAd(
        kind: String,
        action: String,
        screen: String?,
        params: [String: Any]?,
        error: Error? = nil
    ) {
        var eventParams = params ?? [:]
        if let error {
            eventParams["error_code"] = (error as NSError).code
        }
        ScreenTracker.trackFromPod(
            screen: screen ?? ScreenTracker.current,
            action: "\(kind)_\(action)",
            params: eventParams.isEmpty ? nil : eventParams
        )
    }
}
