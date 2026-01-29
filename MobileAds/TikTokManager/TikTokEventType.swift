//
//  TikTokEventType.swift
//  MobileAds
//
//  Created by Claude on 29/01/2026.
//

import Foundation

// MARK: - TikTok Event Types

/// Standard TikTok event types for analytics tracking
public enum TikTokEventType: String {
    // App Lifecycle Events
    case launchApp = "LaunchAPP"
    case installApp = "InstallApp"

    // User Events
    case completeRegistration = "CompleteRegistration"
    case login = "Login"
    case logout = "Logout"

    // Content Events
    case viewContent = "ViewContent"
    case search = "Search"
    case addToWishlist = "AddToWishlist"
    case addToCart = "AddToCart"
    case initiateCheckout = "InitiateCheckout"
    case addPaymentInfo = "AddPaymentInfo"
    case completePayment = "CompletePayment"
    case placeAnOrder = "PlaceAnOrder"

    // Purchase Events
    case purchase = "Purchase"
    case subscribe = "Subscribe"
    case startTrial = "StartTrial"

    // Ad Events
    case inAppAdImpression = "InAppADImpr"
    case inAppAdClick = "InAppADClick"

    // Engagement Events
    case achieveLevel = "AchieveLevel"
    case unlockAchievement = "UnlockAchievement"
    case createGroup = "CreateGroup"
    case joinGroup = "JoinGroup"
    case createRole = "CreateRole"
    case spendCredits = "SpendCredits"
    case contact = "Contact"
    case share = "Share"
    case rate = "Rate"
}

// MARK: - TikTok Event Parameters

/// Parameters for TikTok events
public struct TikTokEventParam {
    public let key: String
    public let value: Any

    public init(key: String, value: Any) {
        self.key = key
        self.value = value
    }
}

// MARK: - Standard Parameter Keys

public extension TikTokEventParam {
    // Content Parameters
    static func contentId(_ value: String) -> TikTokEventParam {
        TikTokEventParam(key: "content_id", value: value)
    }

    static func contentType(_ value: String) -> TikTokEventParam {
        TikTokEventParam(key: "content_type", value: value)
    }

    static func contentName(_ value: String) -> TikTokEventParam {
        TikTokEventParam(key: "content_name", value: value)
    }

    static func contentCategory(_ value: String) -> TikTokEventParam {
        TikTokEventParam(key: "content_category", value: value)
    }

    // Purchase Parameters
    static func value(_ value: Double) -> TikTokEventParam {
        TikTokEventParam(key: "value", value: value)
    }

    static func currency(_ value: String) -> TikTokEventParam {
        TikTokEventParam(key: "currency", value: value)
    }

    static func quantity(_ value: Int) -> TikTokEventParam {
        TikTokEventParam(key: "quantity", value: value)
    }

    static func transactionId(_ value: String) -> TikTokEventParam {
        TikTokEventParam(key: "order_id", value: value)
    }

    static func productId(_ value: String) -> TikTokEventParam {
        TikTokEventParam(key: "product_id", value: value)
    }

    static func price(_ value: Double) -> TikTokEventParam {
        TikTokEventParam(key: "price", value: value)
    }

    // User Parameters
    static func registrationMethod(_ value: String) -> TikTokEventParam {
        TikTokEventParam(key: "registration_method", value: value)
    }

    // Ad Parameters
    static func adType(_ value: String) -> TikTokEventParam {
        TikTokEventParam(key: "ad_type", value: value)
    }

    static func adNetwork(_ value: String) -> TikTokEventParam {
        TikTokEventParam(key: "network_name", value: value)
    }

    // Level/Achievement Parameters
    static func level(_ value: Int) -> TikTokEventParam {
        TikTokEventParam(key: "level", value: value)
    }

    static func achievementId(_ value: String) -> TikTokEventParam {
        TikTokEventParam(key: "achievement_id", value: value)
    }

    // Search Parameters
    static func query(_ value: String) -> TikTokEventParam {
        TikTokEventParam(key: "query", value: value)
    }

    // Custom Parameter
    static func custom(_ key: String, _ value: Any) -> TikTokEventParam {
        TikTokEventParam(key: key, value: value)
    }
}
