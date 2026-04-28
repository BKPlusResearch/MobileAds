import SwiftUI

/// ViewModifier that manages App Open Ad lifecycle (preload + show on foreground).
/// Does NOT need a VC bridge — `showAppOpenAd(from: nil)` works fine.
///
/// Usage:
/// ```swift
/// ContentView()
///     .appOpenAd(
///         adUnitID: AppAdUnit.appOpen,
///         isEnabled: !iapVM.isPurchased
///     )
/// ```
@available(iOS 15.0, *)
public struct AppOpenModifier: ViewModifier {
    let adUnitID: AdUnitIdentifiable
    let isEnabled: Bool
    var onStatusChange: ((AppOpenAdStatus) -> Void)?

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasPreloaded = false

    public func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { newPhase in
                guard isEnabled else { return }
                guard AdMobHelper.shared.checkEnableShowAds() else { return }

                switch newPhase {
                case .active:
                    if hasPreloaded {
                        // App returned from background → show ad
                        AdMobHelper.shared.showAppOpenAd(
                            statusCallback: onStatusChange
                        )
                    } else {
                        // First launch → preload only
                        hasPreloaded = true
                        Task {
                            try? await AdMobHelper.shared.loadAppOpenAd(
                                adUnitID: adUnitID,
                                shouldShowLoadingView: false
                            )
                        }
                    }
                case .background:
                    // Preload for next foreground
                    guard !AdMobHelper.shared.shouldSkipNextAppResume else { return }
                    Task {
                        try? await AdMobHelper.shared.loadAppOpenAd(
                            adUnitID: adUnitID,
                            shouldShowLoadingView: false
                        )
                    }
                default:
                    break
                }
            }
    }
}

@available(iOS 15.0, *)
public extension View {
    /// Attach app open ad behavior — auto-shows on foreground transitions.
    /// - Parameters:
    ///   - adUnitID: Ad unit ID for app open ads
    ///   - isEnabled: Control flag (e.g. `!isPurchased`)
    ///   - onStatusChange: Optional status callback
    func appOpenAd(
        adUnitID: AdUnitIdentifiable,
        isEnabled: Bool = true,
        onStatusChange: ((AppOpenAdStatus) -> Void)? = nil
    ) -> some View {
        modifier(AppOpenModifier(
            adUnitID: adUnitID,
            isEnabled: isEnabled,
            onStatusChange: onStatusChange
        ))
    }
}
