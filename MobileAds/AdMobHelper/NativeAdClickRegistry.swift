import Foundation

/// Weak keys never extend an SDK ad's life. Access remains on the main actor.
@MainActor
final class NativeAdClickRegistry {
    static let shared = NativeAdClickRegistry()
    private final class Handler: NSObject {
        let callback: () -> Void
        init(_ callback: @escaping () -> Void) { self.callback = callback }
    }
    private let handlers = NSMapTable<AnyObject, Handler>.weakToStrongObjects()
    func register(_ ad: AnyObject, callback: @escaping () -> Void) {
        handlers.setObject(Handler(callback), forKey: ad)
    }
    func remove(_ ad: AnyObject) { handlers.removeObject(forKey: ad) }
    func emit(_ ad: AnyObject) { handlers.object(forKey: ad)?.callback() }
}
