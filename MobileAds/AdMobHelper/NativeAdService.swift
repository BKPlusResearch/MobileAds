//
//  NativeAdService.swift
//  AppTheme
//
//  Created by Auto on 2024.
//

import UIKit
import SnapKit
@preconcurrency import GoogleMobileAds

/// Configuration for customizing native ad appearance
/// Singleton pattern to allow global configuration for all native ads in the app
@MainActor
public class NativeAdConfiguration {
    /// Shared singleton instance
    public static let shared = NativeAdConfiguration()
    
    /// Font for headline label
    public var headlineFont: UIFont?
    
    /// Font for body label
    public var bodyFont: UIFont?
    
    /// Font for call to action button
    public var callToActionFont: UIFont?
    
    /// Background color for call to action button
    /// Note: If useGradientForCallToAction is true, this will be ignored
    public var callToActionBackgroundColor: UIColor?
    
    /// Text color for headline label
    public var headlineTextColor: UIColor?
    
    /// Text color for body label
    public var bodyTextColor: UIColor?
    
    /// Text color for call to action button
    public var callToActionTextColor: UIColor?

    // MARK: - Border and Background Properties

    /// Border color for the ad container view
    public var borderColor: UIColor?

    /// Border width for the ad container view
    public var borderWidth: CGFloat?

    /// Background color for the ad container view
    public var backgroundColor: UIColor?

    /// Background color for the "Ad" label view
    public var adsLabelBackgroundColor: UIColor?

    // MARK: - Gradient Properties
    
    /// Flag to enable/disable gradient for call to action button
    public var useGradientForCallToAction: Bool = false
    
    /// Start color for call to action button gradient
    public var callToActionGradientStartColor: UIColor?
    
    /// End color for call to action button gradient
    public var callToActionGradientEndColor: UIColor?
    
    /// Start point for gradient (default: CGPoint(x: 0.0, y: 0.5) - left to right)
    public var callToActionGradientStartPoint: CGPoint = CGPoint(x: 0.0, y: 0.5)
    
    /// End point for gradient (default: CGPoint(x: 1.0, y: 0.5) - left to right)
    public var callToActionGradientEndPoint: CGPoint = CGPoint(x: 1.0, y: 0.5)
    
    /// Private initializer to enforce singleton pattern
    private init() {
        // Default initialization - all properties are nil
    }
    
    /// Reset all configuration to default values
    public func reset() {
        headlineFont = nil
        bodyFont = nil
        callToActionFont = nil
        callToActionBackgroundColor = nil
        headlineTextColor = nil
        bodyTextColor = nil
        callToActionTextColor = nil
        borderColor = nil
        borderWidth = nil
        backgroundColor = nil
        adsLabelBackgroundColor = nil
        useGradientForCallToAction = false
        callToActionGradientStartColor = nil
        callToActionGradientEndColor = nil
        callToActionGradientStartPoint = CGPoint(x: 0.0, y: 0.5)
        callToActionGradientEndPoint = CGPoint(x: 1.0, y: 0.5)
    }
}

/// Service to manage native ads loading and display
@MainActor
public class NativeAdService {
    
    // MARK: - Properties
    
    /// Current delegate helper to prevent deallocation
    private var currentDelegateHelper: NativeAdLoaderDelegateHelper?
    
    /// Current ad loader to prevent deallocation
    private var currentAdLoader: AdLoader?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Native Ad View Type
    
    /// Enum to specify which native ad view template to use
    public enum NativeAdViewType {
        case small
        case medium
        
        /// Returns the xib file name for the view type
        var xibName: String {
            switch self {
            case .small:
                return "NativeAdViewSmall"
            case .medium:
                return "NativeAdViewMedium"
            }
        }
    }
    
    // MARK: - Public Methods

    /// Load and display native ad from network (no caching)
    ///
    /// **Note:** This method always loads from network and does NOT use caching.
    /// For cache support, use:
    /// - `AdMobHelper.shared.loadNativeAd()` with `enableCache: true` (recommended)
    /// - `AdMobHelper.shared.loadNativeAdWithCache()` with manual cache key
    ///
    /// - Parameters:
    ///   - containerView: The view container to add the native ad view to
    ///   - adUnitID: The ad unit identifier for the native ad
    ///   - rootViewController: The view controller that will present the ad
    ///   - viewType: The type of native ad view template to use (.small or .medium)
    ///   - configuration: Optional configuration for customizing ad appearance. If nil, uses `NativeAdConfiguration.shared` singleton
    ///   - statusCallback: Optional callback to notify success (true) or failure (false)
    public func loadNativeAd(
        containerView: UIView,
        adUnitID: AdUnitIdentifiable,
        rootViewController: UIViewController,
        viewType: NativeAdViewType,
        configuration: NativeAdConfiguration? = nil,
        statusCallback: ((Bool) -> Void)? = nil
    ) {
        // Always loads from network (no caching)
        loadNativeAdFromNetwork(
            containerView: containerView,
            adUnitID: adUnitID,
            rootViewController: rootViewController,
            viewType: viewType,
            configuration: configuration,
            statusCallback: statusCallback
        )
    }

