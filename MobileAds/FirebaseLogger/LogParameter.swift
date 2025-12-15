//
//  LogParameter.swift
//  MobileAds
//
//  Created by Claude on 13/12/2024.
//

import Foundation

/// Analytics event parameter keys
/// Extend this struct in your app for app-specific parameters
@available(iOS 15.0, *)
public struct LogParameter: RawRepresentable, Equatable, Hashable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // MARK: - Common Parameters

    // Screen & Navigation
    public static let screenName = LogParameter(rawValue: "screen_name")

    // Error Tracking
    public static let errorMessage = LogParameter(rawValue: "error_message")
    public static let errorContext = LogParameter(rawValue: "error_context")
}
