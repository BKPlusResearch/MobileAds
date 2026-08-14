import Foundation
import StoreKit

/// Entitlement state derived from `Transaction.currentEntitlements`.
///
/// This is the entitlements-first IAP layer. It is deliberately generic: the host app
/// supplies its product IDs through `EntitlementConfig`, builds its own paywall, and
/// decides its own gating policy. The base never shows UI and never hardcodes a product.
///
/// **Do not use this in the same app as `IAPService` / `IAPViewModel`.** Merely creating
/// an `IAPViewModel` spins up `IAPService.shared` and its own `Transaction.updates`
/// listener, giving the app two sources of truth that will drift apart.
///
/// Integration:
/// ```swift
/// EntitlementService.shared.configure(EntitlementConfig(productIDs: [...]))
/// EntitlementService.shared.bootstrap()          // not async, on purpose
/// await EntitlementService.shared.refresh()      // on foreground
/// ```
///
/// Unlock only when `verification == .verified`. Nothing is cached anywhere, so there is
/// no "last known" state to fall back on — and the host must not build one either.
///
/// - Important: This layer has not yet been exercised on a device. See the verification
///   checklist in the repository README before shipping it.
@available(iOS 15.0, *)
@MainActor
public final class EntitlementService: ObservableObject {

    // MARK: - Shared

    public static let shared = EntitlementService()

    // MARK: - Published State

    /// Whether the user currently holds one of the configured products.
    ///
    /// Only ever written by `publish(active:productID:expiry:)` after a full read of
    /// `currentEntitlements`. It is never read from storage, and it stays `false` until
    /// `verification == .verified` — including for a long-standing subscriber.
    @Published public private(set) var isEntitled = false

    /// Whether StoreKit has answered yet. Gate every unlock decision on this.
    @Published public private(set) var verification: EntitlementVerification = .pending

    /// The configured product that granted the current entitlement, if any.
    @Published public private(set) var activeProductID: String?

    /// Expiry of the active entitlement. `nil` for non-consumables (lifetime), which
    /// never expire — `nil` must not be read as "expired".
    @Published public private(set) var expiryDate: Date?

    /// Whether an introductory offer can still be claimed. Defaults to `false`:
    /// a missing trial badge costs one impression, a promised trial that bills
    /// immediately costs a complaint.
    @Published public private(set) var isIntroOfferEligible = false

    /// Loaded products, keyed by product ID. Display data only.
    @Published public private(set) var products: [String: Product] = [:]

    /// Whether to *proactively* suggest restoring purchases.
    ///
    /// - Important: This is not "should the Restore button be visible". The Restore
    ///   button must always be visible (App Store Guideline 3.1.1). Gating the button on
    ///   this flag is a direct path to rejection.
    @Published public private(set) var shouldProactivelyPromptRestore = false

    // MARK: - Private State

    private var config: EntitlementConfig?
    private var listener: Task<Void, Never>?
    /// Guards against an older `verify()` overwriting a newer one's result.
    private var generation = 0
    private var lastVerifyUptime: TimeInterval?
    private var hasBootstrapped = false

    /// The only `UserDefaults` key this layer owns. It is not an entitlement — no
    /// entitlement value is persisted anywhere, so there is none to tamper with.
    private static let promptedKey = "mobileads.entitlement.restorePrompted"
    private static let refreshDebounce: TimeInterval = 30
    /// 5s, in nanoseconds. The iOS 16 clock and interval-based sleep APIs do not
    /// back-deploy, and this pod targets iOS 15 — so the nanosecond overload it is.
    private static let verifyTimeout: UInt64 = 5_000_000_000

    // MARK: - Init

    private init() {
        shouldProactivelyPromptRestore = !UserDefaults.standard.bool(forKey: Self.promptedKey)

        // The listener is intentionally never cancelled: renewals, refunds and deferred
        // approvals arrive at any time, and this singleton lives for the whole process.
        // No `deinit` — writing one would imply a lifecycle that does not exist.
        listener = Task {
            for await update in Transaction.updates {
                await self.handle(update)
            }
        }
    }

