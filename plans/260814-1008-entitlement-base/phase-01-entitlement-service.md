---
phase: 1
title: "EntitlementService"
status: completed
priority: P1
effort: "8h"
dependencies: []
---

# Phase 1: EntitlementService

> Viết lại sau red-team 2026-08-14. Bản đầu sai 6 chỗ, trong đó 4 Critical. Các
> chỗ đánh dấu `[RT-Fn]` là sửa theo finding tương ứng — đọc `plan.md` mục
> `## Red Team Review` trước khi "đơn giản hoá" bất kỳ cái nào trong số đó.

## Overview

Dựng core: một service derive entitlement từ `Transaction.currentEntitlements`,
không đọc storage để ra quyết định.

Phase này **chỉ thêm file**. `IAPService` và layer cũ không bị chạm tới (D4). Pod
sau phase này mang hai layer song song; 4 app đang dùng `IAPService` không bị ảnh
hưởng và không cần bump pod.

**Viết tổng quát.** Base không biết gì về app nào: không product ID cứng, không
giả định app bán subscription, không tự hiện UI. Host truyền cấu hình vào và tự
dựng paywall.

## Requirements

**Functional**
- `isEntitled` derive từ `currentEntitlements`: chỉ nhận `.verified`,
  `revocationDate == nil`, productID thuộc tập cấu hình, không phải consumable,
  và chưa hết hạn.
- Trạng thái verify là **ba giá trị**, không phải Bool: `.pending` / `.verified` /
  `.timedOut`. `[RT-F1]`
- Listener `Transaction.updates` sống suốt process; mỗi update `finish()` rồi
  **re-derive toàn bộ**.
- `verify()` chống chồng lấn bằng generation token. `[RT-F6]`
- `bootstrap()` **không async** — host không thể block lên nó. `[RT-F4]`
- `purchase` trả outcome có `.pending` riêng và `.failed` mang enum có kiểu.
- `restore()` = `AppStore.sync()` + re-derive; huỷ đăng nhập không phải lỗi. `[RT-F11]`
- Intro-offer eligibility chọn product **xác định**, mặc định `false`. `[RT-F8]`

**Tổng quát — ràng buộc thiết kế**
- Không hardcode product ID, tên gói, hay bất kỳ thứ gì của một app cụ thể.
- **Không giả định app bán subscription.** Non-consumable (lifetime) nằm trong
  `currentEntitlements` vĩnh viễn với `expirationDate == nil` — không được coi
  `nil` là hết hạn.
- Không tự hiện UI, không tự bung dialog, không tự quyết khi nào show paywall.
- Public API đủ để host dựng paywall bất kỳ.

**Non-functional**
- **iOS 15.0** (`MobileAds.podspec:78`) và **Swift 5.5** (`:95`). Không được dùng
  `ContinuousClock`, `Duration`, `Task.sleep(for:)` — tất cả đều iOS 16+/Swift 5.7
  và không back-deploy. `[RT-F3]`
- `ObservableObject`, không `@Observable` (iOS 17+).
- Log chỉ trong `#if DEBUG`.
- Theo `docs/code-standards.md`: file `{Feature}Service.swift`, types PascalCase.

## Architecture

```
EntitlementConfig  productIDs (BẮT BUỘC, non-empty), subscriptionGroupID
        │
        ▼
EntitlementService (@MainActor, ObservableObject, singleton)
        │
        ├── configure()   → một lần duy nhất, không nới được sau đó
        ├── bootstrap()   → KHÔNG async; bên trong: timeout ‖ (loadProducts ‖ verify)
        ├── verify()      → generation token; publish chỉ khi còn là bản mới nhất
        ├── refresh(force)→ debounce 30s (systemUptime)
        ├── purchase(id)  → phán quyết từ CHÍNH transaction vừa trả về
        └── restore()     → AppStore.sync() → verify()
```

### Mô hình trạng thái — thay đổi lớn nhất so với bản đầu `[RT-F1]`

Bản đầu: `isEntitled` khởi tạo từ cache, `hasVerified` là Bool, và timeout đặt
`hasVerified = true`. Kết quả: một giá trị chưa bao giờ được kiểm chứng được
đóng dấu "đã verify". Đó chính là lỗi mà plan này viện làm lý do thay `IAPService`.

