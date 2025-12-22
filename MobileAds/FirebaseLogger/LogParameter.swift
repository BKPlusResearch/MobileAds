//
//  LogParameter.swift
//  MobileAds
//
//  Created by Claude on 13/12/2024.
//

import Foundation

/// Analytics event parameter keys
/// Extend this struct in your app for app-specific parameters
public struct LogParameter: RawRepresentable, Equatable, Hashable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // MARK: - Common Parameters
    // Ad Revenue
    public static let adPlatform = LogParameter(rawValue: "ad_platform")
    public static let currency = LogParameter(rawValue: "currency")
    public static let value = LogParameter(rawValue: "value")
}
