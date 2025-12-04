//
//  Copyright 2024 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

@preconcurrency import GoogleMobileAds
import UIKit

/// Main helper class for managing Google Mobile Ads SDK across all ad types.
@MainActor
public class AdMobHelper: NSObject {
    public static let shared = AdMobHelper()

    // MARK: - Properties

    /// The interstitial ad.
    public private(set) var interstitialAd: InterstitialAd?

    /// The rewarded video ad.
    public private(set) var rewardedAd: RewardedAd?

    /// The rewarded interstitial ad.
    public private(set) var rewardedInterstitialAd: RewardedInterstitialAd?

    /// The app open ad.
    public private(set) var appOpenAd: AppOpenAd?

    /// Loading view for app open ads.
    private var appOpenAdLoadingView: AppOpenAdLoadingView?
    
    /// Callback for app open ad status events
    private var appOpenAdStatusCallback: ((AppOpenAdStatus) -> Void)?
    
    /// Loading view for interstitial ads.
    private var interstitialAdLoadingView: AppOpenAdLoadingView?
    
    /// Callback for interstitial ad status events
    private var interstitialAdStatusCallback: ((InterstitialAdStatus) -> Void)?
    
    /// Loading view for rewarded ads.
    private var rewardedAdLoadingView: AppOpenAdLoadingView?
    
    /// Callback for rewarded ad status events
    private var rewardedAdStatusCallback: ((RewardedAdStatus) -> Void)?
    
    /// Tracks if user earned reward (to combine with dismiss event)
    private var didEarnRewardForCurrentAd = false

    /// Keeps track of if an interstitial ad is loading.
    public private(set) var isInterstitialLoading = false

    /// Keeps track of if an interstitial ad is showing.
    public private(set) var isInterstitialShowing = false

    /// Keeps track of if a rewarded ad is loading.
    public private(set) var isRewardedLoading = false

    /// Keeps track of if a rewarded ad is showing.
    public private(set) var isRewardedShowing = false

    /// Keeps track of if a rewarded interstitial ad is loading.
    public private(set) var isRewardedInterstitialLoading = false

    /// Keeps track of if a rewarded interstitial ad is showing.
    public private(set) var isRewardedInterstitialShowing = false

    /// Keeps track of if an app open ad is loading.
    public private(set) var isAppOpenLoading = false

    /// Keeps track of if an app open ad is showing.
    public private(set) var isAppOpenShowing = false

    /// Keeps track of the time when an app open ad was loaded to discard expired ad.
    private var appOpenLoadTime: Date?

    /// Timeout interval for app open ad expiration (4 hours).
    public let appOpenTimeoutInterval: TimeInterval = 4 * 3_600

    /// Indicates whether the Google Mobile Ads SDK has been initialized.
    public private(set) var isSDKInitialized = false

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - SDK Initialization

    /// Configure ads by gathering consent and initializing SDK.
    /// This is the recommended entry point when importing the framework.
    /// Call this method in your AppDelegate or SceneDelegate's didFinishLaunching.
    /// - Parameter viewController: Optional view controller to present consent form from. If nil, will use key window's root view controller.
    public func configAds(from viewController: UIViewController? = nil) {
        GoogleMobileAdsConsentManager.shared.gatherConsent(from: viewController) { [weak self] error in
            if let error {
                print("Consent gathering error: \(error.localizedDescription)")
            }
            
            if GoogleMobileAdsConsentManager.shared.canRequestAds {
                self?.initializeSDK()
            }
        }
    }

    /// Initialize the Google Mobile Ads SDK.
    public func initializeSDK() {
        guard !isSDKInitialized else {
            return
        }

        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            print("Cannot initialize SDK: Consent not granted")
            return
        }