Bản đúng — **không còn cache entitlement nào cả** `[V3]`:

| Property | Ý nghĩa | Được phép dùng để |
|---|---|---|
| `verification: .pending / .verified / .timedOut` | StoreKit đã trả lời chưa | quyết định |
| `isEntitled: Bool` | **`false` cho tới khi `.verified`**. Không bao giờ đọc từ storage | mở khoá — chỉ khi `verification == .verified` |

Timeout không còn "đóng dấu verified" — nó chuyển sang `.timedOut` và **trả quyền
quyết định cho host**. README khuyến nghị chính sách mặc định: **coi như free và
hiện ads** `[V1]` — ưu tiên doanh thu, chấp nhận subscriber mạng tệ thấy ads vài
giây đầu. Host vẫn được phép chọn khác; thư viện chỉ cấp trạng thái.

### Vì sao không còn cache `[V3]`

Bản trước có `cachedEntitlementHint` đọc từ `UserDefaults`, để host vẽ frame đầu
lạc quan cho subscriber. Quyết định validation: **không expose ra public.**

Hệ quả trực tiếp: nếu host không đọc được nó, và mọi quyết định đều gác sau
`.verified`, thì cái Bool đó **không còn ai đọc**. Xoá hẳn — cả `cacheKey`, cả
lệnh ghi trong `publish()`, cả lệnh đọc trong `init()`.

Được gì: bề mặt tấn công của F1 biến mất hoàn toàn. Không còn giá trị entitlement
nào nằm trong storage để mà giả mạo, và không còn đường nào để một giá trị chưa
kiểm chứng lọt vào quyết định.

Mất gì, nói thẳng: subscriber sẽ thấy UI free trong vài chục ms đầu mỗi lần mở app
trước khi `verify()` trả lời. Nếu sau này thấy nháy khó chịu thì thêm lại hint —
nhưng phải thêm như một property **tách biệt**, không bao giờ được là giá trị khởi
tạo của `isEntitled`.

`UserDefaults` chỉ còn đúng một key trong base: `restorePrompted` (bước 15), và nó
không phải entitlement.

### Trường hợp offline `[RT-F5]`

Red-team nêu: `currentEntitlements` không có kênh lỗi, offline trả rỗng và bị đọc
thành "không phải subscriber".

Cơ chế đúng, hẹp hơn phát biểu gốc: trên máy **đã từng sync**, `currentEntitlements`
được phục vụ từ transaction cache trên máy nên **vẫn đúng khi offline**. Trường hợp
thật sự mù là **cài mới + offline** — chưa có dữ liệu local nào, và khi đó
`verification` về `.timedOut` chứ không phải `.verified`, nên host biết là chưa có
câu trả lời.

Không cố phân biệt offline với không-có-quyền: API không cho phép, và giả vờ phân
biệt được sẽ đẻ ra bug tinh vi hơn.

## Related Code Files

- Create: `MobileAds/IAP/EntitlementService.swift` (~230 dòng)
- Create: `MobileAds/IAP/EntitlementConfig.swift` (~40 dòng)
- Create: `MobileAds/IAP/EntitlementOutcome.swift` (~60 dòng)
- Không sửa/xoá gì.

## Implementation Steps

1. `EntitlementConfig.swift` — **fail closed** `[RT-F2]`

   ```swift
   public struct EntitlementConfig {
       /// Tập product cấp quyền. BẮT BUỘC, không có giá trị mặc định.
       ///
       /// Không có nhánh "rỗng = nhận tất cả". `currentEntitlements` còn phát ra
       /// consumable chưa finish và non-renewing đã hết hạn — nhận bừa nghĩa là
       /// một gói xu cấp Premium vĩnh viễn.
       public let productIDs: Set<String>

       /// Giới hạn phạm vi hỏi intro-offer eligibility. nil = mọi subscription
       /// trong danh mục đã tải.
       public let subscriptionGroupID: String?

       public init(productIDs: Set<String>, subscriptionGroupID: String? = nil)
   }
   ```

   Không có `init()` rỗng. Quyết định D6 của bản đầu ("rỗng = nhận tất cả") đã bị
   xoá — nó biện minh cho một tình huống migration mà Non-goals của plan cấm.

