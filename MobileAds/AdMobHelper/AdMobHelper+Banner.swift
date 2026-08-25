@preconcurrency import GoogleMobileAds
import UIKit
import SnapKit
//
//extension AdMobHelper: BannerViewDelegate {
//    // MARK: - Banner Ad    
//    
//    /// Load banner ad and automatically add it to a container view with constraints.
//    /// This is a convenience method that eliminates the need to store a banner view reference in your controller.
//    /// - Parameters:
//    ///   - containerView: The container view where the banner ad will be added.
//    ///   - adUnitID: The Ad Unit ID enum for banner ads.
//    ///   - rootViewController: The view controller that will present the ad.
//    ///   - isCollapsible: Whether to use collapsible banner ad (default: false).
//    ///   - collapsiblePlacement: The placement of the collapsible button (default: .bottom).
//    ///   - enableCache: Enable caching to reuse banner if user returns before impression fires (default: true).
//    ///   - statusCallback: Optional callback to receive ad status events (didLoad, didFailToLoad, didRecordImpression, etc.).
//    public func loadBannerAd(
//        into containerView: UIView,
//        adUnitID: AdUnitIdentifiable,
//        rootViewController: UIViewController,
//        isCollapsible: Bool = false,
//        collapsiblePlacement: BannerCollapsiblePlacement = .bottom,
//        enableCache: Bool = true,
//        statusCallback: ((BannerAdStatus) -> Void)? = nil
//    ) {
//        // Auto-generate cache key from ad unit ID if cache is enabled
//        let cacheKey = enableCache ? adUnitID.adUnitIDString : nil
//
//        // Try to use cached banner first if cache is enabled
//        if let cacheKey = cacheKey,
//           let cachedBanner = getCachedBannerAd(for: cacheKey) {
//            debugPrint("✅ [BANNER_CACHE] Using cached banner for ad unit: '\(cacheKey)'")
//            displayCachedBanner(
//                cachedBanner,
//                in: containerView,
//                cacheKey: cacheKey,
//                statusCallback: statusCallback
//            )
//            return
//        }
//
//        // No cached banner available, load from network
//        if let cacheKey = cacheKey {
//            debugPrint("⏳ [BANNER_CACHE] No cached banner for ad unit: '\(cacheKey)', loading from network...")
//        }
//
//        // Cleanup existing banner ad (remove from container, hide loading, reset state)
//        cleanupBannerAd()
//
//        // Remove any existing banner view from container (in case cleanup didn't catch it)
//        containerView.subviews.forEach { subview in
//            if subview is BannerView {
//                subview.removeFromSuperview()
//            }
//        }
//
//        // Create and load banner view using existing method
//        let bannerView = loadBannerAd(
//            adUnitID: adUnitID,
//            rootViewController: rootViewController,
//            isCollapsible: isCollapsible,
//            collapsiblePlacement: collapsiblePlacement,
//            statusCallback: statusCallback
//        )
//        
//        // Add banner view to container
//        containerView.addSubview(bannerView)
//        bannerView.snp.makeConstraints { make in
//            make.edges.equalToSuperview()
//        }
//    }
//    
//    /// Load and return a banner ad view.
//    /// - Parameters:
//    ///   - adUnitID: The Ad Unit ID enum for banner ads.
//    ///   - rootViewController: The view controller that will present the ad.
//    ///   - isCollapsible: Whether to use collapsible banner ad (default: false).
//    ///   - collapsiblePlacement: The placement of the collapsible button (default: .bottom).
//    ///   - enableCache: Enable caching to reuse banner if user returns before impression fires (default: true).
//    ///   - statusCallback: Optional callback to receive ad status events (didLoad, didFailToLoad, didRecordImpression, etc.).
//    /// - Returns: A configured BannerView ready to load ads.
//    public func loadBannerAd(
//        adUnitID: AdUnitIdentifiable,
//        rootViewController: UIViewController,
//        isCollapsible: Bool = false,
//        collapsiblePlacement: BannerCollapsiblePlacement = .bottom,
//        enableCache: Bool = true,
//        statusCallback: ((BannerAdStatus) -> Void)? = nil
//    ) -> BannerView {
//        // Auto-generate cache key from ad unit ID if cache is enabled
//        let cacheKey = enableCache ? adUnitID.adUnitIDString : nil
//        let bannerView = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: 375))
//        bannerView.adUnitID = adUnitID.adUnitIDString
//        bannerView.rootViewController = rootViewController
//        
//        // Store banner view and callbacks
//        self.bannerAd = bannerView
//        self.bannerAdStatusCallback = statusCallback
//
//        // Store cache key association if provided
//        if let cacheKey = cacheKey {
//            associateCacheKey(cacheKey, with: bannerView)
//        }
//
//        // Set self as delegate to track events
//        bannerView.delegate = self
//
//        // Track ad revenue
//        bannerView.paidEventHandler = { adValue in
//            AdRevenueManager.shared.logRevenue(adType: .banner, adValue: adValue)
//        }
//
//        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
//            debugPrint("Cannot load banner ad: Consent not granted")
//            isBannerLoading = false
//            statusCallback?(.didFailToLoad)
//            return bannerView
//        }
//
//        isBannerLoading = true
//        // Show loading view
//        showBannerAdLoadingView(on: bannerView)
//        initializeSDK()
//
//        // Create request with collapsible option if needed
//        let request = Request()
//        if isCollapsible {
//            let extras = Extras()
//            extras.additionalParameters = ["collapsible": collapsiblePlacement.rawValue]
//            request.register(extras)
//        }
//
//        bannerView.load(request)
//        return bannerView
//    }
//
//    // MARK: - Display Cached Banner
//
//    /// Display a cached banner in container view
//    /// - Parameters:
//    ///   - bannerView: The cached banner view to display
//    ///   - containerView: The container view to add the banner to
//    ///   - cacheKey: The cache key for tracking
//    ///   - statusCallback: Optional callback for status events
//    private func displayCachedBanner(
//        _ bannerView: BannerView,
//        in containerView: UIView,
//        cacheKey: String,
//        statusCallback: ((BannerAdStatus) -> Void)?
//    ) {
//        // Cleanup existing banner first
//        cleanupBannerAd()
//
//        // Clear existing subviews from container
//        containerView.subviews.forEach { $0.removeFromSuperview() }
//
//        // Store as current banner
//        self.bannerAd = bannerView
//        self.bannerAdStatusCallback = statusCallback
//
//        // Maintain cache key association for impression tracking
//        associateCacheKey(cacheKey, with: bannerView)
//
//        // Set delegate to track future events
//        bannerView.delegate = self
//
//        // Add to container
//        containerView.addSubview(bannerView)
//        bannerView.snp.makeConstraints { make in
//            make.edges.equalToSuperview()
//        }
//
//        // Force layout update
//        containerView.setNeedsLayout()
//        containerView.layoutIfNeeded()
//
//        debugPrint("✅ [BANNER_CACHE] Displayed cached banner for key: '\(cacheKey)'")
//
//        // Notify success (banner is already loaded)
//        statusCallback?(.didLoad)
//
//        // NOTE: Cache will be cleared when impression fires (bannerViewDidRecordImpression)
//    }
//
//    // MARK: - BannerViewDelegate
//    
//    public func bannerViewDidReceiveAd(_ bannerView: BannerView) {
//        debugPrint("Banner ad loaded successfully")
//        isBannerLoading = false
//        // Hide loading view when ad loads successfully
//        hideBannerAdLoadingView()
//
//        // Cache banner if cache key associated
//        if let cacheKey = getCacheKey(for: bannerView) {
//            cacheBannerAd(bannerView, for: cacheKey, adUnitID: bannerView.adUnitID ?? "")
//            debugPrint("📦 [BANNER_CACHE] Cached for '\(cacheKey)' - waiting for impression")
//        }
//
//        bannerAdStatusCallback?(.didLoad)
//    }
//    
//    public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
//        debugPrint("Banner ad failed to load with error: \(error.localizedDescription)")
//        isBannerLoading = false
//        // Hide loading view when ad fails to load
//        hideBannerAdLoadingView()
//        bannerAdStatusCallback?(.didFailToLoad)
//    }
//    
//    public func bannerViewDidRecordImpression(_ bannerView: BannerView) {
//        debugPrint("Banner ad recorded an impression")
//
//        // Clear cache AFTER impression fires (critical for show rate optimization)
//        if let cacheKey = getCacheKey(for: bannerView) {
//            clearCachedBannerAd(for: cacheKey)
//            debugPrint("🗑️ [BANNER_CACHE] Cache cleared after impression for '\(cacheKey)'")
//        }
//
//        bannerAdStatusCallback?(.didRecordImpression)
//    }
//    
//    public func bannerViewDidRecordClick(_ bannerView: BannerView) {
//        debugPrint("Banner ad recorded a click")
//        
//        // Mark ad click (will verify in background handler if app actually leaves)
//        markAdClick()
//        
//        bannerAdStatusCallback?(.didRecordClick)
//    }
//    
//    public func bannerViewWillPresentScreen(_ bannerView: BannerView) {
//        debugPrint("Banner ad will present screen")
//        bannerAdStatusCallback?(.willPresentScreen)
//    }
//    
//    public func bannerViewWillDismissScreen(_ bannerView: BannerView) {
//        debugPrint("Banner ad will dismiss screen")
//        bannerAdStatusCallback?(.willDismissScreen)
//    }
//    
//    public func bannerViewDidDismissScreen(_ bannerView: BannerView) {
//        debugPrint("Banner ad dismissed screen")
//        
//        // If dismissed in-app screen without going to background, clear the pending flag
//        clearPendingAdClick()
//        
//        bannerAdStatusCallback?(.didDismissScreen)
//    }
//    
//    // MARK: - Banner Ad Cleanup
//    
//    /// Cleanup existing banner ad (remove from container, hide loading view, reset state)
//    private func cleanupBannerAd() {
//        // Hide loading view if showing
//        hideBannerAdLoadingView()
//        
//        // Remove banner from its superview if it exists
//        bannerAd?.removeFromSuperview()
//        
//        // Reset loading state
//        isBannerLoading = false
//        
//        // Clear callback (will be set again when loading new banner)
//        bannerAdStatusCallback = nil
//        
//        // Note: We don't set bannerAd = nil here because the new loadBannerAd call will replace it
//    }
//    
//    // MARK: - Banner Ad Loading View
//    
//    /// Show loading view for banner ad
//    private func showBannerAdLoadingView(on bannerView: BannerView) {
//        // Remove existing loading view if any
//        hideBannerAdLoadingView()
//        
//        // Create and add loading view
//        let loadingView = BannerAdLoadingView()
//        bannerView.addSubview(loadingView)
//        loadingView.snp.makeConstraints { make in
//            make.edges.equalToSuperview()
//        }
//        
//        // Store reference
//        bannerAdLoadingView = loadingView
//    }
//    
//    /// Hide loading view for banner ad
//    func hideBannerAdLoadingView() {
//        bannerAdLoadingView?.stopAnimation()
//        bannerAdLoadingView?.removeFromSuperview()
//        bannerAdLoadingView = nil
//    }
//}
//
//
