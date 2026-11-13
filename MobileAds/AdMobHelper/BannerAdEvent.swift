//
//  BannerAdEvent.swift
//  MobileAds
//

import Foundation

/// One event of one `BannerAdView` (or `BannerAdSwiftUI`), delivered on the main thread to the
/// view's `onEvent` handler. Every case maps to a real Google Mobile Ads signal; nothing is
/// inferred from timers or layout.
///
/// Collapsible banners: the SDK has no expand or collapse callback. It exposes only
/// `BannerView.isCollapsible` (whether the last loaded ad is collapsible) and documents that a
/// collapsible ad shows its expanded overlay as soon as it is in the view hierarchy — which is
/// where `BannerAdView` loads it. `.didShowCollapsibleExpanded` is built from exactly that. There
/// is no SDK signal for "the user collapsed the overlay"; the closest real signals are the
/// click-time screen callbacks below, which the SDK documents for full-screen content opened by
/// the ad, not for the collapse button.
public enum BannerAdEvent: Equatable {
    /// `bannerViewDidReceiveAd`, or a banner served from the 1-hour cache (already loaded).
    case didLoad
    /// `bannerView(_:didFailToReceiveAdWithError:)`, with the SDK error.
    case didFailToLoad(NSError)
    /// `bannerViewDidRecordImpression`.
    case didRecordImpression
    /// `bannerViewDidRecordClick`.
    case didRecordClick
    /// A freshly loaded ad reported `isCollapsible == true`: the SDK is showing it expanded.
    /// Sent right after `.didLoad`. Never sent for a non-collapsible request.
    case didShowCollapsibleExpanded
    /// `bannerViewWillPresentScreen` — the ad is about to present full-screen content.
    case willPresentScreen
    /// `bannerViewWillDismissScreen`.
    case willDismissScreen
    /// `bannerViewDidDismissScreen`.
    case didDismissScreen
}
