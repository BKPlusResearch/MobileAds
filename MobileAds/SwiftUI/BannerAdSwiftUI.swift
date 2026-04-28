import SwiftUI

/// SwiftUI wrapper for `BannerAdView` (UIKit).
/// Uses `UIViewRepresentable` with KVO + asyncAfter fallback to safely resolve
/// the hosting `UIViewController` before loading the ad.
///
/// Usage:
/// ```swift
/// BannerAdSwiftUI(
///     adUnitID: AppAdUnit.banner,
///     isCollapsible: true,
///     collapsiblePlacement: .bottom
/// )
/// .frame(height: 60)
/// ```
@available(iOS 15.0, *)
public struct BannerAdSwiftUI: UIViewRepresentable {
    let adUnitID: AdUnitIdentifiable
    var isCollapsible: Bool = false
    var collapsiblePlacement: BannerCollapsiblePlacement = .bottom

    public init(
        adUnitID: AdUnitIdentifiable,
        isCollapsible: Bool = false,
        collapsiblePlacement: BannerCollapsiblePlacement = .bottom
    ) {
        self.adUnitID = adUnitID
        self.isCollapsible = isCollapsible
        self.collapsiblePlacement = collapsiblePlacement
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> BannerAdView {
        let view = BannerAdView()
        // Store config in coordinator
        context.coordinator.adUnitID = adUnitID
        context.coordinator.isCollapsible = isCollapsible
        context.coordinator.collapsiblePlacement = collapsiblePlacement

        // KVO observe \.window — fires when view enters the window hierarchy
        context.coordinator.observation = view.observe(
            \.window, options: [.new]
        ) { view, _ in
            guard view.window != nil else { return }
            context.coordinator.loadAdIfNeeded(in: view)
        }

        // Fallback: asyncAfter(0.1) in case KVO doesn't fire (per Validation Q4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.loadAdIfNeeded(in: view)
        }

        return view
    }

    public func updateUIView(_ uiView: BannerAdView, context: Context) {
        // Only reload if adUnitID actually changed
        let currentID = adUnitID.adUnitIDString
        if context.coordinator.loadedAdUnitID != currentID {
            context.coordinator.adUnitID = adUnitID
            context.coordinator.isCollapsible = isCollapsible
            context.coordinator.collapsiblePlacement = collapsiblePlacement
            context.coordinator.loadedAdUnitID = nil // Reset to allow reload
            context.coordinator.loadAdIfNeeded(in: uiView)
        }
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject {
        var adUnitID: AdUnitIdentifiable?
        var isCollapsible: Bool = false
        var collapsiblePlacement: BannerCollapsiblePlacement = .bottom
        var loadedAdUnitID: String?
        var observation: NSKeyValueObservation?

        func loadAdIfNeeded(in view: BannerAdView) {
            guard let adUnitID = adUnitID,
                  loadedAdUnitID != adUnitID.adUnitIDString,
                  let vc = view.nearestViewController ?? view.window?.rootViewController
            else { return }

            loadedAdUnitID = adUnitID.adUnitIDString
            view.loadAd(
                adUnitID: adUnitID,
                rootViewController: vc,
                isCollapsible: isCollapsible,
                collapsiblePlacement: collapsiblePlacement
            )
        }

        deinit {
            observation?.invalidate()
        }
    }
}
