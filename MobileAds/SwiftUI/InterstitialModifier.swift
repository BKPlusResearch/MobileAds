import SwiftUI

/// ViewModifier that presents an interstitial ad when `isPresented` becomes true.
/// Embeds an invisible `ViewControllerResolver` to obtain the hosting VC.
///
/// Usage:
/// ```swift
/// .interstitialAd(
///     isPresented: $showAd,
///     adUnitID: AppAdUnit.interstitial
/// )
/// ```
@available(iOS 15.0, *)
public struct InterstitialModifier: ViewModifier {
    @Binding var isPresented: Bool
    let adUnitID: AdUnitIdentifiable
    var onStatusChange: ((InterstitialAdStatus) -> Void)?

    public func body(content: Content) -> some View {
        content
            .background(
                ViewControllerResolver { vc in
                    print("[vunt ads] InterstitialModifier.onResolve fired, isPresented=\(isPresented)")
                    guard isPresented else { return }
                    Task { @MainActor in
                        print("[vunt ads] InterstitialModifier Task started — loading ad")
                        do {
                            try await AdMobHelper.shared.loadInterstitialAd(
                                adUnitID: adUnitID,
                                shouldShowLoadingView: true
                            )
                            print("[vunt ads] InterstitialModifier ad loaded — presenting")
                            try AdMobHelper.shared.showInterstitialAd(
                                from: vc,
                                shouldShowLoadingView: true,
                                statusCallback: { status in
                                    print("[vunt ads] InterstitialModifier status=\(status)")
                                    onStatusChange?(status)
                                    if status == .didDismiss || status == .didFailToPresent {
                                        print("[vunt ads] InterstitialModifier resetting isPresented=false")
                                        isPresented = false
                                    }
                                }
                            )
                        } catch {
                            print("[vunt ads] InterstitialModifier error: \(error)")
                            isPresented = false
                        }
                    }
                }
                .frame(width: 0, height: 0)
            )
    }
}

@available(iOS 15.0, *)
public extension View {
    /// Show an interstitial ad when `isPresented` becomes true.
    func interstitialAd(
        isPresented: Binding<Bool>,
        adUnitID: AdUnitIdentifiable,
        onStatusChange: ((InterstitialAdStatus) -> Void)? = nil
    ) -> some View {
        modifier(InterstitialModifier(
            isPresented: isPresented,
            adUnitID: adUnitID,
            onStatusChange: onStatusChange
        ))
    }
}
