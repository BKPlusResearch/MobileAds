//
//  AdMetrics.swift
//  MobileAds
//
//  Created by Claude on 11/3/26.
//

import Foundation

/// Tracks lifecycle metrics for a single ad unit within the current app session.
///
/// Mirrors the key columns from the AdMob dashboard:
/// Requests | Match Rate | Show Rate | Impressions | CTR | Clicks
public struct AdMetrics {

    // MARK: - Identity

    /// The ad unit ID string (e.g. "ca-app-pub-xxx/yyy")
    public let adUnit: String

    /// The ad type (interstitial, appOpen, native, banner, reward)
    public let adType: AdType

    // MARK: - Counters

    /// Number of times an ad was requested (load called)
    public private(set) var requestCount: Int = 0

    /// Number of times an ad was loaded successfully (match)
    public private(set) var loadedCount: Int = 0

    /// Number of times an ad failed to load
    public private(set) var loadFailedCount: Int = 0

    /// Number of times an ad was presented to the user
    public private(set) var showCount: Int = 0

    /// Number of recorded impressions
    public private(set) var impressionCount: Int = 0

    /// Number of recorded clicks
    public private(set) var clickCount: Int = 0

    // MARK: - Computed Rates

    /// loadedCount / requestCount (0…100%)
    public var matchRate: Double {
        guard requestCount > 0 else { return 0 }
        return Double(loadedCount) / Double(requestCount) * 100
    }

    /// impressionCount / loadedCount (0…100%)
    public var showRate: Double {
        guard loadedCount > 0 else { return 0 }
        return Double(impressionCount) / Double(loadedCount) * 100
    }

    /// clickCount / impressionCount (0…100%)
    public var ctr: Double {
        guard impressionCount > 0 else { return 0 }
        return Double(clickCount) / Double(impressionCount) * 100
    }

    // MARK: - Init

    public init(adUnit: String, adType: AdType) {
        self.adUnit = adUnit
        self.adType = adType
    }

    // MARK: - Mutations

    mutating func incrementRequest()   { requestCount += 1 }
    mutating func incrementLoaded()    { loadedCount += 1 }
    mutating func incrementLoadFailed(){ loadFailedCount += 1 }
    mutating func incrementShow()      { showCount += 1 }
    mutating func incrementImpression(){ impressionCount += 1 }
    mutating func incrementClick()     { clickCount += 1 }
}