        MobileAds.shared.start()
        isSDKInitialized = true
        print("Google Mobile Ads SDK initialized")

#if DEBUG
        print("⚠️ DEBUG MODE: Using TEST Ad Unit IDs")
        print("   Make sure to use PRODUCTION IDs in RELEASE builds!")
#else
        print("✅ RELEASE MODE: Using PRODUCTION Ad Unit IDs")
#endif
    }

    // MARK: - Banner Ad

    /// Load and return a banner ad view.
    /// - Parameters:
    ///   - adUnitID: The Ad Unit ID enum for banner ads.
    ///   - rootViewController: The view controller that will present the ad.
    ///   - delegate: Optional banner view delegate.
    /// - Returns: A configured BannerView ready to load ads.
    public func loadBannerAd(
        adUnitID: AdUnitID,
        rootViewController: UIViewController,
        delegate: BannerViewDelegate? = nil
    ) -> BannerView {
        let bannerView = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: 375))
        bannerView.adUnitID = adUnitID.rawValue
        bannerView.rootViewController = rootViewController
        bannerView.delegate = delegate

        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            print("Cannot load banner ad: Consent not granted")
            return bannerView
        }

        initializeSDK()
        bannerView.load(Request())
        return bannerView
    }

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

    // MARK: - Rewarded Video Ad

    /// Load a rewarded video ad.
    /// - Parameter adUnitID: The Ad Unit ID enum for rewarded video ads.
    public func loadRewardedAd(adUnitID: AdUnitID) async throws {
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
                with: adUnitID.rawValue, request: Request())
            rewardedAd?.fullScreenContentDelegate = self
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
    ///   - adUnitID: The Ad Unit ID enum for rewarded video ads (used to load if not already loaded).
    ///   - statusCallback: Optional callback to receive ad status events (didPresent, didFailToPresent, didDismiss, didEarnReward).
    ///   - completion: Callback with the reward when the user earns it.
    public func showRewardedAd(
        from viewController: UIViewController,
        adUnitID: AdUnitID,
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

    // MARK: - Rewarded Interstitial Ad

    /// Load a rewarded interstitial ad.
    /// - Parameter adUnitID: The Ad Unit ID enum for rewarded interstitial ads.
    public func loadRewardedInterstitialAd(adUnitID: AdUnitID) async throws {
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
                with: adUnitID.rawValue, request: Request())
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
    ///   - adUnitID: The Ad Unit ID enum for rewarded interstitial ads (used to load if not already loaded).
    ///   - completion: Callback with the reward when the user earns it.
    public func showRewardedInterstitialAd(
        from viewController: UIViewController,
        adUnitID: AdUnitID,
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
    /// - Parameter adUnitID: The Ad Unit ID enum for app open ads.
    public func loadAppOpenAd(adUnitID: AdUnitID) async throws {
        // Do not load ad if there is an unused ad or one is already loading.
        if isAppOpenLoading || isAppOpenAdAvailable() {
            return
        }

        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            throw AdMobHelperError.consentNotGranted
        }

        isAppOpenLoading = true
        // Show loading view when starting to load ad
        showAppOpenAdLoadingView()
        initializeSDK()

        do {
            appOpenAd = try await AppOpenAd.load(
                with: adUnitID.rawValue, request: Request())
            appOpenAd?.fullScreenContentDelegate = self
            appOpenLoadTime = Date()
            print("App open ad loaded successfully")
            // Hide loading view when load completes successfully
            // Keep it showing if we're about to show the ad immediately
        } catch {
            print("App open ad failed to load with error: \(error.localizedDescription)")
            appOpenAd = nil
            appOpenLoadTime = nil
            // Hide loading view when load fails
            hideAppOpenAdLoadingView()
            throw error
        }

        isAppOpenLoading = false
    }

    /// Show an app open ad if available.
    /// - Parameters:
    ///   - viewController: The view controller to present the ad from (can be nil for app open).
    ///   - statusCallback: Optional callback to receive ad status events (didPresent, didFailToPresent, didDismiss).
    /// - Returns: True if ad was shown, false otherwise.

    public func showAppOpenAd(
        from viewController: UIViewController? = nil,
        statusCallback: ((AppOpenAdStatus) -> Void)? = nil
    ) {
        // If the app open ad is already showing, do not show the ad again.
        if isAppOpenShowing {
            debugPrint("App open ad is already showing.")
            return
        }

        // If the app open ad is not available yet, return false.
        if !isAppOpenAdAvailable() {
            debugPrint("App open ad is not ready yet.")
            return
        }

        if let appOpenAd = appOpenAd {
            // Store callback for status events
            appOpenAdStatusCallback = statusCallback
            
            // Loading view should already be showing from loadAppOpenAd
            // If not showing, show it now (in case ad was pre-loaded)
            if appOpenAdLoadingView == nil {
                showAppOpenAdLoadingView()
            }
            
            appOpenAd.present(from: viewController)
            isAppOpenShowing = true
            return
        }
    }

    // MARK: - App Open Ad Loading View
    
    /// Show loading view for app open ad
    private func showAppOpenAdLoadingView() {
        // Remove existing loading view if any
        hideAppOpenAdLoadingView()
        
        // Create and show new loading view
        appOpenAdLoadingView = AppOpenAdLoadingView()
        appOpenAdLoadingView?.show()
    }
    
    /// Hide loading view for app open ad
    private func hideAppOpenAdLoadingView() {
        appOpenAdLoadingView?.hide()
        appOpenAdLoadingView = nil
    }
    
    // MARK: - Interstitial Ad Loading View
    
    /// Show loading view for interstitial ad
    private func showInterstitialAdLoadingView() {
        // Remove existing loading view if any
        hideInterstitialAdLoadingView()
        
        // Create and show new loading view
        interstitialAdLoadingView = AppOpenAdLoadingView()
        interstitialAdLoadingView?.show()
    }
    
    /// Hide loading view for interstitial ad
    private func hideInterstitialAdLoadingView() {
        interstitialAdLoadingView?.hide()
        interstitialAdLoadingView = nil
    }
    
    // MARK: - Rewarded Ad Loading View
    
    /// Show loading view for rewarded ad
    private func showRewardedAdLoadingView() {
        // Remove existing loading view if any
        hideRewardedAdLoadingView()
        
        // Create and show new loading view
        rewardedAdLoadingView = AppOpenAdLoadingView()
        rewardedAdLoadingView?.show()
    }
    
    /// Hide loading view for rewarded ad
    private func hideRewardedAdLoadingView() {
        rewardedAdLoadingView?.hide()
        rewardedAdLoadingView = nil
    }

    // MARK: - Cleanup

    /// Clear all loaded ads.
    public func clearAllAds() {
        interstitialAd = nil
        rewardedAd = nil
        rewardedInterstitialAd = nil
        appOpenAd = nil
        appOpenLoadTime = nil

        isInterstitialLoading = false
        isInterstitialShowing = false
        isRewardedLoading = false
        isRewardedShowing = false
        isRewardedInterstitialLoading = false
        isRewardedInterstitialShowing = false
        isAppOpenLoading = false
        isAppOpenShowing = false
        
        // Hide loading views if showing
        hideAppOpenAdLoadingView()
        hideInterstitialAdLoadingView()
        hideRewardedAdLoadingView()
    }
}

