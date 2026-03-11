//
//  FacebookManager.swift
//  MobileAds
//
//  Created by MobileAds Framework
//

import Foundation
import FBSDKCoreKit
import GoogleMobileAds

// MARK: - Facebook Manager

public final class FacebookManager {
    public static let shared = FacebookManager()

    private init() {}

    // MARK: - AD_IMPRESSION Logging

    /// Log AD_IMPRESSION event to Facebook SDK
    /// Follows: https://developers.facebook.com/docs/app-events/guides/maximize-in-app-ad-revenue/
    /// - Parameters:
    ///   - adType: Type of ad (interstitial, appOpen, native, banner, reward)
    ///   - revenueUSD: Revenue value from AdMob's AdValue
    ///   - currency: Currency code from AdMob's AdValue (e.g., "USD")
    public func logAdImpression(adType: ADJAdType, revenueUSD: Double, currency: String) {
        let params: [AppEvents.ParameterName: Any] = [
            .currency: currency,
        ]

        AppEvents.shared.logEvent(
            .adImpression,
            valueToSum: revenueUSD,
            parameters: params
        )

        debugPrint("📘 [FacebookManager] AD_IMPRESSION logged: \(adType.rawValue) - \(revenueUSD) \(currency)")
    }
}