    // MARK: - Internal method for cache integration

    /// Load and display native ad from network with cache support (internal)
    /// - Parameters:
    ///   - containerView: The view container to add the native ad view to
    ///   - adUnitID: The ad unit identifier
    ///   - rootViewController: The view controller that will present the ad
    ///   - viewType: The type of native ad view template to use
    ///   - configuration: Optional configuration for customizing appearance
    ///   - cacheKey: Optional cache key for storing the loaded ad
    ///   - statusCallback: Optional callback to notify success or failure
    func loadNativeAdFromNetworkWithCache(
        containerView: UIView,
        adUnitID: AdUnitIdentifiable,
        rootViewController: UIViewController,
        viewType: NativeAdViewType,
        configuration: NativeAdConfiguration? = nil,
        cacheKey: String?,
        statusCallback: ((Bool) -> Void)? = nil
    ) {
        // Delegate to existing private method with cache key
        loadNativeAdFromNetwork(
            containerView: containerView,
            adUnitID: adUnitID,
            rootViewController: rootViewController,
            viewType: viewType,
            configuration: configuration,
            cacheKey: cacheKey,
            statusCallback: statusCallback
        )
    }

    /// Load and display native ad from network (original method)
    /// - Parameters:
    ///   - containerView: The view container to add the native ad view to
    ///   - adUnitID: The ad unit identifier for the native ad
    ///   - rootViewController: The view controller that will present the ad
    ///   - viewType: The type of native ad view template to use (.small or .medium)
    ///   - configuration: Optional configuration for customizing ad appearance. If nil, uses `NativeAdConfiguration.shared` singleton
    ///   - cacheKey: Optional cache key for storing the loaded ad
    ///   - statusCallback: Optional callback to notify success (true) or failure (false)
    private func loadNativeAdFromNetwork(
        containerView: UIView,
        adUnitID: AdUnitIdentifiable,
        rootViewController: UIViewController,
        viewType: NativeAdViewType,
        configuration: NativeAdConfiguration? = nil,
        cacheKey: String? = nil,
        statusCallback: ((Bool) -> Void)? = nil
    ) {
        // Clear existing subviews
        containerView.subviews.forEach { $0.removeFromSuperview() }

        // Show loading view based on view type
        let loadingView: UIView
        switch viewType {
        case .small:
            let smallLoading = NativeAdSmallLoadingView()
            loadingView = smallLoading
        case .medium:
            let mediumLoading = NativeAdMediumLoadingView()
            // Apply configuration to loading view
            mediumLoading.applyConfiguration(configuration ?? NativeAdConfiguration.shared)
            loadingView = mediumLoading
        }

        containerView.addSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Clear previous delegate helper and ad loader
        currentDelegateHelper = nil
        currentAdLoader = nil
        
        // Create new delegate helper
        let delegateHelper = NativeAdLoaderDelegateHelper()
        
        // Keep reference to prevent deallocation
        currentDelegateHelper = delegateHelper
        
        // Setup success callback
        delegateHelper.onAdLoaded = { [weak containerView] nativeAd in
            guard let containerView = containerView else {
                statusCallback?(false)
                return
            }
            
            // Remove loading view
            containerView.subviews.forEach { view in
                if let smallLoading = view as? NativeAdSmallLoadingView {
                    smallLoading.stopAnimation()
                    view.removeFromSuperview()
                } else if let mediumLoading = view as? NativeAdMediumLoadingView {
                    mediumLoading.stopAnimation()
                    view.removeFromSuperview()
                }
            }
            
            // Load native ad view from xib
            guard let loadedView = self.loadNativeAdViewFromXib(type: viewType) else {
                debugPrint("NativeAdService: Failed to load native ad view from xib: \(viewType.xibName)")
                statusCallback?(false)
                return
            }
            
            // Setup native ad data
            self.setupNativeAdView(loadedView, with: nativeAd, configuration: configuration)
            
            // Add view to container
            containerView.addSubview(loadedView)
            
            loadedView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            // Force layout update
            containerView.setNeedsLayout()
            containerView.layoutIfNeeded()
            loadedView.setNeedsLayout()
            loadedView.layoutIfNeeded()

            // Cache the ad if cache key provided
            if let cacheKey = cacheKey {
                AdMobHelper.shared.cacheNativeAd(nativeAd, for: cacheKey)
                AdMobHelper.shared.associateNativeAdCacheKey(cacheKey, with: nativeAd)
                debugPrint("📦 [NATIVE_CACHE] Cached for '\(cacheKey)' - waiting for impression")
            }

            statusCallback?(true)
        }
        
        // Setup failure callback
        delegateHelper.onAdFailed = { [weak containerView] error in
            debugPrint("NativeAdService: Native ad failed to load with error: \(error.localizedDescription)")
            
            // Remove loading view on failure
            containerView?.subviews.forEach { view in
                if let smallLoading = view as? NativeAdSmallLoadingView {
                    smallLoading.stopAnimation()
                    view.removeFromSuperview()
                } else if let mediumLoading = view as? NativeAdMediumLoadingView {
                    mediumLoading.stopAnimation()
                    view.removeFromSuperview()
                }
            }
            
            statusCallback?(false)
        }
        
        // Load native ad
        // Keep reference to AdLoader to prevent deallocation
        let adLoader = AdMobHelper.shared.loadNativeAd(
            adUnitID: adUnitID,
            rootViewController: rootViewController,
            delegate: delegateHelper
        )
        
        // Store ad loader to prevent deallocation
        currentAdLoader = adLoader
    }
    
