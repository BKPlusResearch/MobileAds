import SwiftUI

/// Marks a SwiftUI view as a tracked screen: `onAppear` enters it, `onDisappear` leaves it.
///
/// Usage:
/// ```swift
/// HomeView().trackedScreen("home")
/// ```
@available(iOS 15.0, *)
public struct TrackedScreenModifier: ViewModifier {
    let screen: String

    public func body(content: Content) -> some View {
        content
            .onAppear { ScreenTracker.enter(screen) }
            .onDisappear { ScreenTracker.leave(screen) }
    }
}

@available(iOS 15.0, *)
public extension View {
    /// Logs `{app}_{screen}_view` on appear and keeps `ScreenTracker.current` in sync.
    func trackedScreen(_ screen: String) -> some View {
        modifier(TrackedScreenModifier(screen: screen))
    }
}
