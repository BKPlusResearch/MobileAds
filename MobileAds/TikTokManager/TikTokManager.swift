//
//  TikTokManager.swift
//  MobileAds
//
//  Created by Claude on 29/01/2026.
//

import Foundation
import TikTokBusinessSDK
import AppTrackingTransparency
import GoogleMobileAds

// MARK: - TikTok Ad Revenue Info

/// Detailed ad revenue information for TikTok tracking
public struct TikTokAdRevenueInfo {
    public let value: NSDecimalNumber
    public let currencyCode: String
    public let precision: AdValuePrecision
    public let adUnitId: String
    public let adSourceName: String?
    public let adSourceId: String?
    public let adSourceInstanceName: String?
    public let adSourceInstanceId: String?
    public let mediationGroupName: String?
    public let mediationABTestName: String?
    public let mediationABTestVariant: String?

    public init(
        value: NSDecimalNumber,
        currencyCode: String,
        precision: AdValuePrecision,
        adUnitId: String,
        adSourceName: String? = nil,
        adSourceId: String? = nil,
        adSourceInstanceName: String? = nil,
        adSourceInstanceId: String? = nil,
        mediationGroupName: String? = nil,
        mediationABTestName: String? = nil,
        mediationABTestVariant: String? = nil
    ) {
        self.value = value
        self.currencyCode = currencyCode
        self.precision = precision
        self.adUnitId = adUnitId
        self.adSourceName = adSourceName
        self.adSourceId = adSourceId
        self.adSourceInstanceName = adSourceInstanceName
        self.adSourceInstanceId = adSourceInstanceId
        self.mediationGroupName = mediationGroupName
        self.mediationABTestName = mediationABTestName
        self.mediationABTestVariant = mediationABTestVariant
    }
}

// MARK: - TikTok Manager

/// Singleton manager for TikTok Business SDK integration
/// Usage:
/// ```
/// let config = TikTokAppConfig(appId: "YOUR_APP_ID", tiktokAppId: "YOUR_TIKTOK_APP_ID", debugMode: true)
/// TikTokManager.shared.configure(with: config)
/// TikTokManager.shared.trackAppLaunch()
/// ```
public final class TikTokManager {

    // MARK: - Singleton

    public static let shared = TikTokManager()

    // MARK: - Properties

    private var appConfig: TikTokAppConfig?
    private var isConfigured: Bool = false

    // MARK: - Init

    private init() {}

    // MARK: - Configuration

