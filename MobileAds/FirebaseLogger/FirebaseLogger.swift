//
//  FirebaseLogger.swift
//  MobileAds
//
//  Created by Claude on 13/12/2024.
//

import Foundation
import FirebaseAnalytics

/// Main Firebase Analytics Logger
/// Usage from app:
/// ```
/// FirebaseLogger.shared.logEvent(.appOpen)
/// FirebaseLogger.shared.logEvent(.purchaseSuccess, params: [.productId: "premium_yearly"])
/// ```
public final class FirebaseLogger {

    // MARK: - Singleton
    public static let shared = FirebaseLogger()

    // MARK: - Properties
    public var isDebugMode: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    // MARK: - Init
    private init() {}

    // MARK: - Public Methods

    /// Log an analytics event
    /// - Parameters:
    ///   - event: The event to log
    ///   - params: Optional parameters dictionary
    public func logEvent(_ event: AnalyticsEvent, params: [LogParameter: Any]? = nil) {
        let eventName = event.rawValue
        let parameters = params?.reduce(into: [String: Any]()) { result, pair in
            result[pair.key.rawValue] = pair.value
        }

        // Debug print
        if isDebugMode {
            printDebugLog(event: eventName, params: parameters)
        }

        // Send to Firebase
        Analytics.logEvent(eventName, parameters: parameters)
    }

    /// Set user property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: Property value
    public func setUserProperty(key: String, value: String?) {
        if isDebugMode {
            print("🔥 [UserProperty] \(key) = \(value ?? "nil")")
        }
        Analytics.setUserProperty(value, forName: key)
    }

    /// Set premium status user property
    /// - Parameter isPremium: Whether user is premium
    public func setUserPremiumStatus(_ isPremium: Bool) {
        setUserProperty(key: "is_premium", value: isPremium ? "true" : "false")
    }

    // MARK: - Private Methods

    private func printDebugLog(event: String, params: [String: Any]?) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("🔥 [\(timestamp)] \(event)")

        if let params = params, !params.isEmpty {
            print("   📊 Parameters:")
            params.forEach { key, value in
                print("      • \(key): \(value)")
            }
        }
    }
}
