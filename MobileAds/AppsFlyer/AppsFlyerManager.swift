//
//  AppsFlyerManager.swift
//  MobileAds — `MobileAds/AppsFlyer` subspec
//
//  Install attribution, sessions, `af_ad_view` with ad revenue from `AdRevenueManager`,
//  and `af_purchase` for purchases made through `EntitlementService`. Present only when the host's Podfile includes the subspec.
//

import UIKit
import StoreKit
import AppTrackingTransparency
import AppsFlyerLib

@available(iOS 15.0, *)
@MainActor
public final class AppsFlyerManager {

    public static let shared = AppsFlyerManager()

    /// Upper bound on how long a session waits for the ATT answer, so a prompt that is
    /// never shown or never answered cannot hold attribution back.
    private static let attWaitTimeout: TimeInterval = 60

    private var isConfigured = false
    private var isSessionReady = false
    private var didStartThisCycle = false
    private var attTimedOut = false

    private init() {}

    // MARK: - Setup

    /// Call once from `application(_:didFinishLaunchingWithOptions:)`.
    ///
    /// Sessions start once the ATT prompt has been answered (or `attWaitTimeout` passed),
    /// so a first-install session carries the IDFA when the user grants it. The host keeps
    /// requesting ATT exactly as before; this only waits for the answer.
    ///
    /// - Parameters:
    ///   - devKey: AppsFlyer dev key.
    ///   - appleAppID: Numeric App Store ID, without the `id` prefix.
    ///   - launchOptions: Forwarded so a cold-launch Universal Link is attributed.
    ///   - debug: Verbose SDK logging. Defaults to `true` in DEBUG builds only.
    public func configure(devKey: String,
                          appleAppID: String,
                          launchOptions: [UIApplication.LaunchOptionsKey: Any]?,
                          debug: Bool = AppsFlyerManager.isDebugBuild) {
        guard !isConfigured else { return }
        isConfigured = true

        let appsFlyer = AppsFlyerLib.shared()
        appsFlyer.initialize(devKey: devKey, appId: appleAppID)
        appsFlyer.isDebug = debug
        appsFlyer.handleLaunchOptions(launchOptions)

        // Fires once per foreground cycle; `start()` must be called inside it.
        appsFlyer.registerSessionReadyListener { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isSessionReady = true
                self.didStartThisCycle = false
                self.startIfReady()
            }
        }

        let center = NotificationCenter.default
        // Dismissing the ATT prompt makes the app active again; that is the answer arriving.
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.startIfReady() }
        }
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isSessionReady = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.attWaitTimeout) { [weak self] in
            MainActor.assumeIsolated {
                self?.attTimedOut = true
                self?.startIfReady()
            }
        }

        EntitlementTransactionObservers.add(self)
        AdRevenueObservers.add(self)
    }

    /// The AppsFlyer install ID, for linking other tools' data to this install.
    public var appsFlyerUID: String {
        AppsFlyerLib.shared().getAppsFlyerUID()
    }

    /// Logs a custom or standard AppsFlyer in-app event.
    public func logEvent(_ name: String, values: [String: Any]? = nil) {
        guard isConfigured else { return }
        AppsFlyerLib.shared().logEvent(name, withValues: values)
    }

    public nonisolated static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private func startIfReady() {
        let attAnswered = ATTrackingManager.trackingAuthorizationStatus != .notDetermined
        guard isSessionReady, !didStartThisCycle, attAnswered || attTimedOut else { return }
        didStartThisCycle = true
        AppsFlyerLib.shared().start()
    }
}

// MARK: - Purchases

@available(iOS 15.0, *)
extension AppsFlyerManager: EntitlementTransactionObserver {

    /// `af_purchase` for the in-app purchase only. Renewals are not logged from the device.
    func entitlementService(didPurchase transaction: Transaction, product: Product) async {
        logEvent(AFEventPurchase, values: [
            AFEventParamContentId: product.id,
            AFEventParamOrderId: String(transaction.id),
            AFEventParamRevenue: NSDecimalNumber(decimal: EntitlementPricing.chargedPrice(transaction, product: product)),
            AFEventParamCurrency: product.priceFormatStyle.currencyCode
        ])
    }
}

// MARK: - Ad revenue

@available(iOS 15.0, *)
extension AppsFlyerManager: AdRevenueObserver {

    /// `af_ad_view` with revenue for every AdMob paid event — the AppsFlyer counterpart of
    /// the Facebook `AD_IMPRESSION` event `AdRevenueManager` logs at the same moment.
    /// Registered only by `configure`, so reaching here means the SDK is initialized.
    nonisolated func adRevenueManager(didLogRevenue revenue: Double, currency: String, adType: AdType) {
        AppsFlyerLib.shared().logEvent(AFEventAdView, withValues: [
            AFEventParamRevenue: revenue,
            AFEventParamCurrency: currency,
            "af_adrev_ad_type": adType.rawValue
        ])
    }
}
