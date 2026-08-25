//
//  AdRevenueManager.swift
//  MobileAds
//
//  Created by shjn on 22/12/25.
//

import Foundation
import GoogleMobileAds

// MARK: - Ad Type

public enum AdType: String {
    case interstitial
    case appOpen
    case native
    case banner
    case reward
}

// MARK: - Ad Revenue Manager

/// Fans a single AdMob paid event out to every analytics/attribution surface
/// the pod integrates: Firebase Analytics, TikTok Business SDK and Facebook SDK.
/// Each destination SDK is initialized by its own manager, so there is nothing
/// to configure here.
public final class AdRevenueManager {
    public static let shared = AdRevenueManager()

    private init() {}

    // MARK: - Public Methods

    /// Log ad impression with revenue tracking (simple version)
    /// - Parameters:
    ///   - adType: Type of ad (interstitial, appOpen, native, banner, reward)
    ///   - adValue: AdValue from ad callback
    public func logRevenue(adType: AdType, adValue: AdValue) {
        let revenueUSD = Double(truncating: adValue.value)
        let currency = adValue.currencyCode

        debugPrint("💰 [AdRevenue] \(adType.rawValue) - \(revenueUSD) \(currency)")

        // Track to Firebase Analytics
        Task { @MainActor in
            logFirebaseRevenue(value: revenueUSD)
        }

        // Track to TikTok Business SDK (simple version)
        TikTokManager.shared.trackAdRevenue(adType: adType, revenueUSD: revenueUSD)

        // Track to Facebook SDK (AD_IMPRESSION)
        FacebookManager.shared.logAdImpression(adType: adType, revenueUSD: revenueUSD, currency: currency)
    }

    /// Log ad impression with revenue tracking (detailed version for TikTok)
    /// This method captures full AdMob response info for better TikTok attribution
    /// - Parameters:
    ///   - adType: Type of ad (interstitial, appOpen, native, banner, reward)
    ///   - adValue: AdValue from ad callback
    ///   - adUnitId: Ad unit ID
    ///   - responseInfo: ResponseInfo from the ad object
    public func logRevenue(adType: AdType, adValue: AdValue, adUnitId: String, responseInfo: ResponseInfo?) {
        let revenueUSD = Double(truncating: adValue.value)
        let currency = adValue.currencyCode

        debugPrint("💰 [AdRevenue] \(adType.rawValue) - \(revenueUSD) \(currency)")

        // Track to Firebase Analytics
        Task { @MainActor in
            logFirebaseRevenue(value: revenueUSD)
        }

        // Track to TikTok Business SDK (detailed version)
        let loadedAdNetworkResponseInfo = responseInfo?.loadedAdNetworkResponseInfo
        let extras = responseInfo?.extras

        let tiktokAdRevenueInfo = TikTokAdRevenueInfo(
            value: adValue.value,
            currencyCode: adValue.currencyCode,
            precision: adValue.precision,
            adUnitId: adUnitId,
            adSourceName: loadedAdNetworkResponseInfo?.adSourceName,
            adSourceId: loadedAdNetworkResponseInfo?.adSourceID,
            adSourceInstanceName: loadedAdNetworkResponseInfo?.adSourceInstanceName,
            adSourceInstanceId: loadedAdNetworkResponseInfo?.adSourceInstanceID,
            mediationGroupName: extras?["mediation_group_name"] as? String,
            mediationABTestName: extras?["mediation_ab_test_name"] as? String,
            mediationABTestVariant: extras?["mediation_ab_test_variant"] as? String
        )

        TikTokManager.shared.trackAdRevenueEvent(tiktokAdRevenueInfo)

        // Track to Facebook SDK (AD_IMPRESSION)
        FacebookManager.shared.logAdImpression(adType: adType, revenueUSD: revenueUSD, currency: currency)
    }

    // MARK: - Private Methods

    /// Log revenue to Firebase Analytics using FirebaseLogger
    private func logFirebaseRevenue(value: Double) {
        debugPrint("💰 [AdRevenue] \(#function) - \(value)")

        let safeRevenue = Double(String(format: "%.6f", value)) ?? 0.0
        FirebaseLogger.shared.logEvent(.adImpression, params: [
            .adPlatform: "AdMob",
            .currency: "USD",
            .value: safeRevenue
        ])
    }
}