    // MARK: - Configuration

    /// Supplies the product set. Call once, before `bootstrap()`.
    ///
    /// Re-configuring is refused: if the granting product set could be widened at
    /// runtime, it would be a value an already-running app could still change.
    /// Hosts that read product IDs from Remote Config must fetch first, then configure.
    public func configure(_ config: EntitlementConfig) {
        guard self.config == nil else {
            #if DEBUG
            assertionFailure("⚠️ [EntitlementService] Already configured. The productIDs set cannot be widened at runtime.")
            #endif
            return
        }
        self.config = config
    }

    // MARK: - Lifecycle

    /// Starts product loading and entitlement verification. Safe to call more than once.
    ///
    /// Deliberately **not** `async`: the host cannot await it, and therefore cannot block
    /// its first frame on StoreKit. Observe `verification` instead.
    public func bootstrap() {
        // Refuse to consume the one shot while unconfigured. Otherwise both children
        // below return instantly, `deadline` is cancelled before it can fire, and
        // `verification` is wedged at `.pending` forever — with no second chance,
        // because `hasBootstrapped` would already be set.
        guard config != nil else {
            #if DEBUG
            assertionFailure("⚠️ [EntitlementService] bootstrap() called before configure(). Configure first; this call did nothing.")
            #endif
            return
        }
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        Task { await self.runBootstrap() }
    }

    private func runBootstrap() async {
        // Armed *before* any await: a product fetch stalling behind a captive portal
        // must not be able to stop the timeout from ever firing.
        let deadline = Task {
            try? await Task.sleep(nanoseconds: Self.verifyTimeout)
            guard !Task.isCancelled else { return }
            if self.verification == .pending {
                self.verification = .timedOut
                #if DEBUG
                print("⚠️ [EntitlementService] StoreKit did not answer within 5s — verification is .timedOut")
                #endif
            }
        }

        // Genuinely concurrent. Product data is for display and must never sit in front
        // of the entitlement decision.
        async let productsDone: Void = loadProducts()
        async let verifyDone: Bool = verify()
        _ = await (productsDone, verifyDone)

        deadline.cancel()
    }

    /// Re-derives entitlement. Debounced to 30s unless `force` is set.
    public func refresh(force: Bool = false) async {
        // Deliberately in front of the debounce, and gated on *completeness* rather than
        // emptiness. The launch catalog fetch can fail (offline launch) and nothing else
        // retries it; a single-product refetch in `purchase()` would otherwise make the
        // catalog non-empty and permanently suppress the reload, leaving every other
        // product priceless. A missing catalog has nothing to do with throttling
        // entitlement reads, so it must not sit behind that timer.
        if let config = config, products.count < config.productIDs.count {
            await loadProducts()
        }

        if !force,
           let last = lastVerifyUptime,
           ProcessInfo.processInfo.systemUptime - last < Self.refreshDebounce {
            return
        }
        await verify()
    }

    // MARK: - Derivation

    /// The single decision point. Nothing else may conclude that the user is entitled.
    ///
    /// - Returns: The entitlement just derived. Callers must judge from this rather than
    ///   from `isEntitled`, which a concurrent verification may have superseded.
    @discardableResult
    private func verify() async -> Bool {
        // Not configured yet — decide nothing rather than decide wrongly.
        guard let config = config else { return false }

        generation += 1
        let mine = generation

        var active = false
        var product: String?
        var expiry: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard config.productIDs.contains(transaction.productID) else { continue }
            // `currentEntitlements` still emits unfinished consumables and expired
            // non-renewing purchases; neither may grant access.
            guard transaction.productType != .consumable else { continue }
            // Wall-clock comparison, and the user can move the clock. Moving it forward
            // only drops an entitlement (fail-closed), and StoreKit already filters
            // expired auto-renewables — this guard exists for expired *non-renewing*
            // purchases. Do not "fix" it into something that trusts a backward clock.
            if let expiration = transaction.expirationDate, expiration <= Date() { continue }

            active = true
            product = transaction.productID
            expiry = transaction.expirationDate
            break
        }

