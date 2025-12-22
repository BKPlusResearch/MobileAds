@preconcurrency import GoogleMobileAds
import UIKit

extension AdMobHelper {
    // MARK: - Rewarded Video Ad
    
    /// Load a rewarded video ad.
    /// - Parameter adUnitID: The ad unit identifier for rewarded video ads.
    public func loadRewardedAd(adUnitID: AdUnitIdentifiable) async throws {
        guard !isRewardedLoading, rewardedAd == nil else {
            return
        }

        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            throw AdMobHelperError.consentNotGranted
        }

        isRewardedLoading = true
        // Show loading view when starting to load ad
        showRewardedAdLoadingView()
        initializeSDK()

        do {
            rewardedAd = try await RewardedAd.load(
                with: adUnitID.adUnitIDString, request: Request())
            rewardedAd?.fullScreenContentDelegate = self

            // Track ad revenue
            rewardedAd?.paidEventHandler = { adValue in
                ADJustManager.shared.logRevenue(adType: .reward, adValue: adValue)
            }

            print("Rewarded ad loaded successfully")
        } catch {
            print("Rewarded ad failed to load with error: \(error.localizedDescription)")
            rewardedAd = nil
            // Hide loading view when load fails
            hideRewardedAdLoadingView()
            throw error
        }

        isRewardedLoading = false
    }
    
    /// Show a rewarded video ad from the specified view controller.
    /// - Parameters:
    ///   - viewController: The view controller to present the ad from.
    ///   - adUnitID: The ad unit identifier for rewarded video ads (used to load if not already loaded).
    ///   - statusCallback: Optional callback to receive ad status events (didPresent, didFailToPresent, didDismiss, didEarnReward).
    ///   - completion: Callback with the reward when the user earns it.
    public func showRewardedAd(
        from viewController: UIViewController,
        adUnitID: AdUnitIdentifiable,
        statusCallback: ((RewardedAdStatus) -> Void)? = nil,
        completion: @escaping (AdReward) -> Void
    ) async throws {
        guard !isRewardedShowing else {
            throw AdMobHelperError.adAlreadyShowing
        }

        // Store callback for status events
        rewardedAdStatusCallback = statusCallback

        if rewardedAd == nil {
            try await loadRewardedAd(adUnitID: adUnitID)
        }

        guard let rewardedAd = rewardedAd else {
            throw AdMobHelperError.adNotLoaded
        }

        // Loading view should already be showing from loadRewardedAd
        // If not showing, show it now (in case ad was pre-loaded)
        if rewardedAdLoadingView == nil {
            showRewardedAdLoadingView()
        }

        // Skip next app resume ad since rewarded ad is showing
        shouldSkipNextAppResume = true

        isRewardedShowing = true
        didEarnRewardForCurrentAd = false  // Reset flag before showing
        rewardedAd.present(from: viewController) { [weak self] in
            let reward = rewardedAd.adReward
            print("Reward received with currency \(reward.type), amount \(reward.amount.doubleValue)")
            // Mark that reward was earned
            self?.didEarnRewardForCurrentAd = true
            // Notify that reward was earned
            statusCallback?(.didEarnReward)
            completion(reward)
        }
    }
}


