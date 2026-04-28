@preconcurrency import GoogleMobileAds
import UIKit

extension AdMobHelper {
    // MARK: - Rewarded Interstitial Ad
    
    /// Load a rewarded interstitial ad.
    /// - Parameter adUnitID: The ad unit identifier for rewarded interstitial ads.
    public func loadRewardedInterstitialAd(adUnitID: AdUnitIdentifiable) async throws {
        guard !isRewardedInterstitialLoading, rewardedInterstitialAd == nil else {
            return
        }

        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            throw AdMobHelperError.consentNotGranted
        }

        isRewardedInterstitialLoading = true
        AdMetricsTracker.shared.trackRequest(adUnit: adUnitID.adUnitIDString, adType: .reward)
        initializeSDK()

        do {
            rewardedInterstitialAd = try await RewardedInterstitialAd.load(
                with: adUnitID.adUnitIDString, request: Request())
            rewardedInterstitialAd?.fullScreenContentDelegate = self
            if let ad = rewardedInterstitialAd {
                fullScreenAdUnitIDs[ObjectIdentifier(ad)] = adUnitID.adUnitIDString
            }
            AdMetricsTracker.shared.trackLoaded(adUnit: adUnitID.adUnitIDString)

            // Track ad revenue
            rewardedInterstitialAd?.paidEventHandler = { adValue in
                ADJustManager.shared.logRevenue(adType: .reward, adValue: adValue)
            }

            debugPrint("Rewarded interstitial ad loaded successfully")
        } catch {
            debugPrint(
                "Rewarded interstitial ad failed to load with error: \(error.localizedDescription)")
            AdMetricsTracker.shared.trackLoadFailed(adUnit: adUnitID.adUnitIDString)
            rewardedInterstitialAd = nil
            throw error
        }

        isRewardedInterstitialLoading = false
    }
    
    /// Show a rewarded interstitial ad from the specified view controller.
    /// - Parameters:
    ///   - viewController: The view controller to present the ad from.
    ///   - adUnitID: The ad unit identifier for rewarded interstitial ads (used to load if not already loaded).
    ///   - statusCallback: Optional callback to receive ad status events (didPresent, didFailToPresent, didDismiss, didEarnReward).
    ///   - completion: Callback with the reward when the user earns it.
    public func showRewardedInterstitialAd(
        from viewController: UIViewController,
        adUnitID: AdUnitIdentifiable,
        statusCallback: ((RewardedAdStatus) -> Void)? = nil,
        completion: @escaping (AdReward) -> Void
    ) async throws {
        guard !isRewardedInterstitialShowing else {
            throw AdMobHelperError.adAlreadyShowing
        }

        // Store callback for status events
        rewardedInterstitialAdStatusCallback = statusCallback

        if rewardedInterstitialAd == nil {
            try await loadRewardedInterstitialAd(adUnitID: adUnitID)
        }

        guard let rewardedInterstitialAd = rewardedInterstitialAd else {
            throw AdMobHelperError.adNotLoaded
        }

        // Skip next app resume ad since rewarded interstitial ad is showing
        shouldSkipNextAppResume = true

        isRewardedInterstitialShowing = true
        rewardedInterstitialAd.present(from: viewController) {
            let reward = rewardedInterstitialAd.adReward
            debugPrint(
                "Reward received with currency \(reward.amount), amount \(reward.amount.doubleValue)")
            statusCallback?(.didEarnReward)
            completion(reward)
        }
    }
}