    /// Configure TikTok Business SDK
    /// - Parameter config: TikTok configuration
    public func configure(with config: TikTokAppConfig) {
        self.appConfig = config

        // Create TikTok SDK config using the SDK's TikTokConfig class
        guard let sdkConfig = TikTokBusinessSDK.TikTokConfig(appId: config.appId, tiktokAppId: config.tiktokAppId ?? "") else {
            debugPrint("❌ [TikTokManager] Failed to create TikTok config")
            return
        }

        // Set app secret if provided (for S2S verification)
        if let appSecret = config.appSecret, !appSecret.isEmpty {
            sdkConfig.setAppSecret(appSecret)
            debugPrint("🔐 [TikTokManager] App Secret configured")
        }

        // Set log level based on debug mode
        if config.debugMode {
            sdkConfig.setLogLevel(TikTokLogLevelDebug)
            sdkConfig.enableDebugMode()
        } else {
            sdkConfig.setLogLevel(TikTokLogLevelSuppress)
        }

        // Initialize SDK
        TikTokBusiness.initializeSdk(sdkConfig) { [weak self] success, error in
            if success {
                self?.isConfigured = true
                self?.debugPrint("✅ [TikTokManager] SDK initialized successfully")
            } else {
                self?.debugPrint("❌ [TikTokManager] SDK initialization failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }

        debugPrint("✅ [TikTokManager] Configured with App ID: \(config.appId), TikTok App ID: \(config.tiktokAppId ?? "nil")")
    }

    // MARK: - ATT Support

    /// Request App Tracking Transparency authorization
    /// - Parameter completion: Completion handler with authorization status
    @available(iOS 14, *)
    public func requestTrackingAuthorization(completion: ((ATTrackingManager.AuthorizationStatus) -> Void)? = nil) {
        ATTrackingManager.requestTrackingAuthorization { status in
            switch status {
            case .authorized:
                self.debugPrint("✅ [TikTokManager] ATT authorized")
            case .denied:
                self.debugPrint("⚠️ [TikTokManager] ATT denied")
            case .notDetermined:
                self.debugPrint("⚠️ [TikTokManager] ATT not determined")
            case .restricted:
                self.debugPrint("⚠️ [TikTokManager] ATT restricted")
            @unknown default:
                self.debugPrint("⚠️ [TikTokManager] ATT unknown status")
            }
            completion?(status)
        }
    }

    // MARK: - Event Tracking

    /// Track a standard TikTok event
    /// - Parameters:
    ///   - eventType: Standard TikTok event type
    ///   - params: Optional event parameters
    public func trackEvent(_ eventType: TikTokEventType, params: [TikTokEventParam]? = nil) {
        let properties = convertParams(params)

        if let properties = properties {
            TikTokBusiness.trackEvent(eventType.rawValue, withProperties: properties)
        } else {
            TikTokBusiness.trackEvent(eventType.rawValue)
        }

        debugPrint("📊 [TikTokManager] Event tracked: \(eventType.rawValue)")

        if let properties = properties, !properties.isEmpty {
            debugPrint("   Parameters: \(properties)")
        }
    }

    /// Track a custom event
    /// - Parameters:
    ///   - eventName: Custom event name
    ///   - params: Optional event parameters
    public func trackCustomEvent(_ eventName: String, params: [TikTokEventParam]? = nil) {
        let properties = convertParams(params)

        if let properties = properties {
            TikTokBusiness.trackEvent(eventName, withProperties: properties)
        } else {
            TikTokBusiness.trackEvent(eventName)
        }

        debugPrint("📊 [TikTokManager] Custom event tracked: \(eventName)")

        if let properties = properties, !properties.isEmpty {
            debugPrint("   Parameters: \(properties)")
        }
    }

    // MARK: - Convenience Methods

    /// Track app launch event
    public func trackAppLaunch() {
        trackEvent(.launchApp)
    }

    /// Track user login event
    public func trackLogin() {
        trackEvent(.login)
    }

    /// Track user registration
    /// - Parameter method: Registration method (e.g., "email", "facebook", "google")
    public func trackRegistration(method: String) {
        trackEvent(.completeRegistration, params: [
            .registrationMethod(method)
        ])
    }

    /// Track content view
    /// - Parameters:
    ///   - contentId: Content identifier
    ///   - contentType: Content type
    ///   - contentName: Optional content name
    public func trackViewContent(contentId: String, contentType: String, contentName: String? = nil) {
        var params: [TikTokEventParam] = [
            .contentId(contentId),
            .contentType(contentType)
        ]

        if let contentName = contentName {
            params.append(.contentName(contentName))
        }

        trackEvent(.viewContent, params: params)
    }

    /// Track add to cart event
    /// - Parameters:
    ///   - productId: Product identifier
    ///   - price: Product price
    ///   - quantity: Quantity added
    ///   - currency: Currency code (default: "USD")
    public func trackAddToCart(productId: String, price: Double, quantity: Int = 1, currency: String = "USD") {
        trackEvent(.addToCart, params: [
            .productId(productId),
            .price(price),
            .quantity(quantity),
            .currency(currency),
            .value(price * Double(quantity))
        ])
    }

    /// Track purchase event
    /// - Parameters:
    ///   - productId: Product identifier
    ///   - price: Purchase price
    ///   - currency: Currency code (default: "USD")
    ///   - transactionId: Optional transaction identifier
    public func trackPurchase(productId: String, price: Double, currency: String = "USD", transactionId: String? = nil) {
        var params: [TikTokEventParam] = [
            .productId(productId),
            .value(price),
            .currency(currency)
        ]

        if let transactionId = transactionId {
            params.append(.transactionId(transactionId))
        }

        trackEvent(.purchase, params: params)
    }

    /// Track subscription event
    /// - Parameters:
    ///   - productId: Product identifier
    ///   - price: Subscription price
    ///   - currency: Currency code (default: "USD")
    public func trackSubscription(productId: String, price: Double, currency: String = "USD") {
        trackEvent(.subscribe, params: [
            .productId(productId),
            .value(price),
            .currency(currency)
        ])
    }

    /// Track ad revenue event (simple version)
    /// - Parameters:
    ///   - adType: Type of ad (e.g., "interstitial", "banner", "rewarded")
    ///   - revenueUSD: Revenue in USD
    ///   - adNetwork: Ad network name (default: "AdMob")
    public func trackAdRevenue(adType: ADJAdType, revenueUSD: Double, adNetwork: String = "AdMob") {
        // Build minimal ad revenue dictionary                                                                      
      let adRevenue: [String: Any] = [                                                                            
          "device_ad_mediation_platform": "admob_sdk",                                                            
          "value": revenueUSD,                                                                                    
          "currency": "USD",                                                                                      
          "ad_type": adType.rawValue  // Optional: để biết loại ad                                                
      ]                                                                                                           
                                                                                                                  
      // Use TikTokBaseEvent instead of trackEvent                                                                
      let adRevenueEvent = TikTokBaseEvent(                                                                       
          eventName: "InAppADImpr",                                                                               
          properties: adRevenue,                                                                                  
          eventId: nil                                                                                            
      )                                                                                                           
                                                                                                                  
      TikTokBusiness.trackTTEvent(adRevenueEvent)                                                                 
                                                                                                                  
      debugPrint("📊 [TikTokManager] Ad Revenue Event tracked: \(revenueUSD) USD")   
    }

    /// Track ad revenue event with detailed info (matches TikTok official documentation)
    /// - Parameters:
    ///   - adRevenueInfo: Detailed ad revenue information from GADAdValue
    ///   - eventId: Optional custom event ID
    public func trackAdRevenueEvent(_ adRevenueInfo: TikTokAdRevenueInfo, eventId: String? = nil) {
        // Build ad revenue dictionary matching TikTok's expected format
        var adRevenue: [String: Any] = [
            "device_ad_mediation_platform": "admob_sdk",
            "value": adRevenueInfo.value,
            "currency_code": adRevenueInfo.currencyCode,
            "precision": adRevenueInfo.precision.rawValue,
            "ad_unit_id": adRevenueInfo.adUnitId
        ]

        // Add optional parameters
        if let adSourceName = adRevenueInfo.adSourceName {
            adRevenue["ad_source_name"] = adSourceName
        }
        if let adSourceId = adRevenueInfo.adSourceId {
            adRevenue["ad_source_id"] = adSourceId
        }
        if let adSourceInstanceName = adRevenueInfo.adSourceInstanceName {
            adRevenue["ad_source_instance_name"] = adSourceInstanceName
        }
        if let adSourceInstanceId = adRevenueInfo.adSourceInstanceId {
            adRevenue["ad_source_instance_id"] = adSourceInstanceId
        }
        if let mediationGroupName = adRevenueInfo.mediationGroupName {
            adRevenue["mediation_group_name"] = mediationGroupName
        }
        if let mediationABTestName = adRevenueInfo.mediationABTestName {
            adRevenue["mediation_ab_test_name"] = mediationABTestName
        }
        if let mediationABTestVariant = adRevenueInfo.mediationABTestVariant {
            adRevenue["mediation_ab_test_variant"] = mediationABTestVariant
        }

        // Create TikTokBaseEvent for ad revenue
        let adRevenueEvent: TikTokBaseEvent
        if let eventId = eventId {
            adRevenueEvent = TikTokBaseEvent(eventName: "InAppADImpr", properties: adRevenue, eventId: eventId)
        } else {
            adRevenueEvent = TikTokBaseEvent(eventName: "InAppADImpr", properties: adRevenue, eventId: nil)
        }

        // Track the event
        TikTokBusiness.trackTTEvent(adRevenueEvent)

        debugPrint("📊 [TikTokManager] Ad Revenue Event tracked:")
        debugPrint("   Value: \(adRevenueInfo.value) \(adRevenueInfo.currencyCode)")
        debugPrint("   Ad Unit: \(adRevenueInfo.adUnitId)")
        if let adSourceName = adRevenueInfo.adSourceName {
            debugPrint("   Ad Source: \(adSourceName)")
        }
    }

    /// Track search event
    /// - Parameter query: Search query string
    public func trackSearch(query: String) {
        trackEvent(.search, params: [
            .query(query)
        ])
    }

    /// Track level achievement
    /// - Parameter level: Level number achieved
    public func trackAchieveLevel(_ level: Int) {
        trackEvent(.achieveLevel, params: [
            .level(level)
        ])
    }

    /// Track start trial event
    /// - Parameters:
    ///   - productId: Product identifier
    ///   - price: Trial price (usually 0)
    ///   - currency: Currency code (default: "USD")
    public func trackStartTrial(productId: String, price: Double = 0, currency: String = "USD") {
        trackEvent(.startTrial, params: [
            .productId(productId),
            .value(price),
            .currency(currency)
        ])
    }

    // MARK: - Private Methods

    /// Convert TikTokEventParam array to dictionary
    private func convertParams(_ params: [TikTokEventParam]?) -> [String: Any]? {
        guard let params = params, !params.isEmpty else {
            return nil
        }

        var dict: [String: Any] = [:]
        for param in params {
            dict[param.key] = param.value
        }
        return dict
    }

    /// Debug print helper
    private func debugPrint(_ message: String) {
        #if DEBUG
        print(message)
        #else
        if appConfig?.debugMode == true {
            print(message)
        }
        #endif
    }
}