2. `EntitlementOutcome.swift` `[RT-F11]`

   ```swift
   public enum EntitlementFailure: Equatable {
       case network
       case cancelled
       case notAllowed          // parental control, payment bị chặn
       case productUnavailable
       case verificationFailed
       case unknown(String)     // description hệ thống, chỉ để log
   }

   public enum EntitlementPurchaseOutcome: Equatable {
       case purchased
       case cancelled
       /// Ask to Buy và các phê duyệt hoãn khác. Giải quyết sau qua listener —
       /// host nên đóng paywall và báo "đang chờ duyệt", không báo lỗi.
       case pending
       case failed(EntitlementFailure)
   }

   public enum EntitlementRestoreOutcome: Equatable {
       case restored
       case nothingToRestore
       case cancelled           // user huỷ sheet đăng nhập — KHÔNG phải lỗi
       case failed(EntitlementFailure)
   }

   public enum EntitlementVerification: Equatable {
       case pending, verified, timedOut
   }
   ```

   Không để `localizedDescription` thô lọt vào API công khai làm chuỗi chính —
   host cần *loại lỗi* để xử, không cần câu tiếng Anh của hệ thống để in ra.

3. `EntitlementService.swift` — khung, toàn bộ API dùng được ở iOS 15 `[RT-F3]`

   ```swift
   @available(iOS 15.0, *)
   @MainActor
   public final class EntitlementService: ObservableObject {
       public static let shared = EntitlementService()

       @Published public private(set) var isEntitled = false          // KHÔNG có nguồn nào ngoài verify()
       @Published public private(set) var verification: EntitlementVerification = .pending
       @Published public private(set) var activeProductID: String?
       @Published public private(set) var expiryDate: Date?
       @Published public private(set) var isIntroOfferEligible = false // mặc định FALSE
       @Published public private(set) var products: [String: Product] = [:]
       @Published public private(set) var shouldProactivelyPromptRestore = false

       private var config: EntitlementConfig?
       private var listener: Task<Void, Never>?
       private var generation = 0
       private var lastVerifyUptime: TimeInterval?
       private var hasBootstrapped = false

       // Không có key entitlement nào. `restorePrompted` là key DUY NHẤT của base. [V3]
       private static let promptedKey = "mobileads.entitlement.restorePrompted"
       private static let refreshDebounce: TimeInterval = 30
       private static let verifyTimeout: UInt64 = 5_000_000_000   // ns
   }
   ```

   `systemUptime` thay `ContinuousClock`; `UInt64` nanosecond thay `Duration`.
   `systemUptime` không chạy khi máy ngủ — với debounce 30s thì lệch về phía
   refresh nhiều hơn, vô hại.

4. `init()` — khởi động listener, không đọc entitlement từ đâu cả.
   - **Không đọc `UserDefaults` cho `isEntitled`.** `init()` không được chạm vào
     entitlement dưới bất kỳ hình thức nào — đây là điểm quan trọng nhất file.
     `[RT-F1][V3]`
   - `shouldProactivelyPromptRestore = !UserDefaults.standard.bool(forKey: promptedKey)`
   - `listener = Task { for await update in Transaction.updates { await handle(update) } }`
   - Listener **cố ý không cancel**: singleton sống hết process, renewal/refund/
     deferred tới bất cứ lúc nào. Không viết `deinit` — singleton không deinit,
     viết vào chỉ gây hiểu nhầm là có vòng đời.

5. `configure(_:)` — **một lần duy nhất** `[RT-F2]`

   ```swift
   public func configure(_ config: EntitlementConfig) {
       guard self.config == nil else {
           #if DEBUG
           assertionFailure("EntitlementService đã được cấu hình. Không nới tập productIDs lúc runtime.")
           #endif
           return
       }
       self.config = config
   }
   ```

   Không cho re-configure: nếu nới được lúc runtime thì tập sản phẩm cấp quyền
   trở thành thứ có thể bị thay đổi sau khi app đã chạy.

