import SwiftUI

/// SwiftUI wrapper for native ads (Small/Medium) using `UIViewRepresentable`.
/// Delegates to `AdMobHelper.loadNativeAd(containerView:...)` from `+NativeCache` extension.
///
/// Usage:
/// ```swift
/// NativeAdSwiftUI(
///     adUnitID: AppAdUnit.nativeMedium,
///     viewType: .medium,
///     enableCache: true,
///     onImpression: { /* log impression for this placement */ }
/// )
/// .frame(height: 300)
/// ```
///
/// `onImpression` is optional and fires when the ad shown by *this* view records an impression
/// (`nativeAdDidRecordImpression`), so a host can attribute it to a placement. The shared
/// `AdMobHelper.nativeAdStatusCallback` still fires for every native ad.
@available(iOS 15.0, *)
public struct NativeAdSwiftUI: UIViewRepresentable {
    let adUnitID: AdUnitIdentifiable
    let viewType: NativeAdService.NativeAdViewType
    var configuration: NativeAdConfiguration?
    var enableCache: Bool
    var onLoaded: ((Bool) -> Void)?
    var onImpression: (() -> Void)?

    public init(
        adUnitID: AdUnitIdentifiable,
        viewType: NativeAdService.NativeAdViewType = .medium,
        configuration: NativeAdConfiguration? = nil,
        enableCache: Bool = true,
        onLoaded: ((Bool) -> Void)? = nil,
        onImpression: (() -> Void)? = nil
    ) {
        self.adUnitID = adUnitID
        self.viewType = viewType
        self.configuration = configuration
        self.enableCache = enableCache
        self.onLoaded = onLoaded
        self.onImpression = onImpression
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> UIView {
        // A host view, so the impression delegate can find this view's handler
        let container = NativeAdImpressionHostView()
        container.backgroundColor = .clear
        container.onImpression = onImpression

        // Store config in coordinator
        context.coordinator.adUnitID = adUnitID
        context.coordinator.viewType = viewType
        context.coordinator.configuration = configuration
        context.coordinator.enableCache = enableCache
        context.coordinator.onLoaded = onLoaded

        // Load once the container is in a window: `updateUIView` runs before that on a fresh
        // mount (e.g. a new `.id`), so without this a new placement would stay empty.
        container.onMoveToWindow = { [weak coordinator = context.coordinator] view in
            coordinator?.loadAdIfNeeded(in: view)
        }

        return container
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        // Always take the latest handler: it may capture state that changed since creation.
        (uiView as? NativeAdImpressionHostView)?.onImpression = onImpression
        // Reload if adUnitID or viewType changed
        let currentKey = "\(adUnitID.adUnitIDString)_\(viewType)"
        if context.coordinator.loadedKey != currentKey {
            context.coordinator.adUnitID = adUnitID
            context.coordinator.viewType = viewType
            context.coordinator.configuration = configuration
            context.coordinator.enableCache = enableCache
            context.coordinator.onLoaded = onLoaded
            context.coordinator.loadedKey = nil
            context.coordinator.loadAdIfNeeded(in: uiView)
        }
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject {
        var adUnitID: AdUnitIdentifiable?
        var viewType: NativeAdService.NativeAdViewType = .medium
        var configuration: NativeAdConfiguration?
        var enableCache: Bool = true
        var onLoaded: ((Bool) -> Void)?
        var loadedKey: String?

        func loadAdIfNeeded(in containerView: UIView) {
            guard let adUnitID = adUnitID,
                  loadedKey != "\(adUnitID.adUnitIDString)_\(viewType)",
                  let vc = containerView.nearestViewController ?? containerView.window?.rootViewController
            else { return }

            loadedKey = "\(adUnitID.adUnitIDString)_\(viewType)"

            // Call the correct API from AdMobHelper+NativeCache
            Task { @MainActor in
                AdMobHelper.shared.loadNativeAd(
                    containerView: containerView,
                    adUnitID: adUnitID,
                    rootViewController: vc,
                    viewType: viewType,
                    configuration: configuration,
                    enableCache: enableCache,
                    statusCallback: onLoaded
                )
            }
        }
    }
}
