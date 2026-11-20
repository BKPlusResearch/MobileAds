//
//  BannerAdView.swift
//  MobileAds
//
//  Created by Auto on 2025.
//

@preconcurrency import GoogleMobileAds
import UIKit
import SnapKit

/// Self-contained banner ad view.
/// Manages its own BannerView + delegate — does NOT use AdMobHelper.shared singleton.
/// Use this to avoid singleton conflict when multiple banners are needed simultaneously.
public class BannerAdView: UIView {

    // MARK: - Cache

    fileprivate struct CachedEntry {
        let bannerView: BannerView
        let loadedTime: Date
        /// Valid within 1 hour (AdMob policy)
        var isValid: Bool { Date().timeIntervalSince(loadedTime) < 3600 }
    }

    /// Static cache — persists across navigation, keyed by adUnitIDString.
    fileprivate static var cache: [String: CachedEntry] = [:]

    // MARK: - Properties

    private var bannerView: BannerView?
    private var adDelegate: BannerAdViewDelegate?
    private let loadingView = BannerAdLoadingView()

    /// Receives this view's ad events (impression, click, load result, collapsible expanded,
    /// full-screen present/dismiss) on the main thread. Optional; set it before `loadAd` to see
    /// the load result. See `BannerAdEvent` for what each case is built from.
    public var onEvent: ((BannerAdEvent) -> Void)?

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupLoadingView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLoadingView()
    }

    private func setupLoadingView() {
        addSubview(loadingView)
        loadingView.isHidden = true
        loadingView.stopAnimation()
        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - Public API

    /// Load và hiển thị banner ad.
    /// - Serve từ cache nếu banner đã load trong vòng 1 giờ và chưa bắn impression.
    /// - Hiển thị shimmer loading khi cần load từ network.
    /// - isPurchase check phải được xử lý ở app layer trước khi gọi hàm này.
    /// - `adSize`: the standard size requested (`BannerAdSize`, 320 x 50 by default). The ad is
    ///   centered in this view; give the view `adSize.height`.
    public func loadAd(
        adUnitID: AdUnitIdentifiable,
        rootViewController: UIViewController,
        isCollapsible: Bool = false,
        collapsiblePlacement: BannerCollapsiblePlacement = .bottom,
        adSize: BannerAdSize = .small
    ) {
        let cacheKey = adUnitID.adUnitIDString

        // 1. Nếu là banner thường và đã có ad đang hiển thị -> Chỉ cần track SHOW (metrics nội bộ)
        if !isCollapsible, let existing = bannerView, existing.superview != nil {
            AdMetricsTracker.shared.trackShow(adUnit: cacheKey)
            return
        }

        // 2. Consent check
        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            isHidden = true
            return
        }

        // Reveal view
        isHidden = false

        // 3. Cache hit logic
        // KHÔNG dùng cache cho collapsible banner để đảm bảo hiệu ứng thu phóng luôn hoạt động
        if !isCollapsible, let entry = BannerAdView.cache[cacheKey], entry.isValid {
            debugPrint("✅ [BannerAdView] Cache hit for '\(cacheKey)'")
            displayCached(entry.bannerView, cacheKey: cacheKey)
            AdMetricsTracker.shared.trackShow(adUnit: cacheKey)
            onEvent?(.didLoad)
            return
        }

        // 4. Cache miss / Fresh load (Collapsible luôn lọt vào đây)
        BannerAdView.cache.removeValue(forKey: cacheKey)
        if isCollapsible {
            debugPrint("🔄 [BannerAdView] Force network load for COLLAPSIBLE '\(cacheKey)'")
        } else {
            debugPrint("⏳ [BannerAdView] Cache miss for '\(cacheKey)', loading from network...")
        }

        // Cleanup previous
        adDelegate = nil
        bannerView?.delegate = nil
        bannerView?.removeFromSuperview()
        bannerView = nil

        // Show loading shimmer
        loadingView.isHidden = false
        loadingView.startAnimation()
        bringSubviewToFront(loadingView)

        let banner = BannerView(adSize: adSize.adSize)
        banner.adUnitID = cacheKey
        banner.rootViewController = rootViewController

        let delegate = BannerAdViewDelegate(container: self, cacheKey: cacheKey,
                                            requestedCollapsible: isCollapsible)
        banner.delegate = delegate
        adDelegate = delegate

        bannerView = banner

        // Track ad revenue (Facebook AD_IMPRESSION, TikTok, Firebase)
        banner.paidEventHandler = { adValue in
            AdRevenueManager.shared.logRevenue(adType: .banner, adValue: adValue)
        }

        addSubview(banner)
        Self.center(banner, size: adSize.adSize.size)

        let request = Request()
        if isCollapsible {
            let extras = Extras()
            extras.additionalParameters = ["collapsible": collapsiblePlacement.rawValue]
            request.register(extras)
        }
        
        // Track Request (Show will be tracked in bannerViewDidReceiveAd)
        AdMetricsTracker.shared.trackRequest(adUnit: cacheKey, adType: .banner)
        banner.load(request)
    }

    /// Reset về trạng thái ban đầu — KHÔNG xoá cache.
    /// Cache giữ nguyên để khi user quay lại có thể serve ngay.
    public func clearAd() {
        hideLoading()
        adDelegate = nil
        bannerView?.delegate = nil
        bannerView?.removeFromSuperview()
        bannerView = nil
        isHidden = true
    }

    // MARK: - Private Helpers

    private func displayCached(_ cached: BannerView, cacheKey: String) {
        // Cleanup previous
        adDelegate = nil
        bannerView?.delegate = nil
        bannerView?.removeFromSuperview()
        bannerView = nil

        // Setup delegate để vẫn track impression → clear cache
        let delegate = BannerAdViewDelegate(container: self, cacheKey: cacheKey,
                                            requestedCollapsible: false)
        cached.delegate = delegate
        adDelegate = delegate
        bannerView = cached

        addSubview(cached)
        Self.center(cached, size: cached.adSize.size)

        // Cached banner không cần shimmer
        hideLoading()
    }

    /// Pins a banner at its own standard size, centered: a standard creative fills exactly that box,
    /// and the rest of a wider view stays empty instead of stretching the ad.
    private static func center(_ banner: BannerView, size: CGSize) {
        banner.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(size)
        }
    }

    fileprivate func hideLoading() {
        loadingView.stopAnimation()
        loadingView.isHidden = true
    }
}