6. `verify()` — hàm quyết định duy nhất, có generation token `[RT-F6]`

   ```swift
   private func verify() async {
       guard let config else { return }        // chưa configure → không phán quyết gì

       generation += 1
       let mine = generation

       var active = false
       var product: String?
       var expiry: Date?

       for await result in Transaction.currentEntitlements {
           guard case .verified(let t) = result else { continue }
           guard t.revocationDate == nil else { continue }
           guard config.productIDs.contains(t.productID) else { continue }
           guard t.productType != .consumable else { continue }              // [RT-F2]
           if let exp = t.expirationDate, exp <= Date() { continue }         // [RT-F2] non-renewing
           active = true; product = t.productID; expiry = t.expirationDate
           break
       }

       guard mine == generation else { return }   // đã có verify mới hơn — bỏ kết quả này
       publish(active: active, productID: product, expiry: expiry)
       await refreshIntroEligibility()
   }
   ```

   Generation token là bắt buộc: `verify()` có nhiều điểm suspend, `@MainActor`
   **không** serialize qua `await`. Không có nó thì một `verify()` cũ đang treo có
   thể ghi đè kết quả của lần mua vừa xong — user trả tiền rồi mất quyền ngay.

   `currentEntitlements` đã loại subscription auto-renewable hết hạn; ba guard
   thêm vào để loại phần nó **vẫn** trả về: receipt giả, giao dịch đã hoàn tiền,
   consumable, và non-renewing quá hạn. Grace period / billing retry vẫn nằm
   trong đó nên được tính là entitled — đúng, và miễn phí.

7. `publish(active:productID:expiry:)`

   ```swift
   isEntitled = active
   activeProductID = productID
   expiryDate = expiry
   verification = .verified
   lastVerifyUptime = ProcessInfo.processInfo.systemUptime
   if active { markRestorePrompted() }        // đã có quyền thì không gợi ý restore nữa
   ```

   Không có lệnh ghi `UserDefaults` nào ở đây. `[V3]`

   `verification = .verified` chỉ được set ở đây, trong đúng một hàm, sau khi đã
   đọc xong `currentEntitlements`. Không nơi nào khác được phép chạm vào nó
   ngoài nhánh timeout (đặt `.timedOut`).

8. `bootstrap()` — **không async**, timeout arm trước, hai việc chạy song song `[RT-F4]`

   ```swift
   public func bootstrap() {
       guard !hasBootstrapped else { return }
       hasBootstrapped = true
       Task { await runBootstrap() }
   }

   private func runBootstrap() async {
       let deadline = Task {
           try? await Task.sleep(nanoseconds: Self.verifyTimeout)
           if verification == .pending {
               verification = .timedOut
               #if DEBUG
               print("EntitlementService: verify quá 5s, đang dùng hint từ cache")
               #endif
           }
       }
       async let productsDone: Void = loadProducts()
       async let verifyDone: Void = verify()
       _ = await (productsDone, verifyDone)
       deadline.cancel()
   }
   ```

   Ba điểm bản đầu sai và đã sửa:
   - `bootstrap()` **không async** → host không thể `await` nó trước frame đầu.
   - Timeout tạo **trước** `loadProducts()`. Bản đầu arm sau, nên một lần fetch
     product treo 60s (captive portal) làm timeout không bao giờ chạy.
   - `loadProducts()` và `verify()` **thật sự song song**. Sơ đồ kiến trúc bản
     đầu ghi song song nhưng pseudocode viết tuần tự.

   Product là dữ liệu hiển thị — không bao giờ được chặn đường entitlement.

9. `refresh(force:)` — debounce bằng `systemUptime`

   ```swift
   public func refresh(force: Bool = false) async {
       if !force, let last = lastVerifyUptime,
          ProcessInfo.processInfo.systemUptime - last < Self.refreshDebounce { return }
       await verify()
   }
   ```

10. `loadProducts()` / `displayPrice(for:)` — `Product.products(for: config.productIDs)`,
    cache vào `products`. Nuốt lỗi (log `#if DEBUG`): giá là thứ hiển thị được,
    không phải thứ ra quyết định.

11. `purchase(_ productID: String)` — phán quyết từ transaction vừa trả về `[RT-F7]`

    ```swift
    switch try await product.purchase() {
    case .success(let result):
        guard case .verified(let t) = result else { return .failed(.verificationFailed) }
        await t.finish()
        await refresh(force: true)      // cập nhật entitlement, KHÔNG dùng để phán quyết lần mua này
        return .purchased
    case .userCancelled: return .cancelled
    case .pending:       return .pending
    @unknown default:    return .failed(.unknown("unknown purchase result"))
    }
    ```

    Bản đầu trả `isEntitled ? .purchased : .failed` — gắn thành công của **một lần
    mua** vào **trạng thái entitlement toàn cục**. Consumable không bao giờ xuất
    hiện trong `currentEntitlements`, nên mọi lần mua consumable đều báo thất bại
    trong khi thẻ đã bị trừ tiền. Đây là mâu thuẫn trực tiếp với Goal 2.

