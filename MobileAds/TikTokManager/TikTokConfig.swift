//
//  TikTokConfig.swift
//  MobileAds
//
//  Created by Claude on 29/01/2026.
//

import Foundation

/// Configuration for TikTok Business SDK
public struct TikTokAppConfig {
    /// TikTok App ID from TikTok Ads Manager
    public let appId: String

    /// Optional TikTok App ID (different from business app id)
    public let tiktokAppId: String?

    /// Enable debug mode for verbose logging
    public let debugMode: Bool

    /// Enable App Tracking Transparency request
    public let enableATT: Bool

    /// Initialize TikTok configuration
    /// - Parameters:
    ///   - appId: TikTok App ID from TikTok Ads Manager
    ///   - tiktokAppId: Optional TikTok App ID
    ///   - debugMode: Enable debug mode (default: false)
    ///   - enableATT: Enable ATT request (default: true)
    public init(
        appId: String,
        tiktokAppId: String? = nil,
        debugMode: Bool = false,
        enableATT: Bool = true
    ) {
        self.appId = appId
        self.tiktokAppId = tiktokAppId
        self.debugMode = debugMode
        self.enableATT = enableATT
    }
}
