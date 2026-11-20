import Foundation

/// Receives every AdMob paid event `AdRevenueManager` fans out.
///
/// Lets an optional subspec (`MobileAds/AppsFlyer`) log the same ad-revenue event Facebook
/// gets, without Core depending on its SDK: the subspec registers itself when configured.
protocol AdRevenueObserver: AnyObject {
    /// Called on whatever thread AdMob delivered the paid event on.
    func adRevenueManager(didLogRevenue revenue: Double, currency: String, adType: AdType)
}

enum AdRevenueObservers {

    private static let lock = NSLock()
    private static var observers: [AdRevenueObserver] = []

    /// Idempotent: registering the same instance twice keeps one entry.
    static func add(_ observer: AdRevenueObserver) {
        lock.lock(); defer { lock.unlock() }
        guard !observers.contains(where: { $0 === observer }) else { return }
        observers.append(observer)
    }

    static func notify(revenue: Double, currency: String, adType: AdType) {
        lock.lock()
        let current = observers
        lock.unlock()
        for observer in current {
            observer.adRevenueManager(didLogRevenue: revenue, currency: currency, adType: adType)
        }
    }
}