12. `handle(_ result:)` — listener

    ```swift
    case .verified(let t):
        await t.finish()
        await refresh(force: true)
    case .unverified(let t, let error):
        #if DEBUG
        print("EntitlementService: transaction trượt verify — \(error)")
        #endif
        await t.finish()          // [V2]
    ```

    **Finish cả transaction unverified.** `[V2]` Bản trước không finish, với lý do
    "một giao dịch hợp lệ trượt verify sẽ mất luôn" — **lý do đó sai**.

    Entitlement derive từ `currentEntitlements`, độc lập hoàn toàn với hàng đợi
    `Transaction.updates`. Một transaction `.unverified` không cấp quyền ở **cả
    hai** đường. Nếu verify trượt vì lý do tạm thời, sau khi điều kiện hết thì
    `currentEntitlements` vẫn chứa entitlement đó và verify bình thường — không
    phụ thuộc vào việc transaction kia đã finish hay chưa.

    Nên finish nó không làm mất quyền gì; nó chỉ dứt điểm việc StoreKit gửi lại
    mãi một transaction ta sẽ không bao giờ honor. Không cần cấu trúc dedupe.

13. `restore()` `[RT-F11]`

    ```swift
    do {
        try await AppStore.sync()
        await verify()
        return isEntitled ? .restored : .nothingToRestore
    } catch {
        if (error as? StoreKitError) == .userCancelled { return .cancelled }
        return .failed(.network)
    }
    ```

    Huỷ sheet đăng nhập là hành vi bình thường, không phải lỗi — bản đầu map mọi
    throw thành `.failed` nên bấm Restore rồi thoát sẽ hiện alert lỗi.

14. `refreshIntroEligibility()` — xác định, mặc định `false` `[RT-F8]`

    ```swift
    var candidates = products.values.compactMap(\.subscription)
    if let group = config?.subscriptionGroupID {
        candidates = candidates.filter { $0.subscriptionGroupID == group }
    }
    // Chọn product THỰC SỰ có intro offer. Lấy .first của Dictionary.values là
    // phụ thuộc thứ tự băm — đổi giữa các lần chạy, trả lời sai product.
    let subject = candidates.first(where: { $0.introductoryOffer != nil }) ?? candidates.first
    guard let subject else { isIntroOfferEligible = false; return }
    isIntroOfferEligible = await subject.isEligibleForIntroOffer
    ```

    Hai sửa so với bản đầu: dùng `subscriptionGroupID` đã cấu hình (bản đầu khai
    field rồi không đọc), và mặc định `false` khi chưa tải xong. Badge trial thiếu
    là mất một impression; hứa trial mà StoreKit tính tiền ngay là đơn khiếu nại.

    `ios033/TrialLedger.swift:33-44` đã gặp và sửa đúng bug thứ tự dictionary này,
    có comment giải thích. Đừng viết lại bản sai.

15. `shouldProactivelyPromptRestore` + `markRestorePrompted()` `[RT-F10]`

    - Là `@Published` **stored**, không phải computed đọc `UserDefaults` — computed
      không phát `objectWillChange`, SwiftUI sẽ thấy giá trị cũ.
    - Reset về `false` khi `isEntitled` chuyển sang `true` (bước 7).
    - Tên có chữ `Proactively` để không ai nhầm nó với "có nên hiện nút Restore
      không". **Nút Restore phải luôn hiện** — Guideline 3.1.1. Cờ này chỉ nói
      "có nên chủ động gợi ý".

16. Logging: bọc `#if DEBUG`. Pod không có logger dùng chung cho chẩn đoán
    (`MobileAds/Extension/` chỉ có `CallBackDefine.swift`, `UIView+Extension.swift`;
    `FirebaseLogger/` là analytics) → dùng `print` trong `#if DEBUG`.

## Success Criteria

**Kiểm được ở phase này** (không có app nào chạy base — xem R0):

