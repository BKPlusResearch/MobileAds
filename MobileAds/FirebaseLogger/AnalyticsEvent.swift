//
//  AnalyticsEvent.swift
//  MobileAds
//
//  Created by Claude on 13/12/2024.
//

import Foundation

/// Analytics event names
/// Extend this struct in your app for app-specific events
public struct AnalyticsEvent: RawRepresentable, Equatable, Hashable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // MARK: - Common Events (Available for all apps)

    // Ad Revenue
    public static let adImpression = AnalyticsEvent(rawValue: "ad_impression_ios")
}
