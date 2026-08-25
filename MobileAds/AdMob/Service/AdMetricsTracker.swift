//
//  AdMetricsTracker.swift
//  MobileAds
//
//  Created by Claude on 11/3/26.
//

import Foundation

/// In-memory, per-session tracker for ad lifecycle metrics.
///
/// Usage:
/// ```swift
/// AdMetricsTracker.shared.trackRequest(adUnit: "ca-app-pub-xxx", adType: .interstitial)
/// AdMetricsTracker.shared.trackLoaded(adUnit: "ca-app-pub-xxx")
/// ```
@MainActor
public final class AdMetricsTracker {

    // MARK: - Singleton

    public static let shared = AdMetricsTracker()

    // MARK: - Storage

    /// Metrics keyed by ad unit ID string
    private var metrics: [String: AdMetrics] = [:]

    /// Ordered list of ad unit keys (insertion order for display)
    private var orderedKeys: [String] = []

    private init() {}

    // MARK: - Track Events

    /// Track an ad request (load called)
    public func trackRequest(adUnit: String, adType: AdType) {
        ensureEntry(adUnit: adUnit, adType: adType)
        metrics[adUnit]?.incrementRequest()
        debugPrint("📊 [AdMetrics] REQUEST  \(adType.rawValue) — \(adUnit) (total: \(metrics[adUnit]?.requestCount ?? 0))")
    }

    /// Track a successful ad load
    public func trackLoaded(adUnit: String) {
        metrics[adUnit]?.incrementLoaded()
        debugPrint("📊 [AdMetrics] LOADED   \(metrics[adUnit]?.adType.rawValue ?? "?") — \(adUnit) (total: \(metrics[adUnit]?.loadedCount ?? 0))")
    }

    /// Track a failed ad load
    public func trackLoadFailed(adUnit: String) {
        metrics[adUnit]?.incrementLoadFailed()
        debugPrint("📊 [AdMetrics] FAILED   \(metrics[adUnit]?.adType.rawValue ?? "?") — \(adUnit) (total: \(metrics[adUnit]?.loadFailedCount ?? 0))")
    }

    /// Track ad presented to user
    public func trackShow(adUnit: String) {
        metrics[adUnit]?.incrementShow()
        debugPrint("📊 [AdMetrics] SHOW     \(metrics[adUnit]?.adType.rawValue ?? "?") — \(adUnit) (total: \(metrics[adUnit]?.showCount ?? 0))")
    }

    /// Track ad impression recorded
    public func trackImpression(adUnit: String) {
        metrics[adUnit]?.incrementImpression()
        debugPrint("📊 [AdMetrics] IMPRESS  \(metrics[adUnit]?.adType.rawValue ?? "?") — \(adUnit) (total: \(metrics[adUnit]?.impressionCount ?? 0))")
    }

    /// Track ad click recorded
    public func trackClick(adUnit: String) {
        metrics[adUnit]?.incrementClick()
        debugPrint("📊 [AdMetrics] CLICK    \(metrics[adUnit]?.adType.rawValue ?? "?") — \(adUnit) (total: \(metrics[adUnit]?.clickCount ?? 0))")
    }

    // MARK: - Query

    /// Returns all metrics in insertion order
    public func getAllMetrics() -> [AdMetrics] {
        return orderedKeys.compactMap { metrics[$0] }
    }

    /// Returns metrics for a specific ad unit
    public func getMetrics(for adUnit: String) -> AdMetrics? {
        return metrics[adUnit]
    }

    /// Reset all metrics
    public func reset() {
        metrics.removeAll()
        orderedKeys.removeAll()
        debugPrint("📊 [AdMetrics] All metrics reset")
    }

    // MARK: - Private

    private func ensureEntry(adUnit: String, adType: AdType) {
        if metrics[adUnit] == nil {
            metrics[adUnit] = AdMetrics(adUnit: adUnit, adType: adType)
            orderedKeys.append(adUnit)
        }
    }
}
