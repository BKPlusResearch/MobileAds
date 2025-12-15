//
//  AnalyticsEvent.swift
//  MobileAds
//
//  Created by Claude on 13/12/2024.
//

import Foundation

/// Analytics event names
/// Extend this struct in your app for app-specific events
@available(iOS 15.0, *)
public struct AnalyticsEvent: RawRepresentable, Equatable, Hashable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // MARK: - Common Events (Available for all apps)

    // App Lifecycle
    public static let appOpen = AnalyticsEvent(rawValue: "app_open")

    // Screen Tracking
    public static let screenView = AnalyticsEvent(rawValue: "screen_view")

    // Errors
    public static let error = AnalyticsEvent(rawValue: "app_error")
}
