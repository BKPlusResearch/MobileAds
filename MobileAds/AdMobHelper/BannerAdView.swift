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
    public func loadAd(
        adUnitID: AdUnitIdentifiable,
        rootViewController: UIViewController,
        isCollapsible: Bool = false,
        collapsiblePlacement: BannerCollapsiblePlacement = .bottom
    ) {
        // Skip nếu đã có banner đang hiển thị
        if let existing = bannerView, existing.superview != nil {
            return
        }

        // Consent check
        guard GoogleMobileAdsConsentManager.shared.canRequestAds else {
            isHidden = true
            return
        }

        // Reveal view (có thể bị ẩn sau clearAd())
        isHidden = false

        let cacheKey = adUnitID.adUnitIDString

        // Cache hit → serve ngay, không cần network request
        if let entry = BannerAdView.cache[cacheKey], entry.isValid {
            debugPrint("✅ [BannerAdView] Cache hit for '\(cacheKey)'")
            displayCached(entry.bannerView, cacheKey: cacheKey)
            return
        }

        // Cache miss / expired
        BannerAdView.cache.removeValue(forKey: cacheKey)
        debugPrint("⏳ [BannerAdView] Cache miss for '\(cacheKey)', loading from network...")

        // Cleanup previous
        adDelegate = nil
        bannerView?.delegate = nil
        bannerView?.removeFromSuperview()
        bannerView = nil

        // Show loading shimmer
        loadingView.isHidden = false
        loadingView.startAnimation()
        bringSubviewToFront(loadingView)

        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)

        let banner = BannerView(adSize: adSize)
        banner.adUnitID = cacheKey
        banner.rootViewController = rootViewController

        let delegate = BannerAdViewDelegate(container: self, cacheKey: cacheKey)
        banner.delegate = delegate
        adDelegate = delegate  // strong ref — BannerView.delegate là weak

        bannerView = banner
        addSubview(banner)
        banner.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let request = Request()
        if isCollapsible {
            let extras = Extras()
            extras.additionalParameters = ["collapsible": collapsiblePlacement.rawValue]
            request.register(extras)
        }
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
        let delegate = BannerAdViewDelegate(container: self, cacheKey: cacheKey)
        cached.delegate = delegate
        adDelegate = delegate
        bannerView = cached

        addSubview(cached)
        cached.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Cached banner không cần shimmer
        hideLoading()
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

    init(container: BannerAdView, cacheKey: String) {
        self.container = container
        self.cacheKey = cacheKey
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        // Cache banner sau khi load thành công
        BannerAdView.cache[cacheKey] = BannerAdView.CachedEntry(
            bannerView: bannerView,
            loadedTime: Date()
        )
        debugPrint("📦 [BannerAdView] Cached banner for '\(cacheKey)' — waiting for impression")
        container?.hideLoading()
        container?.isHidden = false
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("BannerAdView: ❌ \(error.localizedDescription)")
        BannerAdView.cache.removeValue(forKey: cacheKey)
        container?.hideLoading()
        container?.isHidden = true
    }

    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        // Ad đã được user thấy → xoá cache, lần sau load fresh
        BannerAdView.cache.removeValue(forKey: cacheKey)
        debugPrint("🗑️ [BannerAdView] Cache cleared after impression for '\(cacheKey)'")
    }
}