    /// Load and display native ad with configuration
    /// - Parameters:
    ///   - containerView: The view container to add the native ad view to
    ///   - adUnitID: The ad unit identifier for the native ad
    ///   - rootViewController: The view controller that will present the ad
    ///   - viewType: The type of native ad view template to use (.small or .medium)
    ///   - configuration: Configuration for customizing ad appearance
    ///   - statusCallback: Optional callback to notify success (true) or failure (false)
    func loadNativeAdWithConfiguration(
        containerView: UIView,
        adUnitID: AdUnitIdentifiable,
        rootViewController: UIViewController,
        viewType: NativeAdViewType,
        configuration: NativeAdConfiguration,
        statusCallback: ((Bool) -> Void)? = nil
    ) {
        loadNativeAd(
            containerView: containerView,
            adUnitID: adUnitID,
            rootViewController: rootViewController,
            viewType: viewType,
            configuration: configuration,
            statusCallback: statusCallback
        )
    }
    
    // MARK: - Helper Methods
    
    /// Load native ad view from xib based on view type
    /// - Parameter type: The native ad view type (.small or .medium)
    /// - Returns: NativeAdView instance loaded from xib, or nil if failed
    private func loadNativeAdViewFromXib(type: NativeAdViewType) -> NativeAdView? {
        switch type {
        case .small:
            // Use custom class NativeAdViewSmall - load directly from XIB
            return NativeAdViewSmall.loadFromXib()
        case .medium:
            // Use custom class NativeAdViewMedium - load directly from XIB
            return NativeAdViewMedium.loadFromXib()
        }
    }
    
    /// Setup native ad view with native ad data
    /// - Parameters:
    ///   - nativeAdView: The native ad view to setup
    ///   - nativeAd: The native ad data
    ///   - configuration: Optional configuration for customizing appearance (uses shared singleton if nil)
    private func setupNativeAdView(_ nativeAdView: NativeAdView, with nativeAd: NativeAd, configuration: NativeAdConfiguration? = nil) {
        // Set native ad to view
        // In newer versions of Google Mobile Ads SDK, setting nativeAd property
        // automatically handles registration. The outlets connected in xib will be used.
        nativeAdView.nativeAd = nativeAd
        
        // Set delegate to track native ad clicks
        nativeAd.delegate = AdMobHelper.shared
        
        // Use provided configuration or fall back to shared singleton
        let configToUse = configuration ?? NativeAdConfiguration.shared

        // If using custom class NativeAdViewSmall, use its applyConfiguration method
        if let customView = nativeAdView as? NativeAdViewSmall {
            customView.applyConfiguration(configToUse)
        } else if let customView = nativeAdView as? NativeAdViewMedium {
            // If using custom class NativeAdViewMedium, use its applyConfiguration method
            customView.applyConfiguration(configToUse)

            // Handle media view visibility
            let hasMedia = nativeAd.mediaContent != nil &&
                          (nativeAd.mediaContent.hasVideoContent ||
                           nativeAd.mediaContent.mainImage != nil)
            customView.updateMediaVisibility(hasMedia: hasMedia)
        } else {
            // Fallback to manual configuration for other view types
            applyConfigurationManually(to: nativeAdView, with: nativeAd, configuration: configToUse)
        }
        
        // Populate the views with ad data
        // Headline
        if let headlineView = nativeAdView.headlineView as? UILabel {
            headlineView.text = nativeAd.headline
        }
        
        // Body
        if let bodyView = nativeAdView.bodyView as? UILabel {
            bodyView.text = nativeAd.body
        }
        
        // Call to action button
        if let callToActionView = nativeAdView.callToActionView as? UIButton {
            callToActionView.setTitle(nativeAd.callToAction, for: .normal)
        }
        
        // Icon
        if let iconView = nativeAdView.iconView as? UIImageView,
           let icon = nativeAd.icon?.image {
            iconView.image = icon
        }
        
        // Advertiser
        if let advertiserView = nativeAdView.advertiserView as? UILabel {
            advertiserView.text = nativeAd.advertiser
        }
        
        // Star rating
        if let starRatingView = nativeAdView.starRatingView as? UIView,
           let starRating = nativeAd.starRating {
            // Star rating is typically handled by the view itself when nativeAd is set
        }
        
        // Price
        if let priceView = nativeAdView.priceView as? UILabel {
            priceView.text = nativeAd.price
        }
        
        // Store
        if let storeView = nativeAdView.storeView as? UILabel {
            storeView.text = nativeAd.store
        }
    }
    
