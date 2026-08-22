@preconcurrency import GoogleMobileAds
import SwiftUI

/// ViewModifier that presents a rewarded interstitial ad when `isPresented` becomes true.
///
/// Usage:
/// ```swift
/// .rewardedInterstitialAd(
///     isPresented: $showRI,
///     adUnitID: AppAdUnit.rewardedInterstitial,
///     onReward: { reward in gems += Int(reward.amount.intValue) }
/// )
/// ```
@available(iOS 15.0, *)
public struct RewardedInterstitialModifier: ViewModifier {
    @Binding var isPresented: Bool
    let adUnitID: AdUnitIdentifiable
    var onReward: ((AdReward) -> Void)?
    var onStatusChange: ((RewardedAdStatus) -> Void)?

    public func body(content: Content) -> some View {
        content
            .background(
                ViewControllerResolver { vc in
                    guard isPresented else { return }
                    Task { @MainActor in
                        do {
                            try await AdMobHelper.shared.showRewardedInterstitialAd(
                                from: vc,
                                adUnitID: adUnitID,
                                statusCallback: { status in
                                    onStatusChange?(status)
                                    if status == .didDismiss || status == .didEarnRewardAndDismiss || status == .didFailToPresent {
                                        isPresented = false
                                    }
                                },
                                completion: { reward in
                                    onReward?(reward)
                                }
                            )
                        } catch {
                            debugPrint("RewardedInterstitial error: \(error)")
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
    /// Show a rewarded interstitial ad when `isPresented` becomes true.
    func rewardedInterstitialAd(
        isPresented: Binding<Bool>,
        adUnitID: AdUnitIdentifiable,
        onReward: ((AdReward) -> Void)? = nil,
        onStatusChange: ((RewardedAdStatus) -> Void)? = nil
    ) -> some View {
        modifier(RewardedInterstitialModifier(
            isPresented: isPresented,
            adUnitID: adUnitID,
            onReward: onReward,
            onStatusChange: onStatusChange
        ))
    }
}
