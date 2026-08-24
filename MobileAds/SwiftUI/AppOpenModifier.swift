import SwiftUI

/// ViewModifier that manages App Open Ad lifecycle (preload + show on foreground).
/// Does NOT need a VC bridge — `showAppOpenAd(from: nil)` works fine.
///
/// Usage:
/// ```swift
/// ContentView()
///     .appOpenAd(
///         adUnitID: AppAdUnit.appOpen,
///         isEnabled: !entitlements.isEntitled
///     )
/// ```
///
/// - Important: Gate on `EntitlementService.isEntitled`, and only once
///   `verification == .verified` — `isEntitled` is `false` until StoreKit answers, so
///   gating on it too early shows ads to a paying subscriber. See the README.
@available(iOS 15.0, *)
public struct AppOpenModifier: ViewModifier {
    let adUnitID: AdUnitIdentifiable
    let isEnabled: Bool
    var onStatusChange: ((AppOpenAdStatus) -> Void)?

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasPreloaded = false
    // Only a real background trip earns a resume ad. `.active` is also reached from
    // `.inactive` — a control centre pull, the app switcher, an incoming call — and the
    // UIKit path never shows an ad for those, because willEnterForeground does not fire.
    @State private var didEnterBackground = false

    public func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { newPhase in
                guard isEnabled else { return }

                switch newPhase {
                case .active:
                    guard hasPreloaded else {
                        // First launch → preload only
                        hasPreloaded = true
                        preload()
                        return
                    }

                    // Returning from .inactive without a background trip is not a resume.
                    guard didEnterBackground else { return }
                    didEnterBackground = false

                    // Consume the skip flag. A full-screen ad shown just before the app
                    // left, or an ad click that took the user out, sets it; stacking a
                    // resume ad on top of that is what it exists to prevent. Resetting
                    // here is what lets the next background preload again — left set, it
                    // latches and silently stops every later app open ad.
                    guard !AdMobHelper.shared.shouldSkipNextAppResume else {
                        AdMobHelper.shared.resetAppResumeSkipFlag()
                        return
                    }

                    AdMobHelper.shared.showAppOpenAd(
                        statusCallback: onStatusChange
                    )
                case .background:
                    didEnterBackground = true
                    // Preload for next foreground, unless that resume is already spoken for.
                    guard !AdMobHelper.shared.shouldSkipNextAppResume else { return }
                    preload()
                default:
                    break
                }
            }
    }

    private func preload() {
        Task {
            try? await AdMobHelper.shared.loadAppOpenAd(
                adUnitID: adUnitID,
                shouldShowLoadingView: false
            )
        }
    }
}

@available(iOS 15.0, *)
public extension View {
    /// Attach app open ad behavior — auto-shows on foreground transitions.
    /// - Parameters:
    ///   - adUnitID: Ad unit ID for app open ads
    ///   - isEnabled: Control flag, e.g. `!EntitlementService.shared.isEntitled`
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
