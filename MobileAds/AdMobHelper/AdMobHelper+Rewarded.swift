@preconcurrency import GoogleMobileAds
import UIKit

extension AdMobHelper {
    /// Ready inventory must match the requested unit and be less than one hour old.
    public func isRewardedAdReady(adUnitID: AdUnitIdentifiable) -> Bool {
        guard !isRewardedShowing, let ad = rewardedAd, let loaded = rewardedLoadTime else { return false }
        return fullScreenAdUnitIDs[ObjectIdentifier(ad)] == adUnitID.adUnitIDString
            && Date().timeIntervalSince(loaded) >= 0 && Date().timeIntervalSince(loaded) < 3600
    }

    public func discardCachedRewardedAd() {
        guard !isRewardedShowing else { return }
        if let ad = rewardedAd { fullScreenAdUnitIDs.removeValue(forKey: ObjectIdentifier(ad)) }
        rewardedAd = nil
        rewardedLoadTime = nil
    }
    // MARK: - Rewarded Video Ad
    
    /// Load a rewarded video ad.
    /// - Parameter adUnitID: The ad unit identifier for rewarded video ads.
    public func loadRewardedAd(adUnitID: AdUnitIdentifiable, showLoading: Bool = true) async throws {
        guard !isRewardedLoading else { throw AdMobHelperError.adLoadInProgress }
        guard !isRewardedShowing else { throw AdMobHelperError.adAlreadyShowing }
        if isRewardedAdReady(adUnitID: adUnitID) { return }
        discardCachedRewardedAd()

        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            throw AdMobHelperError.consentNotGranted
        }

        isRewardedLoading = true
        // Released on every exit, including the rethrow below. Clearing it only after the
        // do/catch left the flag stuck true after a single failed load, so the guard above
        // then declined every later rewarded load in the process.
        defer { isRewardedLoading = false }
        AdMetricsTracker.shared.trackRequest(adUnit: adUnitID.adUnitIDString, adType: .reward)
        // Show loading view when starting to load ad
        if showLoading {
            showRewardedAdLoadingView()
        }
        initializeSDK()

        do {
            rewardedAd = try await RewardedAd.load(
                with: adUnitID.adUnitIDString, request: Request())
            rewardedLoadTime = Date()
            rewardedAd?.fullScreenContentDelegate = self
            if let ad = rewardedAd {
                fullScreenAdUnitIDs[ObjectIdentifier(ad)] = adUnitID.adUnitIDString
            }
            AdMetricsTracker.shared.trackLoaded(adUnit: adUnitID.adUnitIDString)

            // Track ad revenue
            rewardedAd?.paidEventHandler = { adValue in
                AdRevenueManager.shared.logRevenue(adType: .reward, adValue: adValue)
            }

            debugPrint("Rewarded ad loaded successfully")
        } catch {
            debugPrint("Rewarded ad failed to load with error: \(error.localizedDescription)")
            AdMetricsTracker.shared.trackLoadFailed(adUnit: adUnitID.adUnitIDString)
            rewardedAd = nil
            // Hide loading view when load fails
            if showLoading {
                hideRewardedAdLoadingView()
            }
            throw error
        }
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
        cachedOnly: Bool = false,
        showLoading: Bool = true,
        completion: @escaping (AdReward) -> Void
    ) async throws {
        guard !isRewardedShowing else {
            throw AdMobHelperError.adAlreadyShowing
        }
        if cachedOnly && !isRewardedAdReady(adUnitID: adUnitID) { throw AdMobHelperError.adNotLoaded }
        guard GoogleMobileAdsConsentManager.shared.canRequestAds else { throw AdMobHelperError.consentNotGranted }

        if !isRewardedAdReady(adUnitID: adUnitID) {
            guard !cachedOnly else { throw AdMobHelperError.adNotLoaded }
            try await loadRewardedAd(adUnitID: adUnitID, showLoading: showLoading)
        }

        guard let rewardedAd = rewardedAd else {
            throw AdMobHelperError.adNotLoaded
        }

        // Never present while backgrounded — the ad would render half-presented
        // and its loading overlay would get stuck. Hide the overlay and keep the
        // loaded ad so it can present on the next attempt once foregrounded.
        guard canPresentFullScreenAd,
              viewController.viewIfLoaded?.window?.windowScene?.activationState == .foregroundActive,
              viewController.presentedViewController == nil else {
            hideRewardedAdLoadingView()
            rewardedAdStatusCallback = nil
            throw AdMobHelperError.appInBackground
        }

        // Loading view should already be showing from loadRewardedAd
        // If not showing, show it now (in case ad was pre-loaded)
        if showLoading && rewardedAdLoadingView == nil {
            showRewardedAdLoadingView()
        }

        // Skip next app resume ad since rewarded ad is showing
        shouldSkipNextAppResume = true

        rewardedAdStatusCallback = statusCallback
        isRewardedShowing = true
        didEarnRewardForCurrentAd = false  // Reset flag before showing
        rewardedAd.present(from: viewController) { [weak self] in
            let reward = rewardedAd.adReward
            debugPrint("Reward received with currency \(reward.type), amount \(reward.amount.doubleValue)")
            // Mark that reward was earned
            if self?.rewardedAd === rewardedAd { self?.didEarnRewardForCurrentAd = true }
            // Notify that reward was earned
            statusCallback?(.didEarnReward)
            completion(reward)
        }
    }
}


