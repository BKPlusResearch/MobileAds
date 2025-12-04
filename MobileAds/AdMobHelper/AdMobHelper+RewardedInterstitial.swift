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
        initializeSDK()

        do {
            rewardedInterstitialAd = try await RewardedInterstitialAd.load(
                with: adUnitID.adUnitIDString, request: Request())
            rewardedInterstitialAd?.fullScreenContentDelegate = self
            print("Rewarded interstitial ad loaded successfully")
        } catch {
            print(
                "Rewarded interstitial ad failed to load with error: \(error.localizedDescription)")
            rewardedInterstitialAd = nil
            throw error
        }

        isRewardedInterstitialLoading = false
    }
    
    /// Show a rewarded interstitial ad from the specified view controller.
    /// - Parameters:
    ///   - viewController: The view controller to present the ad from.
    ///   - adUnitID: The ad unit identifier for rewarded interstitial ads (used to load if not already loaded).
    ///   - completion: Callback with the reward when the user earns it.
    public func showRewardedInterstitialAd(
        from viewController: UIViewController,
        adUnitID: AdUnitIdentifiable,
        completion: @escaping (AdReward) -> Void
    ) async throws {
        guard !isRewardedInterstitialShowing else {
            throw AdMobHelperError.adAlreadyShowing
        }

        if rewardedInterstitialAd == nil {
            try await loadRewardedInterstitialAd(adUnitID: adUnitID)
        }

        guard let rewardedInterstitialAd = rewardedInterstitialAd else {
            throw AdMobHelperError.adNotLoaded
        }

        isRewardedInterstitialShowing = true
        rewardedInterstitialAd.present(from: viewController) {
            let reward = rewardedInterstitialAd.adReward
            print(
                "Reward received with currency \(reward.amount), amount \(reward.amount.doubleValue)")
            completion(reward)
        }
    }
}


