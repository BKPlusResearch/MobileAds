//
//  AnalyticsNameValidator.swift
//  MobileAds
//

import Foundation

/// Validates standard event names against docs/tracking-standard.md.
/// DEBUG: a violation trips `assertionFailure` with the name and the reason.
/// Release: the event is still logged, truncated to `maxLength`.
enum AnalyticsNameValidator {
    static let maxLength = 40

    /// Allowed action suffixes. A name must end with `_<suffix>`; this covers the
    /// fixed actions, `{target}_click`, the IAP purchase actions and the ad states.
    static let allowedActionSuffixes: [String] = [
        "view", "back", "close", "next", "skip", "click",
        "start", "complete", "success", "fail", "cancel",
        "show", "show_fail",
        "purchase",
        "request", "load", "load_fail", "reward"
    ]

    /// Returns the name to send (truncated when over the limit), or reports violations in DEBUG.
    static func validated(_ name: String) -> String {
        if let reason = violation(in: name) {
            assertionFailure("Invalid analytics event name '\(name)': \(reason)")
        }
        return name.count > maxLength ? String(name.prefix(maxLength)) : name
    }

    /// The first rule the name breaks, or nil when it is valid.
    static func violation(in name: String) -> String? {
        if name.range(of: "^[a-z0-9_]+$", options: .regularExpression) == nil {
            return "only [a-z0-9_] is allowed"
        }
        if name.count > maxLength {
            return "\(name.count) characters, limit is \(maxLength)"
        }
        if name.hasSuffix("_show") || name.hasSuffix("_show_fail"),
           !["_aoa_", "_inter_", "_ad_"].contains(where: { name.contains($0) }) {
            return "show is only for ads; use view"
        }
        let hasAllowedAction = allowedActionSuffixes.contains { name.hasSuffix("_" + $0) }
        if !hasAllowedAction {
            return "action is not in the allowed list"
        }
        return nil
    }
}
