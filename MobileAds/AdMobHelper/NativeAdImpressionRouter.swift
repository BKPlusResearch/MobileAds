//
//  NativeAdImpressionRouter.swift
//  MobileAds
//

import UIKit
import GoogleMobileAds

/// Container view that wants to hear when the native ad it displays records an impression.
/// `NativeAdSwiftUI` uses one so its `onImpression` fires for its own ad only.
final class NativeAdImpressionHostView: UIView {
    var onImpression: (() -> Void)?
    /// Called each time the view lands in a window. `UIView.window` is not key-value observable
    /// (an observation never fires), so this override is how `NativeAdSwiftUI` learns it can load.
    var onMoveToWindow: ((UIView) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        onMoveToWindow?(self)
    }
}

/// Ties each displayed `NativeAd` to the container that shows it, so the shared
/// `nativeAdDidRecordImpression` delegate (one `AdMobHelper.shared` for every ad) can reach the
/// right placement.
///
/// Both sides are weak: an ad that leaves the screen before its impression must not be kept alive
/// by this table (see `NativeAdWeakMap`), nor may a removed container. A cached ad shown again in
/// a new container is re-bound to it. Main thread only, like the other native maps.
final class NativeAdImpressionRouter: @unchecked Sendable {
    static let shared = NativeAdImpressionRouter()

    private let table = NSMapTable<NativeAd, NativeAdImpressionHostView>.weakToWeakObjects()

    /// Called where an ad is added to `containerView`; ignores containers that are not hosts.
    func bind(_ nativeAd: NativeAd, to containerView: UIView) {
        guard let host = containerView as? NativeAdImpressionHostView else { return }
        table.setObject(host, forKey: nativeAd)
    }

    /// Called from `nativeAdDidRecordImpression`. An ad records one impression, so the binding is
    /// dropped after it fires.
    func routeImpression(of nativeAd: NativeAd) {
        guard let host = table.object(forKey: nativeAd) else { return }
        table.removeObject(forKey: nativeAd)
        host.onImpression?()
    }
}
