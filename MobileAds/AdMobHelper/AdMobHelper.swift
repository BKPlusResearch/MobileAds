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
import AppTrackingTransparency

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
    
    /// Flag to skip next App Resume Ad (e.g., when user returns from ad-opened browser)
    public var shouldSkipNextAppResume = false
    
    /// Track if user recently clicked an ad (to verify if background is from ad click)
    private var hadRecentAdClick = false
    
    /// Timestamp of last ad click
    private var lastAdClickTime: Date?
    
    /// The banner ad view.
    public internal(set) var bannerAd: BannerView?
    
    /// Keeps track of if a banner ad is loading.
    public internal(set) var isBannerLoading = false
    
    /// Callback for banner ad status events
    var bannerAdStatusCallback: ((BannerAdStatus) -> Void)?
    
    /// Loading view for banner ads.
    var bannerAdLoadingView: BannerAdLoadingView?

    /// Callback for native ad status events
    public var nativeAdStatusCallback: ((NativeAdStatus) -> Void)?

    /// Keeps track of the time when an app open ad was loaded to discard expired ad.
    var appOpenLoadTime: Date?

    /// Timeout interval for app open ad expiration (4 hours).
    public let appOpenTimeoutInterval: TimeInterval = 4 * 3_600

    /// Indicates whether the Google Mobile Ads SDK has been initialized.
    public private(set) var isSDKInitialized = false

    /// Maps full-screen ad objects to their ad unit ID strings for metrics tracking.
    /// FullScreenPresentingAd protocol doesn't expose adUnitID, so we store it at load time.
    var fullScreenAdUnitIDs: [ObjectIdentifier: String] = [:]

    var isEnableShowAds: Bool = true
    
    public func setEnableShowAds(_ isEnableShowAds: Bool) {
        self.isEnableShowAds = isEnableShowAds
    }
    
    public func checkEnableShowAds() -> Bool {
        return isEnableShowAds
    }

    // MARK: - Presentation Safety

    /// Whether it is safe to present a full-screen ad right now.
    ///
    /// Presenting while the app is in the background (e.g. an on-demand ad
    /// finishes loading after the user has left the app) leaves the ad
    /// half-presented: its `adWillPresentFullScreenContent` never fires, so the
    /// "Loading ads…" overlay is never removed and the `is*Showing` flag stays
    /// stuck — the user comes back to an ad they cannot dismiss. Only `.active`
    /// and `.inactive` (the brief foreground transition used by resume App-Open)
    /// are safe to present in.
    var canPresentFullScreenAd: Bool {
        UIApplication.shared.applicationState != .background
    }

    // MARK: - App Resume Control
    
    /// Check if there was a recent ad click within specified time window
    public func isRecentAdClick(withinSeconds seconds: TimeInterval) -> Bool {
        guard hadRecentAdClick, let clickTime = lastAdClickTime else {
            return false
        }
        
        let timeSinceClick = Date().timeIntervalSince(clickTime)
        return timeSinceClick <= seconds
    }
    
    /// Confirm that app went to background after ad click, set skip flag
    public func confirmSkipNextAppResume() {
        shouldSkipNextAppResume = true
        hadRecentAdClick = false  // Reset pending flag
        lastAdClickTime = nil
    }
    
    /// Mark that an ad was clicked (pending verification in background handler)
    public func markAdClick() {
        hadRecentAdClick = true
        lastAdClickTime = Date()
    }
    
    /// Clear pending ad click flag (for in-app overlays that don't leave app)
    public func clearPendingAdClick() {
        hadRecentAdClick = false
        lastAdClickTime = nil
    }
    
    /// Reset the skip flag (typically after checking it)
    public func resetAppResumeSkipFlag() {
        shouldSkipNextAppResume = false
        hadRecentAdClick = false
        lastAdClickTime = nil
    }
    
    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - SDK Initialization

    /// Longest the tracking-authorization step will block `configAds`.
    ///
    /// Only reached while the ATT alert is genuinely on screen unanswered, which
    /// is user-paced — the wait normally ends within a few hundred milliseconds
    /// of the user tapping. The cap exists so a launch cannot stall forever if
    /// the alert never presents.
    private static let trackingAuthorizationTimeout: TimeInterval = 30

    /// Poll step while waiting for the app to become active or for ATT to resolve.
    private static let trackingAuthorizationPollNanoseconds: UInt64 = 200_000_000

    /// Configure ads by gathering consent and initializing SDK.
    /// This is the recommended entry point when importing the framework.
    /// Call this method in your AppDelegate or SceneDelegate's didFinishLaunching.
    /// - Parameter viewController: Optional view controller to present consent form from. If nil, will use key window's root view controller.
    public func configAds(from viewController: UIViewController? = nil, completion: (() -> Void)? = nil) {
        GoogleMobileAdsConsentManager.shared.gatherConsent(from: viewController) { [weak self] error in
            if let error {
                debugPrint("Consent gathering error: \(error.localizedDescription)")
            }

            // UMP first, then ATT — this is the order Google documents, because
            // the UMP IDFA explainer message can only load while the tracking
            // status is still `.notDetermined`. Requesting ATT first would
            // permanently prevent that message from ever being shown.
            Task { @MainActor in
                guard let self else {
                    completion?()
                    return
                }
                await self.resolveTrackingAuthorization()
                self.finishConfigAds(completion)
            }
        }
    }

    /// Blocks until App Tracking Transparency has actually reached a decided
    /// state, rather than until its callback happens to fire.
    ///
    /// `requestTrackingAuthorization` returns immediately — reporting
    /// `.notDetermined` and presenting nothing — in two situations that both
    /// occur in normal use:
    ///
    /// 1. The app is not `.active`. During launch, or while another system
    ///    alert owns the screen, iOS silently declines to present the prompt.
    /// 2. A prompt queued by an earlier session has not been answered yet. iOS
    ///    re-presents that one asynchronously, and the callback does not wait
    ///    for it.
    ///
    /// Treating the callback as "ATT resolved" therefore lets the SDK
    /// initialize, and ad requests start, while the alert is still on screen.
    private func resolveTrackingAuthorization() async {
        // Already answered. This is also the path taken when the UMP IDFA
        // explainer presented the alert itself during `gatherConsent`, in which
        // case there is nothing left to ask.
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }

        let deadline = Date().addingTimeInterval(Self.trackingAuthorizationTimeout)

        // The prompt only presents while the app is active.
        await waitWhile(before: deadline) {
            UIApplication.shared.applicationState != .active
        }

        await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { _ in
                continuation.resume()
            }
        }

        // The callback can land before the user has answered, so the status is
        // the authority, not the callback. This exits as soon as they tap.
        await waitWhile(before: deadline) {
            ATTrackingManager.trackingAuthorizationStatus == .notDetermined
        }
    }

    /// Yields in small steps while `condition` holds and the deadline is unmet.
    /// Suspends rather than blocks, so the main actor stays responsive.
    private func waitWhile(before deadline: Date, _ condition: () -> Bool) async {
        while condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: Self.trackingAuthorizationPollNanoseconds)
        }
    }

    /// Initializes the SDK when consent allows, then invokes the caller's
    /// completion. Split out so the ATT request can gate SDK init.
    private func finishConfigAds(_ completion: (() -> Void)?) {
        if GoogleMobileAdsConsentManager.shared.canRequestAds {
            initializeSDK()
        }
        completion?()
    }

    /// Initialize the Google Mobile Ads SDK.
    public func initializeSDK() {
        guard !isSDKInitialized else {
            return
        }

        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            debugPrint("Cannot initialize SDK: Consent not granted")
            return
        }

        MobileAds.shared.start()
        isSDKInitialized = true
        debugPrint("Google Mobile Ads SDK initialized")

