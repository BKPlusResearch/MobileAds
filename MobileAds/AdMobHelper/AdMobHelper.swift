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
    public internal(set) var interstitialAd: InterstitialAd?
    
    /// The rewarded video ad.
    public internal(set) var rewardedAd: RewardedAd?
    
    /// The rewarded interstitial ad.
    public internal(set) var rewardedInterstitialAd: RewardedInterstitialAd?
    
    /// The app open ad.
    public internal(set) var appOpenAd: AppOpenAd?
    
    /// Loading view for app open ads.
    var appOpenAdLoadingView: AppOpenAdLoadingView?
    
    /// Callback for app open ad status events
    var appOpenAdStatusCallback: ((AppOpenAdStatus) -> Void)?
    
    /// Loading view for interstitial ads.
    var interstitialAdLoadingView: AppOpenAdLoadingView?
    
    /// Callback for interstitial ad status events
    var interstitialAdStatusCallback: ((InterstitialAdStatus) -> Void)?
    
    /// Loading view for rewarded ads.
    var rewardedAdLoadingView: AppOpenAdLoadingView?
    
    /// Callback for rewarded ad status events
    var rewardedAdStatusCallback: ((RewardedAdStatus) -> Void)?
    
    /// Tracks if user earned reward (to combine with dismiss event)
    var didEarnRewardForCurrentAd = false
    
    /// Keeps track of if an interstitial ad is loading.
    public internal(set) var isInterstitialLoading = false
    
    /// Keeps track of if an interstitial ad is showing.
    public internal(set) var isInterstitialShowing = false
    
    /// Keeps track of if a rewarded ad is loading.
    public internal(set) var isRewardedLoading = false
    
    /// Keeps track of if a rewarded ad is showing.
    public internal(set) var isRewardedShowing = false
    
    /// Keeps track of if a rewarded interstitial ad is loading.
    public internal(set) var isRewardedInterstitialLoading = false
    
    /// Keeps track of if a rewarded interstitial ad is showing.
    public internal(set) var isRewardedInterstitialShowing = false
    
    /// Keeps track of if an app open ad is loading.
    public internal(set) var isAppOpenLoading = false
    
    /// Keeps track of if an app open ad is showing.
    public internal(set) var isAppOpenShowing = false
    
    /// The banner ad view.
    public internal(set) var bannerAd: BannerView?
    
    /// Keeps track of if a banner ad is loading.
    public internal(set) var isBannerLoading = false
    
    /// Callback for banner ad status events
    var bannerAdStatusCallback: ((BannerAdStatus) -> Void)?
    
    /// Keeps track of the time when an app open ad was loaded to discard expired ad.
    var appOpenLoadTime: Date?

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

    // MARK: - Cleanup

    /// Clear all loaded ads.
    public func clearAllAds() {
        interstitialAd = nil
        rewardedAd = nil
        rewardedInterstitialAd = nil
        appOpenAd = nil
        appOpenLoadTime = nil
        bannerAd = nil

        isInterstitialLoading = false
        isInterstitialShowing = false
        isRewardedLoading = false
        isRewardedShowing = false
        isRewardedInterstitialLoading = false
        isRewardedInterstitialShowing = false
        isAppOpenLoading = false
        isAppOpenShowing = false
        isBannerLoading = false
        
        // Clear callbacks
        bannerAdStatusCallback = nil
        
        // Hide loading views if showing
        hideAppOpenAdLoadingView()
        hideInterstitialAdLoadingView()
        hideRewardedAdLoadingView()
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

// MARK: - Banner Ad Status

/// Status events for banner ad lifecycle
public enum BannerAdStatus {
    case didLoad              // Banner ad loaded successfully
    case didFailToLoad        // Banner ad failed to load
    case didRecordImpression  // Banner ad recorded an impression
    case didRecordClick       // Banner ad was clicked
    case willPresentScreen    // Banner ad will present full screen content
    case willDismissScreen    // Banner ad will dismiss full screen content
    case didDismissScreen     // Banner ad dismissed full screen content
}

// MARK: - AdMobHelperError

/// Errors that can occur when using AdMobHelper.
public enum AdMobHelperError: Error {
    case consentNotGranted
    case adNotLoaded
    case adAlreadyShowing
}

