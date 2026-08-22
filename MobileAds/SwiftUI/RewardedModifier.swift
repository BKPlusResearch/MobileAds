@preconcurrency import GoogleMobileAds
import SwiftUI

/// ViewModifier that presents a rewarded ad when `isPresented` becomes true.
///
/// Usage:
/// ```swift
/// .rewardedAd(
///     isPresented: $showRewarded,
///     adUnitID: AppAdUnit.rewarded,
///     onReward: { reward in coins += Int(reward.amount.intValue) }
/// )
/// ```
@available(iOS 15.0, *)
public struct RewardedModifier: ViewModifier {
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
                            try await AdMobHelper.shared.showRewardedAd(
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
                            debugPrint("Rewarded error: \(error)")
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
    /// Show a rewarded ad when `isPresented` becomes true.
    func rewardedAd(
        isPresented: Binding<Bool>,
        adUnitID: AdUnitIdentifiable,
        onReward: ((AdReward) -> Void)? = nil,
        onStatusChange: ((RewardedAdStatus) -> Void)? = nil
    ) -> some View {
        modifier(RewardedModifier(
            isPresented: isPresented,
            adUnitID: adUnitID,
            onReward: onReward,
            onStatusChange: onStatusChange
        ))
    }
}
