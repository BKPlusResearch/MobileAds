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
    public let token: String?

    public init(impressionToken: String?, token: String?) {
        self.impressionToken = impressionToken
        self.token = token
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

    /// Initialize Adjust SDK and configure ADJustManager
    /// - Parameters:
    ///   - config: AppADJustConfig with app token and impression token
    ///   - environment: Adjust environment (sandbox or production)
    ///   - delegate: Optional AdjustDelegate for callbacks
    public func configure(with config: AppADJustConfig, delegate: AdjustDelegate? = nil) {
        // Store config first
        self.adjConfig = config

        // If token provided, initialize Adjust SDK
        let environment: String
#if DEBUG
        environment = ADJEnvironmentSandbox
#else
        environment = ADJEnvironmentProduction
#endif
        if let token = config.token {
            guard let adjustConfig = ADJConfig(appToken: token, environment: environment) else {
                debugPrint("❌ [ADJustManager] Failed to create Adjust config")
                return
            }

            // Set delegate if provided
            if let delegate = delegate as? NSObject & AdjustDelegate {
                adjustConfig.delegate = delegate
            }

            // Set log level based on environment
            #if DEBUG
            adjustConfig.logLevel = ADJLogLevel.verbose
            #else
            adjustConfig.logLevel = ADJLogLevel.warn
            #endif

            // Initialize Adjust SDK
            Adjust.initSdk(adjustConfig)
            debugPrint("✅ [ADJustManager] Adjust SDK initialized with token: \(token) in \(environment) environment")
        }

        // Log configuration status
        debugPrint("✅ [ADJustManager] Configured for ad revenue tracking with impression token: \(config.impressionToken ?? "nil")")
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

// MARK: - Additional Public Methods

extension ADJustManager {

    /// Track custom event to Adjust
    /// - Parameters:
    ///   - eventToken: Event token from Adjust dashboard
    ///   - revenue: Optional revenue value
    ///   - currency: Currency code (default: USD)
    public func trackEvent(_ eventToken: String, revenue: Double? = nil, currency: String = "USD") {
        guard let event = ADJEvent(eventToken: eventToken) else {
            debugPrint("❌ [ADJustManager] Failed to create event with token: \(eventToken)")
            return
        }

        if let revenue = revenue {
            event.setRevenue(revenue, currency: currency)
        }

        Adjust.trackEvent(event)
        debugPrint("✅ [ADJustManager] Event tracked: \(eventToken)")
    }

    /// Track purchase event to Adjust
    /// - Parameters:
    ///   - transactionId: Transaction/Receipt ID
    ///   - productId: Product identifier
    ///   - price: Purchase price
    ///   - currency: Currency code
    public func trackPurchase(transactionId: String, productId: String, price: Double, currency: String) {
        // Create purchase event if you have purchase event token
        // For now, just log the info
        debugPrint("💰 [ADJustManager] Purchase tracked:")
        debugPrint("  • Transaction ID: \(transactionId)")
        debugPrint("  • Product ID: \(productId)")
        debugPrint("  • Price: \(price) \(currency)")
    }
}
