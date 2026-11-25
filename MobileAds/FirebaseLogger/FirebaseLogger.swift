//
//  FirebaseLogger.swift
//  MobileAds
//
//  Created by Claude on 13/12/2024.
//

import Foundation
import FirebaseAnalytics
import FirebaseCore

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
        let parameters = params?.reduce(into: [String: Any]()) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
        logEvent(name: event.rawValue, params: parameters)
    }

    /// Log an analytics event by raw name (used by the standard `{app}_{screen}_{action}` events)
    /// - Parameters:
    ///   - name: Event name
    ///   - params: Optional parameters dictionary keyed by parameter name
    public func logEvent(name: String, params: [String: Any]?) {
        // Debug print
        if isDebugMode {
            printDebugLog(event: name, params: params)
        }

        // Send to Firebase
        Analytics.logEvent(name, parameters: params)
    }

    /// Set user property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: Property value
    public func setUserProperty(key: String, value: String?) {
        if isDebugMode {
            debugPrint("🔥 [UserProperty] \(key) = \(value ?? "nil")")
        }
        Analytics.setUserProperty(value, forName: key)
    }

    /// Set premium status user property
    /// - Parameter isPremium: Whether user is premium
    public func setUserPremiumStatus(_ isPremium: Bool) {
        setUserProperty(key: "is_premium", value: isPremium ? "true" : "false")
    }

    /// Set the user properties every app must carry: `is_premium`, `ab_branch`, and
    /// `first_open_version` (set once, on the first call, from CFBundleShortVersionString).
    /// Call at launch and whenever premium status or the A/B branch changes.
    public func setStandardUserProperties(isPremium: Bool, abBranch: String?) {
        setUserPremiumStatus(isPremium)
        setUserProperty(key: "ab_branch", value: abBranch)
        setFirstOpenVersionIfNeeded()
    }

    // MARK: - Private Methods

    private static let firstOpenVersionFlagKey = "MobileAds.firstOpenVersionSet"

    private func setFirstOpenVersionIfNeeded() {
        let defaults = UserDefaults.standard
        // Without a configured Firebase app the property is dropped, so do not burn the one-shot flag.
        guard FirebaseApp.app() != nil,
              !defaults.bool(forKey: Self.firstOpenVersionFlagKey),
              let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        else { return }
        setUserProperty(key: "first_open_version", value: version)
        defaults.set(true, forKey: Self.firstOpenVersionFlagKey)
    }

    private func printDebugLog(event: String, params: [String: Any]?) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugPrint("🔥 [\(timestamp)] \(event)")

        if let params = params, !params.isEmpty {
            debugPrint("   📊 Parameters:")
            params.forEach { key, value in
                debugPrint("      • \(key): \(value)")
            }
        }
    }
}
