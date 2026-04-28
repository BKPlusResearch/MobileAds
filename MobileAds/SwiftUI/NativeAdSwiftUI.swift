import SwiftUI

/// SwiftUI wrapper for native ads (Small/Medium) using `UIViewRepresentable`.
/// Delegates to `AdMobHelper.loadNativeAd(containerView:...)` from `+NativeCache` extension.
///
/// Usage:
/// ```swift
/// NativeAdSwiftUI(
///     adUnitID: AppAdUnit.nativeMedium,
///     viewType: .medium,
///     enableCache: true
/// )
/// .frame(height: 300)
/// ```
@available(iOS 15.0, *)
public struct NativeAdSwiftUI: UIViewRepresentable {
    let adUnitID: AdUnitIdentifiable
    let viewType: NativeAdService.NativeAdViewType
    var configuration: NativeAdConfiguration?
    var enableCache: Bool
    var onLoaded: ((Bool) -> Void)?

    public init(
        adUnitID: AdUnitIdentifiable,
        viewType: NativeAdService.NativeAdViewType = .medium,
        configuration: NativeAdConfiguration? = nil,
        enableCache: Bool = true,
        onLoaded: ((Bool) -> Void)? = nil
    ) {
        self.adUnitID = adUnitID
        self.viewType = viewType
        self.configuration = configuration
        self.enableCache = enableCache
        self.onLoaded = onLoaded
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        // Store config in coordinator
        context.coordinator.adUnitID = adUnitID
        context.coordinator.viewType = viewType
        context.coordinator.configuration = configuration
        context.coordinator.enableCache = enableCache
        context.coordinator.onLoaded = onLoaded

        // KVO observe window attachment
        context.coordinator.observation = container.observe(
            \.window, options: [.new]
        ) { view, _ in
            guard view.window != nil else { return }
            context.coordinator.loadAdIfNeeded(in: view)
        }

        return container
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
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
        var observation: NSKeyValueObservation?

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

        deinit {
            observation?.invalidate()
        }
    }
}