- [ ] Pod build sạch trên iOS 15 simulator
- [ ] `grep -rnE "ContinuousClock|Duration|sleep\(for:" MobileAds/IAP/Entitlement*.swift` → 0 hit
- [ ] Không `print` nào ngoài `#if DEBUG` trong 3 file mới
- [ ] Không hardcode product ID / tên app / chuỗi hiển thị:
      `grep -rniE "premium|weekly|monthly|yearly|moboco" MobileAds/IAP/Entitlement*.swift`
      chỉ ra doc comment
- [ ] `EntitlementConfig` **không** có `init()` rỗng; `productIDs` không có default
- [ ] `verification = .verified` chỉ được gán ở đúng một chỗ (`publish`)
- [ ] `grep -n "UserDefaults" MobileAds/IAP/EntitlementService.swift` → chỉ ra
      `restorePrompted`, **không** có key entitlement nào `[V3]`
- [ ] Không có property nào tên `cached*` / `hint*` trong API công khai `[V3]`
- [ ] `handle()` gọi `finish()` ở **cả hai** nhánh verified và unverified `[V2]`
- [ ] `bootstrap()` không phải `async`
- [ ] Đọc lại luồng derive: `expirationDate == nil` (non-consumable) **không** bị
      coi là hết hạn
- [ ] `git diff` chỉ có file thêm mới — 0 dòng sửa trong `IAPService*`, `IAPModels`,
      `IAPUserDefaultsStorage`, `IAPKeychainStorage`, `IAPMigration`,
      `SwiftUI/IAPViewModel.swift`

**Không kiểm được ở phase này** — người tích hợp đầu tiên phải thử (checklist Phase 2):

- [ ] ~~mua → entitled~~ · ~~reinstall → tự khôi phục~~ · ~~refund → mất quyền~~ ·
      ~~Ask to Buy → `.pending`~~ · ~~timeout → `.timedOut`~~ · ~~intro offer đúng product~~ ·
      ~~consumable không cấp quyền~~ · ~~race mua-trong-lúc-verify~~

## Risk Assessment

| Risk | Signal | Phản ứng |
|---|---|---|
| **R0 — base chưa từng chạy.** Không host app, không test target dùng được (`TEST_HOST` trỏ `TestAds.app` đã không còn trong project; 0 file test). Mọi hành vi ở đây là suy luận từ tài liệu StoreKit | Host đầu tiên tích hợp sẽ là người phát hiện lỗi | Đã chấp nhận có ý thức (D8). Red-team tìm được 4 Critical **chỉ bằng đọc** — phần chỉ lộ lúc chạy vẫn không có gì bắt. README (Phase 2) phải mang checklist đầy đủ |
| Ai đó "đơn giản hoá" mô hình ba trạng thái về lại Bool | `verification` biến mất, `hasVerified` quay lại | Mọi chỗ liên quan đánh dấu `[RT-F1]`; plan.md có mục Red Team Review giải thích vì sao |
| `systemUptime` không chạy khi máy ngủ → debounce lệch | refresh nhiều hơn dự kiến sau khi máy ngủ lâu | Lệch về phía an toàn. Không đổi sang `Date` — `Date` user chỉnh được, debounce sẽ bỏ qua được |
| App nào đó dùng **cả** `IAPService` lẫn `EntitlementService` → hai consumer `Transaction.updates` | transaction bị finish hai lần | Hiện chưa app nào dùng base. Chặn bằng tài liệu (Phase 2). Không chặn được bằng runtime assert vì phải sửa `IAPService` — D4 cấm. Đây là hạn chế đã biết |
| `isEligibleForIntroOffer` sai khi products chưa tải | badge trial biến mất | Mặc định `false`, host vẫn phải kiểm `introductoryOffer != nil` của product cụ thể trước khi in chữ trial |
| Subscriber thấy UI free vài chục ms đầu mỗi lần mở app (hệ quả của việc xoá cache) | user phàn nàn nháy | Đánh đổi đã chấp nhận `[V3]`. Nếu cần sửa: thêm hint như property **tách biệt**, không bao giờ là giá trị khởi tạo của `isEntitled` |
| Ai đó thêm lại cache entitlement vào `UserDefaults` "cho mượt" | xuất hiện key mới trong `init()` | Success criteria có grep chặn. Đọc lại `### Vì sao không còn cache` trước khi thêm |
