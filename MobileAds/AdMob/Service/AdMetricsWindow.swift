//
//  AdMetricsWindow.swift
//  MobileAds
//
//  Created by Claude on 11/3/26.
//

import UIKit

/// Ad Metrics Monitor — displays ad lifecycle metrics as a debug overlay.
///
/// ## Setup (2 steps):
///
/// **Step 1** — Enable in AppDelegate (pass your app's window):
/// ```swift
/// #if DEBUG
/// AdMetricsWindow.shared.enable(in: window)
/// #endif
/// ```
///
/// **Step 2** — Forward shake events (add to your root ViewController or BaseViewController):
/// ```swift
/// override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
///     super.motionEnded(motion, with: event)
///     AdMetricsWindow.shared.handleMotion(motion)
/// }
/// ```
///
/// That's it! Shake device (⌘+Ctrl+Z in Simulator) to toggle the monitor.
@MainActor
public final class AdMetricsWindow {

    // MARK: - Singleton

    public static let shared = AdMetricsWindow()

    // MARK: - State

    private weak var hostWindow: UIWindow?
    private var monitorView: AdMetricsMonitorView?
    private var isMonitorVisible = false
    private var isEnabled = false

    private init() {}

    // MARK: - Public API

    /// Enable the ad metrics monitor.
    /// - Parameter window: Your app's main window (from SceneDelegate or AppDelegate)
    public func enable(in window: UIWindow?) {
        guard !isEnabled else { return }
        guard let window = window else {
            debugPrint("[ADM] ⚠️ enable() called with nil window")
            return
        }

        isEnabled = true
        hostWindow = window
        debugPrint("[ADM] ✅ Monitor enabled on window: \(window)")
    }

    /// Disable the monitor
    public func disable() {
        hideMonitor()
        isEnabled = false
        hostWindow = nil
        debugPrint("[ADM] Monitor disabled")
    }

    /// Forward shake events to the monitor. Call from your ViewController's motionEnded.
    public func handleMotion(_ motion: UIEvent.EventSubtype) {
        guard isEnabled else { return }
        debugPrint("[ADM] handleMotion called, isShake: \(motion == .motionShake)")
        if motion == .motionShake {
            toggleMonitor()
        }
    }

    /// For testing: show the monitor without shake
    public func test() {
        debugPrint("[ADM] test() — showing monitor")
        showMonitor()
    }

    // MARK: - Toggle

    private func toggleMonitor() {
        if isMonitorVisible {
            hideMonitor()
        } else {
            showMonitor()
        }
    }

    private func showMonitor() {
        guard !isMonitorVisible else { return }

        // Find the active visible key window (hostWindow may still be hidden if enable() was called early)
        let activeWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? hostWindow

        guard let window = activeWindow else {
            debugPrint("[ADM] ⚠️ No visible window found")
            return
        }

        let monitor = AdMetricsMonitorView(frame: window.bounds)
        monitor.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        monitor.alpha = 0
        monitor.onClose = { [weak self] in
            self?.hideMonitor()
        }

        window.addSubview(monitor)
        monitorView = monitor

        UIView.animate(withDuration: 0.25) {
            monitor.alpha = 1
        }

        isMonitorVisible = true
        debugPrint("[ADM] Monitor shown on window: \(window), isHidden: \(window.isHidden)")
    }

    private func hideMonitor() {
        guard isMonitorVisible, let monitor = monitorView else { return }

        UIView.animate(withDuration: 0.2, animations: {
            monitor.alpha = 0
        }) { _ in
            monitor.removeFromSuperview()
            self.monitorView = nil
        }

        isMonitorVisible = false
        debugPrint("[ADM] Monitor hidden")
    }
}
