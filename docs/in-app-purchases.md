# MobileAds — In-App Purchases

**⚠️ Requirements:** iOS 15.0+ (StoreKit 2)

`EntitlementService` là layer IAP **duy nhất** của pod. Layer `IAPService` cũ đã bị **gỡ ở 2.0.0** — xem [Nâng cấp từ 1.x lên 2.0](#nâng-cấp-từ-1x-lên-20).

Entitlement được suy ra từ `Transaction.currentEntitlements` ở **mỗi lần check**, nên cài lại app, đổi máy, refund, grace period và Family Sharing đều do StoreKit lo, không phải do local storage. Layer này generic: nó không giữ product ID nào của riêng nó và không bao giờ hiện UI — app tự cấu hình và tự dựng paywall.

Layer này dùng chung cho cả UIKit lẫn SwiftUI. Phần ads: [ads-uikit.md](ads-uikit.md) ·
[ads-swiftui.md](ads-swiftui.md). Phần dùng chung: [README](../README.md).

> **Trạng thái: chưa verify trên máy thật.** Layer này viết theo tài liệu StoreKit 2, chưa app nào chạy. Nó đã qua một lượt red-team và một lượt code review, cả hai đều tìm ra lỗi thật chỉ bằng đọc code — nên cứ giả định các lỗi chỉ lộ ra lúc runtime vẫn còn nguyên. Repo không có StoreKit test configuration, nên checklist bên dưới là biện pháp kiểm soát duy nhất đang có. **Nếu bạn là người tích hợp đầu tiên, hãy chạy nó và báo lại kết quả.**

## Mục lục

- [1. Configure](#1-configure--một-lần-trước-bootstrap) · [2. Bootstrap](#2-bootstrap-lúc-launch) ·
  [3. Refresh](#3-refresh-khi-vào-foreground) · [4. Đọc state](#4-đọc-state) ·
  [5. Purchase & Restore](#5-purchase--restore)
- [Năm cái bẫy](#năm-cái-bẫy) · [Consumables](#consumables--bắt-buộc-phải-cấp-onunfinished) ·
  [Checklist sandbox](#checklist-sandbox-cho-người-tích-hợp-đầu-tiên) ·
  [Nâng cấp từ 1.x lên 2.0](#nâng-cấp-từ-1x-lên-20)

## 1. Configure — một lần, trước `bootstrap()`

```swift
EntitlementService.shared.configure(
    EntitlementConfig(productIDs: ["your.weekly", "your.yearly"],
                      subscriptionGroupID: "your_group")
)
```

`productIDs` là bắt buộc, không có default. Không có chế độ "để rỗng nghĩa là chấp nhận tất cả": `currentEntitlements` còn phát ra cả consumable chưa finish và non-renewing đã hết hạn, nên một tập rộng rãi sẽ khiến gói xu cấp quyền vĩnh viễn.

Nếu product ID lấy từ Remote Config, **fetch trước rồi mới configure** — service không quyết định gì cho tới khi được configure, và nó từ chối bị configure lần thứ hai.

## 2. Bootstrap lúc launch

```swift
EntitlementService.shared.bootstrap()   // KHÔNG async — cố ý
```

Hàm này trả về ngay để frame đầu tiên không bao giờ phải chờ StoreKit. Hãy quan sát `verification` thay vì `await` bất cứ thứ gì.

## 3. Refresh khi vào foreground

```swift
await EntitlementService.shared.refresh()             // có sẵn debounce 30s
await EntitlementService.shared.refresh(force: true)  // bỏ qua debounce
```

Chỉ dùng `force: true` khi có sự kiện thật sự đổi entitlement mà không đi qua
`purchase()` / `restore()` — ví dụ user vừa quay về từ màn quản lý subscription
của App Store. Gọi `force` theo nhịp polling là tự bỏ đi lớp chống spam StoreKit.

## 4. Đọc state

`EntitlementService` là `@MainActor ObservableObject`. App host UIKit thì đường chuẩn là sink `@Published` bằng Combine:

```swift
import Combine

final class PremiumGate {
    static let shared = PremiumGate()
    private var bag = Set<AnyCancellable>()

    /// Gate phải phân biệt được "chưa premium" và "chưa biết".
    var state: (isPremium: Bool, isKnown: Bool) {
        let s = EntitlementService.shared
        return (s.isEntitled, s.verification == .verified)
    }

    func start() {
        EntitlementService.shared.$isEntitled
            .removeDuplicates()
            .sink { isEntitled in
                // Pod không có cờ bật/tắt ads. App tự gate call site bằng `state`
                // ở trên — xem README: "Tắt ads cho user premium".
                if isEntitled { AdMobHelper.shared.clearAllAds() }
                NotificationCenter.default.post(name: .premiumStatusDidChange, object: nil)
            }
            .store(in: &bag)
    }
}
```

Nếu app host là SwiftUI, quan sát trực tiếp:

```swift
@ObservedObject private var entitlements = EntitlementService.shared

if entitlements.verification == .verified && entitlements.isEntitled {
    PremiumContent()
} else {
    FreeContent()
}
```

| Property | Ý nghĩa |
|---|---|
| `verification` | `.pending` / `.verified` / `.timedOut` — StoreKit đã trả lời chưa? |
| `isEntitled` | Đang giữ một product đã configure. Chỉ có nghĩa khi đã `.verified` |
| `activeProductID` | Product nào đang cấp quyền |
| `expiryDate` | `nil` với lifetime/non-consumable — **`nil` không phải là "đã hết hạn"** |
| `isIntroOfferEligible` | `false` cho tới khi catalog load xong và eligibility có kết quả. Vẫn phải check `introductoryOffer` của đúng product trước khi in chữ về trial |
| `products` | `Product` đã load, key theo ID; `displayPrice(for:)` để lấy giá đã localize |
| `shouldProactivelyPromptRestore` | Có nên *chủ động gợi ý* restore — **không phải** có nên hiện nút |

## 5. Purchase & Restore

```swift
switch await EntitlementService.shared.purchase("your.yearly") {
case .purchased(let receipt):
    // KHÔNG credit consumable ở đây — `onUnfinished` đã được mời transaction này
    // và là nơi duy nhất để credit. Xem mục "Consumables".
    dismissPaywall()
case .cancelled:        break
case .pending:          showAwaitingApprovalMessage()   // Ask to Buy — không phải lỗi
case .failed(let why):  log(why)
}

switch await EntitlementService.shared.restore() {
case .restored:          dismissPaywall()
case .nothingToRestore:  showNothingToRestore()
case .cancelled:         break                          // user tắt sheet đăng nhập — không phải lỗi
case .failed(let why):   showError(why)
}
```

## Năm cái bẫy

1. **Chỉ mở khoá khi `verification == .verified`.** `.pending` nghĩa là *chưa biết*; `.timedOut` nghĩa là StoreKit không trả lời trong 5s. **Mặc định khuyến nghị khi `.timedOut`: coi user là free và hiện quảng cáo.** Cách này ưu tiên doanh thu; cái giá là người đã mua đang ở mạng kém sẽ thấy quảng cáo vài giây cho tới khi `verify()` trả lời, rồi quảng cáo biến mất. Chỉ chọn khác nếu có lý do.
2. **Không cache ở bất cứ đâu.** Không có entitlement nào được lưu, không có state "lần cuối biết". `isEntitled` là `false` cho tới khi verify xong, kể cả với người đã mua từ lâu. **Đừng thêm cache ở phía app để làm mượt chỗ này** — đó chính xác là khuyết tật của layer 1.x đã bị gỡ, và là lý do nó bị gỡ.
3. **Với `@Observable` (iOS 17+), phải mirror — đừng forward.** `var isPremium: Bool { base.isEntitled }` compile được nhưng UI **không bao giờ update**, vì `@Observable` không theo dõi `objectWillChange` của một `ObservableObject`. Hãy sink các `@Published` vào stored property.
4. **Mỗi app chỉ một `Transaction.updates` listener.** Layer này đang chạy một cái. Nếu app còn giữ listener riêng — subscription tracker, analytics observer — hai bên sẽ finish transaction của nhau và trôi lệch nhau. Hãy bỏ listener của app, hoặc đưa nó qua `onUnfinished`.
5. **Nút Restore phải luôn hiện.** `shouldProactivelyPromptRestore` chỉ trả lời "có nên chủ động gợi ý không". Lấy cờ đó để ẩn chính cái nút là đường thẳng tới việc bị reject theo Guideline 3.1.1. Gọi `markRestorePrompted()` sau khi bạn đã hiện UI gợi ý của mình.

## Consumables — bắt buộc phải cấp `onUnfinished`

App chỉ bán subscription hoặc non-consumable có thể dừng đọc ở đây. App bán gói xu, credit, hay lượt chơi **bắt buộc** phải cấp `onUnfinished`, nếu không sẽ thu tiền khách mà không giao hàng.

**Vì sao credit ở chỗ `purchase()` trả về là không đủ.** Rất dễ nghĩ rằng cứ credit xu ngay chỗ `purchase()` trả về là xong. Nhưng StoreKit giao consumable qua `Transaction.updates` — nơi không có lời gọi `purchase()` nào đang chờ — trong ít nhất bốn tình huống bình thường:

- app bị kill hoặc crash giữa lúc trả tiền và lúc giao hàng;
- Ask to Buy được phụ huynh duyệt vài phút hoặc vài ngày sau;
- giao dịch bắt đầu từ máy khác cùng Apple ID;
- lần giao hàng trước bị gián đoạn.

Ở cả bốn trường hợp, library thấy một transaction mà app không thấy. Không có hook thì nó finish rồi vứt đi. **Consumable không bao giờ vào `currentEntitlements`**, nên khác với subscription, không còn gì để suy ra lại: tiền đã mất và số xu chưa từng tồn tại.

`onUnfinished` phủ **cả hai** đường: `purchase()` cũng mời transaction của nó qua đúng hook đó trước khi finish. Nhờ vậy chỉ có đúng một nơi để credit, và nó bắt được mọi trường hợp.

```swift
EntitlementService.shared.configure(
    EntitlementConfig(
        // SKU xu cũng phải liệt kê ở đây — purchase() từ chối mọi ID không có trong này.
        // Liệt kê KHÔNG khiến chúng cấp premium; verify() lọc consumable
        // theo Transaction.productType.
        productIDs: ["your.weekly", "your.yearly", "your.coins.100"],
        subscriptionGroupID: "your_group",
        onUnfinished: { receipt in
            // Ghi credit TRƯỚC khi return true, và khử trùng lặp theo transactionID.
            await CoinLedger.creditOnce(receipt.transactionID, productID: receipt.productID)
        }
    )
)
```

Hợp đồng, và từng dòng đều gánh việc:

| Quy tắc | Không làm thì hỏng thế nào |
|---|---|
| Ghi credit **trước** khi return `true` | Crash giữa hai bước là bạn vừa tái tạo lại đúng cái mất mát mà hook này sinh ra để chặn |
| Khử trùng lặp theo `receipt.transactionID` | StoreKit giao lại; credit theo từng lần giao sẽ credit gấp đôi |
| **Chỉ** credit ở đây | Mọi consumable được mời qua hook này đúng một lần, kể cả cái mua ở foreground qua `purchase()`. Credit thêm ở chỗ `purchase()` trả về là credit hai lần |
| Ghi credit phải atomic | Read-then-write qua một actor hop, hoặc vào `UserDefaults` App Group dùng chung với widget, sẽ mất credit khi ghi đồng thời |
| Chỉ return `false` khi ghi **thật sự** thất bại | Đây không phải kênh báo lỗi. `false` vĩnh viễn nghĩa là giao lại vĩnh viễn |

Hook cố ý **không** được gọi cho:

| Không gọi cho | Vì sao |
|---|---|
| Subscription và non-consumable | Entitlement suy lại được từ `currentEntitlements`, finish chúng không mất gì. Nếu hook thấy cả renewal, một app return `false` cho product nó không nhận ra sẽ kẹt renewal đó trong vòng giao lại vĩnh viễn |
| Transaction đã revoke / refund | Giao hàng cho một đơn đã hoàn tiền là cho không. `refresh()` vẫn chạy nên entitlement vẫn rớt đúng |
| Transaction verify thất bại | Chấp nhận chúng là giao hàng dựa trên bằng chứng không kiểm chứng được |

**Lỗ hổng đã biết:** vì dòng cuối bảng trên, một consumable đã bị tính tiền nhưng không verify được thì vẫn mất. Bịt đúng chỗ này cần server-side receipt validation, thứ library không làm.

Hai hành vi nên biết:

- **Transaction đến trước `configure()` được để nguyên chưa finish**, không bị vứt, và sẽ được thử lại sau khi app configure. Finish chúng là không thể cứu vãn.
- **`bootstrap()` mời lại mọi thứ còn chưa finish** từ các phiên trước, nên return `false` là thử lại chứ không phải đi một chiều.

## Checklist sandbox cho người tích hợp đầu tiên

| # | Trường hợp | Kỳ vọng |
|---|---|---|
| 1 | Mua | Có quyền ngay, UI update không cần restart |
| 2 | Kill rồi mở lại | Vẫn có quyền |
| 3 | Xoá app, cài lại, không bấm gì | Có quyền trong ~1s |
| 4 | Refund qua StoreKit Transaction Manager | Mất quyền sau khi refresh |
| 5 | Ask to Buy | Outcome `.pending`, không phải lỗi |
| 6 | Đăng nhập Apple ID khác | Mất quyền |
| 7 | Restore ở trường hợp 6 | Hiện prompt đăng nhập |
| 8 | Airplane mode, máy **đã** verify trước đó | Vẫn có quyền — `currentEntitlements` đọc từ transaction cache trên máy của StoreKit |
| 9 | Airplane mode + **cài mới** | `verification` thành `.timedOut` sau 5s; theo policy mặc định thì app hiện quảng cáo |
| 10 | Non-consumable / lifetime | Có quyền vĩnh viễn, `expiryDate` là `nil` |
| 11 | **Consumable** (nếu app có bán) | **Không** cấp entitlement, nhưng `purchase()` vẫn trả `.purchased(receipt)` |
| 12 | **Intro offer** — 2+ product, chỉ một cái có trial | `isIntroOfferEligible` trả lời đúng product, nhất quán qua các lần chạy |
| 13 | **Mua trong lúc một verify đang bay** | Không bị mất quyền sau khi mua xong |
| 14 | **Lần launch thứ hai với tư cách người đã mua** | UI free vài chục ms rồi mới premium. Báo lại nếu cái nháy đó khó chịu |
| 15 | **Subscription group mà không product nào có intro offer** | `isIntroOfferEligible` giữ nguyên `false` — không bao giờ gắn badge trial lên gói tính tiền ngay |
| 16 | **Launch offline, nối mạng lại, mở paywall ngay** (trong debounce 30s) | **Tất cả** giá đều hiện và `purchase()` chạy được. Mua một gói không được làm các gói còn lại mất giá suốt phiên |
| 17 | **Consumable mua ở foreground** (chỉ app bán consumable) | `onUnfinished` chạy một lần; xu được credit một lần; `purchase()` trả `.purchased(receipt)` |
| 18 | **Consumable, app bị kill giữa lúc mua** | Xu được credit ở lần launch kế qua `onUnfinished`, đúng một lần |
| 19 | **Consumable qua Ask to Buy, duyệt sau khi mở lại app** | Xu được credit khi duyệt về, đúng một lần |
| 20 | **`onUnfinished` return `false`** | Transaction KHÔNG finish; được mời lại ở `bootstrap()` kế |
| 21 | **Refund một consumable qua StoreKit Transaction Manager** | `onUnfinished` **không** chạy lại; không credit thêm xu |
| 22 | **Subscription renew trong khi có `onUnfinished`** | Hook **không** chạy; renewal finish; `expiryDate` update |
| 23 | **Transaction đến trước `configure()`** | Để nguyên chưa finish, rồi được credit sau `configure()` + `bootstrap()` |

Trường hợp 3 chính là lý do layer này tồn tại. Trường hợp 11–13 là lỗi do lượt red-team tìm ra, 15–16 từ lượt code review đầu, và 17–23 từ lượt review của delivery hook 2.0 — mỗi cái là một cách cụ thể làm mất tiền trên giấy; bỏ bớt cái nào là vứt đi giá trị của các lượt review đó. Trường hợp 14 đo cái giá của việc không có cache.

Hai trường hợp nữa cần app hỗ trợ huỷ tác vụ: gọi `refresh()` từ một `Task` bị cancel giữa chừng không được làm người đã mua rớt về free, và gọi `bootstrap()` trước `configure()` phải để `bootstrap()` vẫn dùng được sau đó chứ không kẹt `verification` ở `.pending`.

## Nâng cấp từ 1.x lên 2.0

**2.0.0 đã gỡ layer IAP cũ.** `IAPService`, `IAPProductIdentifiable`, `IAPError`, `ProductType`, cùng phần lưu trữ Keychain/UserDefaults phía sau chúng không còn tồn tại. App đang ở 1.x sẽ không compile với 2.0 cho tới khi migrate. Ở lại 1.x là lựa chọn hợp lệ — pin `:tag => '1.4.0'`.

Vì sao nó bị gỡ: entitlement được đọc từ local storage, nên **premium mất khi cài lại hoặc đổi máy** cho tới khi user tự tìm ra "Restore Purchases", và Ask to Buy bị báo cho user như một lỗi.

Ánh xạ API:

| 1.x | 2.0 |
|---|---|
| `IAPService.shared.hasActiveSubscription()` | `EntitlementService.shared.isEntitled` |
| `IAPService.shared.isSubscriptionActive(for:)` | `EntitlementService.shared.activeProductID == id` |
| `IAPService.shared.getSubscriptionInfo(for:)` | `expiryDate` + `products[id]` |
| `IAPService.shared.fetchProducts(_:)` | `configure()` + `bootstrap()`, rồi đọc `products` |
| `IAPService.shared.purchase(_:)` | `EntitlementService.shared.purchase(id)` → outcome |
| `IAPService.shared.restorePurchases()` | `EntitlementService.shared.restore()` |
| `IAPService.shared.sharedSecret = …` | Đã gỡ. Xoay shared secret là việc riêng — xoá dòng này không làm secret hết hiệu lực |
| `IAPService.shared.validateReceiptWithApple()` | Đã gỡ. Cần validate phía server thì làm ở backend |
| `catch IAPServiceError.purchaseCancelled` | `case .cancelled` |
| `catch IAPServiceError.purchasePending` | `case .pending` |
| `catch let e as IAPServiceError` | `case .failed(let failure)` |
| `IAPProductIdentifiable` / `ProductType` | Tự khai báo phía app; pod không còn vend nữa |

**Cái bẫy sẽ ngốn của bạn một ngày: `isEntitled` không đồng bộ.**
`hasActiveSubscription()` đọc `UserDefaults` nên luôn có câu trả lời ngay lập tức. `isEntitled` là `false` cho tới khi verify xong. **Mọi ad gate và paywall check chạy lúc launch sẽ thấy `false` và hiện quảng cáo cho người đã trả tiền.**

Một shim `-> Bool` không cứu được chuyện này. Gate phải phân biệt được "không premium" và "chưa biết", và phải có thứ gì đó báo cho UI khi câu trả lời về — xem `PremiumGate` ở mục [Đọc state](#4-đọc-state).

Bridge sang RxSwift: sink `$isEntitled`. **Đừng** dùng `objectWillChange` — nó bắn ở `willSet` và không mang giá trị, nên relay luôn chậm một nhịp. Nó compile sạch nên không build check nào bắt được.

Bán consumable? Đọc [Consumables](#consumables--bắt-buộc-phải-cấp-onunfinished) trước khi bắt đầu; ở đó `onUnfinished` là bắt buộc.
