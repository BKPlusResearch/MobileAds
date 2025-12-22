//
//  ADJustManager.swift
//  MobileAds
//
//  Created by shjn on 22/12/25.
//

import Foundation
import AdjustSdk
import GoogleMobileAds

// MARK: - Configuration

public struct AppADJustConfig {
    public let impressionToken: String?

    public init(impressionToken: String?) {
        self.impressionToken = impressionToken
    }
}

// MARK: - Ad Type

public enum ADJAdType: String {
    case interstitial
    case appOpen
    case native
    case banner
    case reward
}

// MARK: - ADJust Manager

public final class ADJustManager {
    public static let shared = ADJustManager()

    private var adjConfig: AppADJustConfig?

    private init() {}

    // MARK: - Configuration

    /// Configure ADJustManager with impression token
    /// - Parameter config: AppADJustConfig containing impression token
    public func configure(with config: AppADJustConfig) {
        self.adjConfig = config
        debugPrint("✅ [ADJustManager] Configured with impression token: \(config.impressionToken ?? "nil")")
    }

    // MARK: - Public Methods

    /// Log ad impression with revenue tracking
    /// - Parameters:
    ///   - adType: Type of ad (interstitial, appOpen, native, banner, reward)
    ///   - adValue: GADAdValue from ad callback
    public func logRevenue(adType: ADJAdType, adValue: AdValue) {
        let valueMicros = Double(truncating: adValue.value)
        let currency = adValue.currencyCode
        let revenueUSD = valueMicros

        // Track to Adjust ad revenue
        trackAdRevenue(adType: adType, revenueUSD: revenueUSD, currency: currency)

        // Track to Adjust event
        trackAdjustEvent(revenueUSD: revenueUSD, currency: currency)

        // Track to Firebase Analytics
        Task { @MainActor in
            logFirebaseRevenue(value: revenueUSD)
        }
    }

    // MARK: - Private Methods

    /// Track ad revenue to Adjust SDK
    private func trackAdRevenue(adType: ADJAdType, revenueUSD: Double, currency: String) {
        debugPrint("💰 [AdRevenue] \(#function) \(adType.rawValue) - \(revenueUSD) \(currency)")

        let adjustAdRevenue = ADJAdRevenue(source: "admob_sdk")
        adjustAdRevenue?.setRevenue(revenueUSD, currency: currency)
        adjustAdRevenue?.setAdImpressionsCount(1)
        adjustAdRevenue?.setAdRevenueNetwork("AdMob")
        adjustAdRevenue?.setAdRevenueUnit(adType.rawValue)
        adjustAdRevenue?.setAdRevenuePlacement("default")

        if let adjustAdRevenue = adjustAdRevenue {
            Adjust.trackAdRevenue(adjustAdRevenue)
        }
    }

    /// Track event to Adjust with impression token
    private func trackAdjustEvent(revenueUSD: Double, currency: String) {
        debugPrint("💰 [AdRevenue] \(#function) - \(revenueUSD) \(currency)")

        if let token = adjConfig?.impressionToken {
            let event = ADJEvent(eventToken: token)
            event?.setRevenue(revenueUSD, currency: currency)
            Adjust.trackEvent(event)
        } else {
            debugPrint("⚠️ [AdRevenue] Impression token not configured")
        }
    }

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
