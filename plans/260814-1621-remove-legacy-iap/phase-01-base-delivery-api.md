---
phase: 1
title: "Base delivery API"
status: completed
completed: 2026-08-15
priority: P1
effort: "8h"
dependencies: [0]
---

# Phase 1: Base delivery API

> Viết lại sau red-team. Bản đầu chỉ trả transaction ID từ `purchase()` và cấm
> delivery callback (E2). Cả 3 reviewer chỉ ra cùng một lỗ: consumable đến từ
> `Transaction.updates` thì host **không thấy transaction nào cả**.

## Overview

Cho host thấy được mọi transaction trước khi base finish nó, và trả bằng chứng
giao dịch từ `purchase()`. Không có bước này thì themearts mất tiền của khách.

## Requirements

**Functional**
- `.purchased` mang `EntitlementPurchaseReceipt`.
- Host cấp `onUnfinished(receipt) async -> Bool`; base gọi **trước** `finish()`,
  ở **cả hai** nhánh của `handle()`, và chỉ finish khi host trả `true`.
- Host không cấp hook → giữ hành vi cũ (finish luôn), để app không bán consumable
  không phải làm gì.

**Non-functional**
- iOS 15 / Swift 5.5. Không `ContinuousClock`, `Duration`, `sleep(for:)`.
- Base vẫn không lưu transaction, không biết app bán gì.
- `EntitlementPurchaseOutcome` vẫn `Equatable`.

## Architecture

```swift
public struct EntitlementPurchaseReceipt: Equatable {
    public let transactionID: String
    public let productID: String
    public let purchaseDate: Date
}

public enum EntitlementPurchaseOutcome: Equatable {
    case purchased(EntitlementPurchaseReceipt)
    case cancelled
    case pending
    case failed(EntitlementFailure)
}
```

`EntitlementConfig` nhận thêm:

```swift
/// Gọi TRƯỚC khi base finish một transaction đến từ `Transaction.updates`.
/// Trả `true` = host đã giao hàng xong, base finish. Trả `false` = base KHÔNG
/// finish, StoreKit sẽ gửi lại lần sau.
///
/// nil = finish luôn. Đúng cho app chỉ bán subscription/non-consumable, vì
/// entitlement derive lại được từ `currentEntitlements`. App bán consumable
/// BẮT BUỘC cấp hook này — consumable không vào `currentEntitlements`, nên
/// finish mà chưa giao hàng là mất vĩnh viễn.
public let onUnfinished: ((EntitlementPurchaseReceipt) async -> Bool)?
```

Ranh giới vẫn giữ: base không giao hàng hộ, không biết coin là gì. Nó chỉ hỏi
"xong chưa?" trước khi đóng sổ.

**Chú ý về `productIDs`:** doc hiện tại nói đó là "tập product **cấp quyền**".
themearts phải bỏ cả consumable vào đó thì `purchase()` mới không từ chối
(`EntitlementService.swift:341`). Bảo vệ duy nhất khi đó là guard
`productType != .consumable` ở `:206`. Phase này phải sửa doc của `productIDs`
cho đúng thực tế, hoặc tách thành hai tập.

## Related Code Files

- Modify: `MobileAds/IAP/EntitlementOutcome.swift` — thêm receipt struct, đổi case
- Modify: `MobileAds/IAP/EntitlementConfig.swift` — thêm `onUnfinished`, sửa doc `productIDs`
- Modify: `MobileAds/IAP/EntitlementService.swift` — `purchase()` dựng receipt; `handle()` gọi hook trước finish
- Modify: `README.md` — mục consumable, cảnh báo finish-trước-khi-giao-hàng

## Implementation Steps

1. Thêm `EntitlementPurchaseReceipt`; đổi `.purchased` sang mang nó.

2. `purchase()`: dựng receipt **trước** `finish()`.

   ```swift
   let receipt = EntitlementPurchaseReceipt(
       transactionID: String(transaction.id),
       productID: transaction.productID,
       purchaseDate: transaction.purchaseDate
   )
   await transaction.finish()
   await refresh(force: true)
   return .purchased(receipt)
   ```

3. `EntitlementConfig`: thêm `onUnfinished`. Vì có closure, struct không còn
   `Equatable` được — kiểm xem có chỗ nào đang dựa vào điều đó không.