// MARK: - BannerAdViewDelegate (private)

private class BannerAdViewDelegate: NSObject, BannerViewDelegate {
    weak var container: BannerAdView?
    let cacheKey: String
    /// Only a request sent with the `collapsible` extra can come back expanded.
    let requestedCollapsible: Bool

    init(container: BannerAdView, cacheKey: String, requestedCollapsible: Bool) {
        self.container = container
        self.cacheKey = cacheKey
        self.requestedCollapsible = requestedCollapsible
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        // Cache banner sau khi load thành công
        BannerAdView.cache[cacheKey] = BannerAdView.CachedEntry(
            bannerView: bannerView,
            loadedTime: Date()
        )
        AdMetricsTracker.shared.trackLoaded(adUnit: cacheKey)
        AdMetricsTracker.shared.trackShow(adUnit: cacheKey)
        debugPrint("📦 [BannerAdView] Cached banner for '\(cacheKey)' — waiting for impression")
        container?.hideLoading()
        container?.isHidden = false
        container?.onEvent?(.didLoad)
        // The SDK shows a collapsible ad's expanded overlay as soon as it is in the hierarchy,
        // and this banner already is (added before `load`).
        if requestedCollapsible && bannerView.isCollapsible {
            container?.onEvent?(.didShowCollapsibleExpanded)
        }
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("BannerAdView: ❌ \(error.localizedDescription)")
        AdMetricsTracker.shared.trackLoadFailed(adUnit: cacheKey)
        BannerAdView.cache.removeValue(forKey: cacheKey)
        container?.hideLoading()
        container?.isHidden = true
        container?.onEvent?(.didFailToLoad(error as NSError))
    }

    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        // Ad đã được user thấy → xoá cache, lần sau load fresh
        AdMetricsTracker.shared.trackImpression(adUnit: cacheKey)
        BannerAdView.cache.removeValue(forKey: cacheKey)
        debugPrint("🗑️ [BannerAdView] Cache cleared after impression for '\(cacheKey)'")
        container?.onEvent?(.didRecordImpression)
    }

    func bannerViewDidRecordClick(_ bannerView: BannerView) {
        AdMetricsTracker.shared.trackClick(adUnit: cacheKey)
        container?.onEvent?(.didRecordClick)
    }

    func bannerViewWillPresentScreen(_ bannerView: BannerView) {
        debugPrint("🪟 [BannerAdView] willPresentScreen for '\(cacheKey)'")
        container?.onEvent?(.willPresentScreen)
    }

    func bannerViewWillDismissScreen(_ bannerView: BannerView) {
        debugPrint("🪟 [BannerAdView] willDismissScreen for '\(cacheKey)'")
        container?.onEvent?(.willDismissScreen)
    }

    func bannerViewDidDismissScreen(_ bannerView: BannerView) {
        debugPrint("🪟 [BannerAdView] didDismissScreen for '\(cacheKey)'")
        container?.onEvent?(.didDismissScreen)
    }
}
