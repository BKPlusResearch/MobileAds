//
//  AnalyticsConfig.swift
//  MobileAds
//

import Foundation

/// App-wide configuration for the standard tracking events (`{app}_{screen}_{action}`).
///
/// Set once at launch, before any screen is entered:
/// ```swift
/// AnalyticsConfig.appCode = "ios099"
/// ```
/// While unset, no standard event is sent and DEBUG builds hit an `assertionFailure`.
public enum AnalyticsConfig {
    /// App code used as the event-name prefix, for example `"ios099"`.
    /// Read and written from the main thread.
    public static var appCode: String?
}