    /// Apply configuration manually for views that don't have custom applyConfiguration method
    private func applyConfigurationManually(to nativeAdView: NativeAdView, with nativeAd: NativeAd, configuration: NativeAdConfiguration) {
        let config = configuration
        
        // Headline
        if let headlineView = nativeAdView.headlineView as? UILabel {
            if let font = config.headlineFont {
                headlineView.font = font
            }
            if let color = config.headlineTextColor {
                headlineView.textColor = color
            }
        }
        
        // Body
        if let bodyView = nativeAdView.bodyView as? UILabel {
            if let font = config.bodyFont {
                bodyView.font = font
            }
            if let color = config.bodyTextColor {
                bodyView.textColor = color
            }
        }
        
        // Call to action button
        if let callToActionView = nativeAdView.callToActionView as? UIButton {
            if let font = config.callToActionFont {
                callToActionView.titleLabel?.font = font
            }
            
            // Remove any existing gradient layers first
            callToActionView.layer.sublayers?.forEach { layer in
                if layer is CAGradientLayer {
                    layer.removeFromSuperlayer()
                }
            }
            
            // Apply gradient or solid background color
            if config.useGradientForCallToAction,
               let startColor = config.callToActionGradientStartColor,
               let endColor = config.callToActionGradientEndColor {
                // Apply gradient
                let gradientLayer = CAGradientLayer()
                gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
                gradientLayer.startPoint = config.callToActionGradientStartPoint
                gradientLayer.endPoint = config.callToActionGradientEndPoint
                gradientLayer.frame = callToActionView.bounds
                gradientLayer.cornerRadius = callToActionView.layer.cornerRadius
                
                // Insert gradient layer at the bottom
                callToActionView.layer.insertSublayer(gradientLayer, at: 0)
                callToActionView.backgroundColor = .clear
            } else if let backgroundColor = config.callToActionBackgroundColor {
                // Apply solid background color
                callToActionView.backgroundColor = backgroundColor
            }
            
            if let textColor = config.callToActionTextColor {
                callToActionView.setTitleColor(textColor, for: .normal)
            }
        }
    }

    /// Display a native ad that's already loaded (from cache or otherwise)
    /// - Parameters:
    ///   - nativeAd: The loaded native ad
    ///   - containerView: The view container to add the native ad view to
    ///   - viewType: The type of native ad view template to use
    ///   - configuration: Optional configuration for customizing appearance
    ///   - rootViewController: The view controller that will present the ad
    private func displayNativeAd(
        _ nativeAd: NativeAd,
        in containerView: UIView,
        viewType: NativeAdViewType,
        configuration: NativeAdConfiguration?,
        rootViewController: UIViewController
    ) {
        // Clear existing subviews
        containerView.subviews.forEach { $0.removeFromSuperview() }

        // Load native ad view from xib
        guard let nativeAdView = loadNativeAdViewFromXib(type: viewType) else {
            debugPrint("Failed to load native ad view from xib")
            return
        }

        // Setup the view with ad data
        setupNativeAdView(nativeAdView, with: nativeAd, configuration: configuration)

        // Add native ad view to container
        containerView.addSubview(nativeAdView)
        nativeAdView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

