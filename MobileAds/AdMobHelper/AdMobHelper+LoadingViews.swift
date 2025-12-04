import UIKit

extension AdMobHelper {
    // MARK: - App Open Ad Loading View
    
    /// Show loading view for app open ad
    func showAppOpenAdLoadingView() {
        // Remove existing loading view if any
        hideAppOpenAdLoadingView()
        
        // Create and show new loading view
        appOpenAdLoadingView = AppOpenAdLoadingView()
        appOpenAdLoadingView?.show()
    }
    
    /// Hide loading view for app open ad
    func hideAppOpenAdLoadingView() {
        appOpenAdLoadingView?.hide()
        appOpenAdLoadingView = nil
    }
    
    // MARK: - Interstitial Ad Loading View
    
    /// Show loading view for interstitial ad
    func showInterstitialAdLoadingView() {
        // Remove existing loading view if any
        hideInterstitialAdLoadingView()
        
        // Create and show new loading view
        interstitialAdLoadingView = AppOpenAdLoadingView()
        interstitialAdLoadingView?.show()
    }
    
    /// Hide loading view for interstitial ad
    func hideInterstitialAdLoadingView() {
        interstitialAdLoadingView?.hide()
        interstitialAdLoadingView = nil
    }
    
    // MARK: - Rewarded Ad Loading View
    
    /// Show loading view for rewarded ad
    func showRewardedAdLoadingView() {
        // Remove existing loading view if any
        hideRewardedAdLoadingView()
        
        // Create and show new loading view
        rewardedAdLoadingView = AppOpenAdLoadingView()
        rewardedAdLoadingView?.show()
    }
    
    /// Hide loading view for rewarded ad
    func hideRewardedAdLoadingView() {
        rewardedAdLoadingView?.hide()
        rewardedAdLoadingView = nil
    }
}