        // `@MainActor` does not serialize across `await`. Without this check, a stale
        // verify could overwrite the result of a purchase that just completed — the user
        // pays and immediately loses access.
        //
        // The cancellation check matters just as much: `refresh()` is public and `async`,
        // so it inherits the caller's cancellation — `.task { await refresh() }` is
        // cancelled when the view disappears. A cancelled read ends the sequence early
        // with `active == false`, and publishing that would stamp `.verified` on a false
        // negative, dropping a paying subscriber to free.
        // A cancelled read is truncated, so its `active` is meaningless — say `false`
        // rather than hand back a value this guard just declared untrustworthy.
        guard !Task.isCancelled else { return false }
        // Superseded: a newer pass has already published, so its result is the freshest
        // answer available and is what a caller should judge from.
        guard mine == generation else { return isEntitled }

        publish(active: active, productID: product, expiry: expiry)
        await refreshIntroEligibility(generation: mine)
        return active
    }

    /// The only place `verification` is set to `.verified`.
    private func publish(active: Bool, productID: String?, expiry: Date?) {
        isEntitled = active
        activeProductID = productID
        expiryDate = expiry
        verification = .verified
        lastVerifyUptime = ProcessInfo.processInfo.systemUptime
        // Clear the live flag only. Burning the *persisted* one here would record a
        // prompt that was never shown, so a later lapse on the same install would never
        // offer restore again.
        if active { shouldProactivelyPromptRestore = false }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            await transaction.finish()
            await refresh(force: true)

        case .unverified(let transaction, let error):
            #if DEBUG
            print("⚠️ [EntitlementService] Transaction failed verification — \(error)")
            #endif
            // Finished on purpose. Entitlement comes from `currentEntitlements`, which is
            // independent of this queue, so an unverified transaction grants nothing by
            // either route. If verification failed only transiently, the entitlement is
            // still in `currentEntitlements` and verifies normally later. Finishing it
            // only stops StoreKit redelivering a transaction that will never be honored.
            //
            // - Note: This reasoning covers subscriptions and non-consumables, where the
            //   entitlement is re-derivable. A host selling **consumables** should not
            //   adopt it unqualified: finishing an unverified consumable discards the
            //   only delivery record, so a charged purchase is never credited.
            await transaction.finish()
        }
    }

    // MARK: - Products

    private func loadProducts() async {
        guard let config = config else { return }
        do {
            let fetched = try await Product.products(for: config.productIDs)
            var loaded: [String: Product] = [:]
            for product in fetched { loaded[product.id] = product }
            products = loaded
        } catch {
            // Swallowed here: a missing price must not block the entitlement decision.
            // `refresh()` and `purchase()` both retry, so this is not terminal.
            #if DEBUG
            print("❌ [EntitlementService] Failed to load products — \(error)")
            #endif
            return
        }
        // Eligibility must be recomputed now. `verify()` reads the on-device transaction
        // cache and almost always finishes before this network fetch, so the pass it ran
        // saw an empty catalog and concluded `false`.
        await refreshIntroEligibility(generation: generation)
    }

    /// Localized price string for a configured product, once loaded.
    public func displayPrice(for productID: String) -> String? {
        products[productID]?.displayPrice
    }

    /// Resolves eligibility against a *deterministic* product.
    ///
    /// Sorted by product ID first: `products` is a `Dictionary`, so its value order is
    /// hash-dependent and answers for a different product between runs.
    private func refreshIntroEligibility(generation mine: Int) async {
        var candidates = products.values.sorted { $0.id < $1.id }
        if let group = config?.subscriptionGroupID {
            candidates = candidates.filter { $0.subscription?.subscriptionGroupID == group }
        }

        // Only a product that actually declares an offer may answer this. Eligibility is
        // a *group-level* question — "has this Apple ID used an intro offer in this
        // group" — so an offer-free product happily answers `true`, and the host would
        // promise a trial on a plan that bills immediately. No fallback candidate.
        guard let subject = candidates.compactMap({ $0.subscription })
                .first(where: { $0.introductoryOffer != nil }) else {
            isIntroOfferEligible = false
            return
        }

        let eligible = await subject.isEligibleForIntroOffer
        // Same reasoning as `verify()`: this await is a full StoreKit round-trip, and a
        // newer pass may have answered while it was in flight.
        guard !Task.isCancelled, mine == generation else { return }
        isIntroOfferEligible = eligible
    }

    // MARK: - Purchase & Restore

    /// Buys a configured product.
    ///
    /// The verdict comes from the returned transaction, never from global entitlement
    /// state — a consumable never appears in `currentEntitlements`, so reading entitlement
    /// here would report failure on every consumable purchase that in fact charged the card.
    public func purchase(_ productID: String) async -> EntitlementPurchaseOutcome {
        // Fail closed: only a configured product may be bought through this layer.
        guard let config = config, config.productIDs.contains(productID) else {
            #if DEBUG
            assertionFailure("⚠️ [EntitlementService] purchase(\(productID)) with no matching configured product. Check configure() ran with this ID.")
            #endif
            return .failed(.productUnavailable)
        }

        var resolved = products[productID]
        if resolved == nil {
            // The launch catalog fetch may have failed. Without this retry, one offline
            // launch leaves every product unbuyable for the rest of the process.
            do {
                resolved = try await Product.products(for: [productID]).first
                if let fetched = resolved { products[productID] = fetched }
            } catch {
                // Classify rather than collapse: "you are offline, retry" and "this plan
                // does not exist in your storefront" call for different host behavior.
                return .failed(mapFailure(error))
            }
        }
        guard let product = resolved else {
            return .failed(.productUnavailable)
        }

        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    return .failed(.verificationFailed)
                }
                await transaction.finish()
                // Updates entitlement state; not used to judge this purchase.
                await refresh(force: true)
                return .purchased

            case .userCancelled:
                return .cancelled

            case .pending:
                return .pending

            @unknown default:
                return .failed(.unknown("Unknown purchase result"))
            }
        } catch {
            return .failed(mapFailure(error))
        }
    }

    /// Restores purchases via `AppStore.sync()`, then re-derives.
    ///
    /// Dismissing the sign-in sheet returns `.cancelled`, not a failure — mapping every
    /// throw to an error makes "tap Restore, then back out" show an error alert.
    public func restore() async -> EntitlementRestoreOutcome {
        // Unconfigured, `verify()` decides nothing and would report `.nothingToRestore`
        // to a user who does hold a purchase.
        guard config != nil else {
            #if DEBUG
            assertionFailure("⚠️ [EntitlementService] restore() before configure(). Configure first.")
            #endif
            return .failed(.productUnavailable)
        }
        do {
            try await AppStore.sync()
            // Judge from this verification's own result. `AppStore.sync()` delivers
            // transactions to the `updates` listener, which fires its own refresh — so
            // reading `isEntitled` here can report a value from before the sync and tell
            // a user who just restored successfully that there was nothing to restore.
            let active = await verify()
            return active ? .restored : .nothingToRestore
        } catch {
            let failure = mapFailure(error)
            if failure == .cancelled { return .cancelled }
            return .failed(failure)
        }
    }

    // MARK: - Restore Prompting

    /// Records that the restore suggestion has been shown, so it is not offered again.
    /// Call this from the host after presenting its own suggestion UI.
    public func markRestorePrompted() {
        UserDefaults.standard.set(true, forKey: Self.promptedKey)
        shouldProactivelyPromptRestore = false
    }

    // MARK: - Error Mapping

    private func mapFailure(_ error: Error) -> EntitlementFailure {
        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .userCancelled: return .cancelled
            case .networkError: return .network
            case .notAvailableInStorefront: return .productUnavailable
            default: return .unknown(String(describing: storeKitError))
            }
        }
        if let purchaseError = error as? Product.PurchaseError {
            switch purchaseError {
            case .productUnavailable: return .productUnavailable
            case .purchaseNotAllowed: return .notAllowed
            default: return .unknown(String(describing: purchaseError))
            }
        }
        return .unknown(error.localizedDescription)
    }
}
