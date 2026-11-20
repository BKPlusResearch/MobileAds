//
//  BannerAdSize.swift
//  MobileAds
//

@preconcurrency import GoogleMobileAds
import UIKit

/// Standard AdMob banner sizes a `BannerAdView` can request. A standard size gets creatives made
/// for exactly that box, so the ad is never stretched or cropped; on a screen wider than the ad it
/// sits centered in its view. Size the view's height with `height`.
public enum BannerAdSize: Sendable {
    /// 320 x 50 (`AdSizeBanner`).
    case small
    /// 320 x 100 (`AdSizeLargeBanner`).
    case large

    /// The Google Mobile Ads size requested for this case.
    public var adSize: AdSize {
        switch self {
        case .small: return AdSizeBanner
        case .large: return AdSizeLargeBanner
        }
    }

    /// The ad's height in points: the height its view must have.
    public var height: CGFloat { adSize.size.height }
}