4. `handle()`: gọi hook trước finish, **cả hai nhánh**.

   ```swift
   case .verified(let transaction):
       let receipt = EntitlementPurchaseReceipt(...)
       if let hook = config?.onUnfinished {
           guard await hook(receipt) else { return }   // host chưa xong → KHÔNG finish
       }
       await transaction.finish()
       await refresh(force: true)

   case .unverified(let transaction, let error):
       // Không gọi hook: transaction này không đáng tin, giao hàng theo nó là
       // cấp phát miễn phí. Vẫn finish để dứt điểm redelivery.
       await transaction.finish()
   ```

   Nhánh `.unverified` cố ý **không** gọi hook — nhưng doc phải nói rõ hệ quả cho
   app bán consumable, vì đó vẫn là một đường mất hàng đã trả tiền.

5. Sửa doc `productIDs` cho khớp thực tế (nó là tập **mua được**, còn cấp quyền thì
   lọc thêm bằng `productType`).

6. README: mục "Consumable" — base không giao hàng hộ; app bán consumable **bắt
   buộc** cấp `onUnfinished`; chống cộng trùng bằng `transactionID` là việc của
   host; ghi ledger **trước** khi trả `true`.

## Success Criteria

- [x] Pod build sạch iOS 15 — `xcodebuild -scheme MobileAds` → BUILD SUCCEEDED, 0 error
- [x] `handle()` gọi `onUnfinished` trước `finish()` ở nhánh verified — `EntitlementService.swift:253-275`
- [x] Trả `false` từ hook → transaction **không** bị finish — `guard await deliver(receipt) else { return }`, đặt trước `transaction.finish()`
- [x] `onUnfinished == nil` → hành vi y hệt trước — hook nằm trong `if let deliver = config?.onUnfinished`; `nil` thì rơi thẳng xuống `finish()` như cũ
- [x] Receipt dựng trước `finish()` ở cả `purchase()` và `handle()`
- [x] `grep -rnE "ContinuousClock|Duration|sleep\(for:" MobileAds/IAP/Entitlement*.swift` → **0**
- [x] Base vẫn không lưu transaction; `UserDefaults` vẫn chỉ `restorePrompted` (3 hit, đều là `promptedKey`)
- [x] Doc `productIDs` mô tả đúng vai trò thật — nói rõ đây là tập **mua được**, rộng hơn tập **cấp quyền**; nhắc `productType` mới là bảo vệ thật, không phải quy ước đặt tên
- [x] README nói rõ: bán consumable mà không cấp hook = mất hàng — mục "Consumables — you must supply `onUnfinished`", có bảng contract 5 dòng + 3 case sandbox mới (17–19)

### Ghi chú khi implement

- `EntitlementConfig` **chưa từng** khai `Equatable` (bước 3 lo hụt), nên thêm closure
  không phá gì. Grep: không chỗ nào ngoài `EntitlementService` dùng tới nó.
- Chỉ có **1** chỗ dựng `.purchased` trong pod, nên đổi payload không lan ra đâu cả.
- `purchase()` **không** gọi `onUnfinished` — host lấy receipt thẳng từ giá trị trả về.
  Mỗi transaction do đó được giao đúng một lần. README vẫn bắt dedupe theo
  `transactionID` và khuyên cộng ở **một** chỗ, vì `Transaction.updates` không cam kết
  sẽ không phát lại.

## Risk Assessment

| Risk | Signal | Phản ứng |
|---|---|---|
| Hook trả `false` mãi → transaction kẹt, gửi lại vô hạn | log redelivery lặp | Đúng thiết kế của StoreKit. README phải dặn host chỉ trả `false` khi thật sự chưa ghi được ledger |
| Hook throw/treo → listener đứng | không transaction nào được xử lý sau đó | Hook là `async -> Bool`, không `throws`. Cân nhắc bọc timeout — nhưng đừng finish khi timeout |
| Closure trong `EntitlementConfig` phá `Equatable` | compile lỗi chỗ khác | Bước 3 kiểm trước |
| Nhánh `.unverified` vẫn mất hàng | khách trả tiền, verify trượt, không ai giao | Hạn chế đã biết, ghi vào README. Sửa đúng cần server-side, ngoài scope |
| Có người "đơn giản hoá" hook đi cho gọn | `onUnfinished` biến mất | Đây là C1 của red-team. Đọc `## Red Team Review` trước khi động vào |
