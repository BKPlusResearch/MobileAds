//
//  ScreenTracker.swift
//  MobileAds
//

import Foundation

/// Tracks the screen the user is on and logs standard events `{app}_{screen}_{action}`.
///
/// Main-thread only. UIKit: call `enter` in `viewDidAppear` and `leave` in
/// `viewDidDisappear`. SwiftUI: use `.trackedScreen("home")`.
/// The stack lets `current` fall back to the screen underneath when a sheet closes.
public enum ScreenTracker {
    public static let unknownScreen = "unknown"

    private static var stack: [String] = []

    // Full-screen ad bookkeeping. A full-screen ad makes the covered screen disappear and
    // reappear (viewDidDisappear/viewDidAppear, or onDisappear/onAppear); that pair must not
    // empty the stack nor log a second `_view`.
    private static var adActive = false
    private static var coveredScreen: String?
    private static var pendingReappear: String?

    /// Top of the stack, or `"unknown"` when no screen has been entered.
    public static var current: String { stack.last ?? unknownScreen }

    /// Pushes `screen` and logs `{app}_{screen}_view`.
    /// The screen that is already on top is not pushed twice (a cancelled UIKit back-swipe calls
    /// `viewDidAppear` again without `viewDidDisappear`), but `_view` is still logged.
    /// The reappearance of a screen covered by a full-screen ad is ignored. Any other `enter`
    /// while a leave is deferred means the covered screen is gone, so the deferred leave is applied first.
    public static func enter(_ screen: String) {
        enter(screen, params: nil)
    }

    /// Same as `enter(_:)`, with `params` attached to the `{app}_{screen}_view` event.
    public static func enter(_ screen: String, params: [String: Any]?) {
        assertMainThread()
        if pendingReappear == screen && stack.last == screen {
            pendingReappear = nil
            return
        }
        applyPendingLeave()
        if stack.last != screen {
            stack.append(screen)
        }
        log(screen: screen, action: "view", params: params, fromPod: false)
    }

    /// Removes `screen` from the stack: the top entry, or the matching entry when it is
    /// not on top (the last match wins). No-op when absent.
    /// While a full-screen ad covers `screen`, the removal is deferred until the next `enter`,
    /// `leave` of another screen or ad start, which applies it unless it is the covered screen reappearing.
    public static func leave(_ screen: String) {
        assertMainThread()
        if adActive && screen == coveredScreen {
            pendingReappear = screen
            return
        }
        if let pending = pendingReappear, pending != screen {
            applyPendingLeave()
        }
        if let index = stack.lastIndex(of: screen) {
            stack.remove(at: index)
        }
    }

    /// Logs `{app}_{current}_{action}`.
    public static func track(_ action: String, params: [String: Any]? = nil) {
        assertMainThread()
        log(screen: current, action: action, params: params, fromPod: false)
    }

    /// Logs `{app}_{screen}_{action}`.
    public static func track(screen: String, action: String, params: [String: Any]? = nil) {
        assertMainThread()
        log(screen: screen, action: action, params: params, fromPod: false)
    }

    // MARK: - Internal (pod)

    /// Called right before a full-screen ad is presented.
    /// A leave still deferred from an earlier ad is applied first.
    static func beginFullScreenAd() {
        applyPendingLeave()
        coveredScreen = stack.last
        adActive = true
    }

    /// Called when a full-screen ad was dismissed or failed to present.
    /// `pendingReappear` stays so a `viewDidAppear` arriving after this call is still ignored.
    static func endFullScreenAd() {
        adActive = false
    }

    /// Pod-originated event: skipped silently when the app has not adopted `AnalyticsConfig`.
    static func trackFromPod(screen: String, action: String, params: [String: Any]? = nil) {
        log(screen: screen, action: action, params: params, fromPod: true)
    }

    // MARK: - Private

    /// Applies a deferred leave: removes the last occurrence of the pending screen and clears it.
    private static func applyPendingLeave() {
        guard let pending = pendingReappear else { return }
        pendingReappear = nil
        if let index = stack.lastIndex(of: pending) {
            stack.remove(at: index)
        }
    }

    private static func assertMainThread() {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
    }

    private static func log(screen: String, action: String, params: [String: Any]?, fromPod: Bool) {
        guard let appCode = AnalyticsConfig.appCode, !appCode.isEmpty else {
            if fromPod {
                debugPrint("AnalyticsConfig.appCode is not set; pod event '\(screen)_\(action)' skipped")
            } else {
                assertionFailure("AnalyticsConfig.appCode is not set; standard event '\(screen)_\(action)' dropped")
            }
            return
        }
        let name = AnalyticsNameValidator.validated("\(appCode)_\(screen)_\(action)")
        FirebaseLogger.shared.logEvent(name: name, params: params)
    }
}