#if DEBUG
        debugPrint("⚠️ DEBUG MODE: Using TEST Ad Unit IDs")
        debugPrint("   Make sure to use PRODUCTION IDs in RELEASE builds!")
#else
        debugPrint("✅ RELEASE MODE: Using PRODUCTION Ad Unit IDs")
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

        // Reset App Resume skip flags
        shouldSkipNextAppResume = false
        hadRecentAdClick = false
        lastAdClickTime = nil

        // Clear callbacks
        bannerAdStatusCallback = nil

        // Hide loading views if showing
        hideAppOpenAdLoadingView()
        hideInterstitialAdLoadingView()
        hideRewardedAdLoadingView()

        // Clear banner cache
        clearAllCachedBannerAds()
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

// MARK: - Native Ad Status

/// Status events for native ad lifecycle
public enum NativeAdStatus {
    case didLoad              // Native ad loaded successfully
    case didFailToLoad        // Native ad failed to load
    case didRecordImpression  // Native ad recorded an impression
    case didRecordClick       // Native ad was clicked
    case willPresentScreen    // Native ad will present full screen content
    case willDismissScreen    // Native ad will dismiss full screen content
    case didDismissScreen     // Native ad dismissed full screen content
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

// MARK: - Banner Collapsible Placement

/// Placement options for collapsible banner ads
public enum BannerCollapsiblePlacement: String {
    case top = "top"
    case bottom = "bottom"
}

// MARK: - AdMobHelperError

/// Errors that can occur when using AdMobHelper.
public enum AdMobHelperError: Error {
    case consentNotGranted
    case adNotLoaded
    case adAlreadyShowing
    /// The app is backgrounded, so a full-screen ad must not be presented now.
    case appInBackground
}