// MARK: - FullScreenContentDelegate

extension AdMobHelper: FullScreenContentDelegate {
    public func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("Ad recorded an impression.")
    }

    public func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        print("Ad recorded a click.")
    }

    public func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Ad will be presented.")
        
        // Hide loading view when ad is about to be presented (success case)
        if ad === appOpenAd {
            hideAppOpenAdLoadingView()
            // Notify that ad was presented successfully
            appOpenAdStatusCallback?(.didPresent)
        } else if ad === interstitialAd {
            hideInterstitialAdLoadingView()
            // Notify that ad was presented successfully
            interstitialAdStatusCallback?(.didPresent)
        } else if ad === rewardedAd {
            hideRewardedAdLoadingView()
            // Notify that ad was presented successfully
            rewardedAdStatusCallback?(.didPresent)
        }
    }

    public func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Ad will be dismissed.")
        
        // Notify that ad will be dismissed
        if ad === appOpenAd {
            appOpenAdStatusCallback?(.willDismiss)
        } else if ad === interstitialAd {
            interstitialAdStatusCallback?(.willDismiss)
        } else if ad === rewardedAd {
            rewardedAdStatusCallback?(.willDismiss)
        }
    }

    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Ad was dismissed.")

        // Clear the ad and reset showing state
        if ad === interstitialAd {
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
            rewardedInterstitialAd = nil
            isRewardedInterstitialShowing = false
        } else if ad === appOpenAd {
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
        print("Ad failed to present with error: \(error.localizedDescription)")

        // Clear the ad and reset showing state
        if ad === interstitialAd {
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
            rewardedInterstitialAd = nil
            isRewardedInterstitialShowing = false
        } else if ad === appOpenAd {
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

// MARK: - App Open Ad Status

/// Status events for app open ad lifecycle
public enum AppOpenAdStatus {
    case didPresent        // Ad was presented successfully
    case didFailToPresent  // Ad failed to present
    case willDismiss       // Ad will be dismissed
    case didDismiss        // Ad was dismissed by user
}

public enum InterstitialAdStatus {
    case didPresent        // Ad was presented successfully
    case didFailToPresent  // Ad failed to present
    case willDismiss       // Ad will be dismissed
    case didDismiss        // Ad was dismissed by user
}

public enum RewardedAdStatus {
    case didPresent              // Ad was presented successfully
    case didFailToPresent        // Ad failed to present
    case willDismiss             // Ad will be dismissed
    case didDismiss              // Ad was dismissed by user (without earning reward)
    case didEarnReward           // User earned the reward
    case didEarnRewardAndDismiss // User earned reward AND ad was dismissed
}

// MARK: - AdMobHelperError

/// Errors that can occur when using AdMobHelper.
public enum AdMobHelperError: Error {
    case consentNotGranted
    case adNotLoaded
    case adAlreadyShowing
}

