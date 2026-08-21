---
phase: 2
title: "Docs + release"
status: completed
priority: P1
effort: "4h"
dependencies: [1]
---

# Phase 2: Docs + release

> Cập nhật sau red-team 2026-08-14. Chỗ đánh dấu `[RT-Fn]` là sửa theo finding.

## Overview

Base ship ở trạng thái **chưa từng chạy** (R0). Docs vì thế không phải thủ tục —
nó là thứ duy nhất đứng giữa base và người tích hợp đầu tiên. Đặc biệt sau khi
red-team cho thấy 4 Critical tìm được chỉ bằng đọc: phần chỉ lộ lúc chạy vẫn hoàn
toàn không có gì bắt, nên checklist là control duy nhất còn lại.

## Requirements

**Functional**
- README có hướng dẫn tích hợp chạy được, không phải mô tả suông.
- README ghi rõ base chưa qua kiểm chứng, kèm checklist sandbox 14 case.
- **Cảnh báo "không trộn hai layer" phải đặt ở cả ba nơi** host thực sự đọc, không
  chỉ ở mục mới. `[RT-F9]`
- Docs pod nêu rõ hai layer và hạn chế của layer cũ.
- Podspec bump minor.

**Non-functional**
- Theo `documentation-management.md`: sửa surface nhỏ nhất sở hữu nội dung đó.

## Related Code Files

- Modify: `README.md` — mục tích hợp `EntitlementService`
- Modify: `README.md` — **mục ads hiện có** (`:8` quảng cáo `IAPViewModel` như một
  phần của SwiftUI surface) `[RT-F9]`
- Modify: `MobileAds/SwiftUI/AppOpenModifier.swift` — **chỉ doc comment** `:11,:67`
  (`isEnabled: !iapVM.isPurchased`) `[RT-F9]`
- Modify: `MobileAds/SwiftUI/IAPViewModel.swift` — **chỉ doc comment** đầu file `[RT-F9]`
- Modify: `docs/codebase-summary.md` — thêm base vào module IAP
- Modify: `docs/system-architecture.md` — luồng entitlement
- Modify: `docs/code-standards.md` — **bảng type-location mục 8** (`:170`), **không**
  đụng cây thư mục mục 1 `[RT-F12]`
- Modify: `MobileAds.podspec` — `spec.version` (hiện `1.3.0`, `:19`)
- Không tạo `MIGRATION.md` — không app nào phải migrate

**Lưu ý về `[RT-F9]`:** sửa doc comment trong `AppOpenModifier.swift` và
`IAPViewModel.swift` là **thay đổi comment, không phải code** — vẫn giữ nguyên
tinh thần D4 (0 dòng logic bị sửa). Nêu rõ điều này trong mô tả PR để reviewer
không hiểu nhầm là vi phạm D4.

## Implementation Steps

1. **README — hướng dẫn tích hợp.**

   ```swift
   // 1. Cấu hình một lần, TRƯỚC bootstrap. productIDs là bắt buộc.
   EntitlementService.shared.configure(
       EntitlementConfig(productIDs: ["your.weekly", "your.yearly"],
                         subscriptionGroupID: "your_group")
   )

   // 2. Gọi lúc launch. KHÔNG async — không await được, và đó là cố ý.
   EntitlementService.shared.bootstrap()

   // 3. Gọi khi quay lại foreground — có debounce 30s sẵn
   await EntitlementService.shared.refresh()
   ```

   Nếu host lấy product ID từ Remote Config thì phải `configure()` **trước** khi
   `bootstrap()`; base không phán quyết gì khi chưa cấu hình.

2. **README — năm cái bẫy, viết thành mục riêng chứ không giấu trong doc comment:**

   - **Chỉ mở khoá khi `verification == .verified`.** `.pending` nghĩa là chưa biết.
     `.timedOut` nghĩa là StoreKit không trả lời trong 5s. **Khuyến nghị mặc định ở
     `.timedOut`: coi như free và hiện ads.** `[V1]` Ưu tiên doanh thu; cái giá là
     subscriber mạng tệ thấy ads vài giây đầu cho tới khi `verify()` trả lời, rồi
     ads tắt. Host được phép chọn khác, nhưng nếu không có lý do riêng thì theo
     mặc định này. `[RT-F1]`
   - **Base không lưu entitlement ở đâu cả.** Không có cache để đọc, không có
     "trạng thái lần trước". `isEntitled` là `false` cho tới khi verify xong —
     kể cả với subscriber đã trả tiền từ lâu. Đừng cố tự cache lại ở phía host để
     "cho mượt": đó chính là lỗi mà layer cũ mắc phải. `[V3]`
   - **Host dùng `@Observable` (iOS 17+) phải mirror, không forward.**
     `var isPremium: Bool { base.isEntitled }` compile được nhưng UI **không bao giờ
     cập nhật** — `@Observable` không theo dõi `objectWillChange` của
     `ObservableObject`. Phải sink `@Published` vào stored property.
   - **Đừng dùng `EntitlementService` chung app với `IAPService`/`IAPViewModel`.**
     Chỉ cần khởi tạo `IAPViewModel` là `IAPService.shared` được tạo và listener
     `Transaction.updates` của nó bật lên (`IAPService.swift:43-48`,
     `IAPViewModel.swift:35-37`). Hai nguồn sự thật sẽ lệch nhau.
   - **Nút Restore phải luôn hiện.** `shouldProactivelyPromptRestore` chỉ nói "có
     nên chủ động gợi ý", **không** phải "có nên hiện nút". Gate nút Restore bằng
     cờ này là đường thẳng tới rejection 3.1.1. `[RT-F10]`

3. **README — trạng thái và checklist.**

   ```markdown
   > **Trạng thái: chưa kiểm chứng trên thiết bị.** Base viết theo tài liệu
   > StoreKit 2 nhưng chưa app nào chạy nó. Một vòng red-team đã tìm và sửa 4 lỗi
   > Critical bằng cách đọc; các lỗi chỉ lộ lúc chạy thì chưa có gì bắt.
   > Người tích hợp đầu tiên vui lòng chạy checklist dưới đây và báo lại.
   ```

   | # | Case | Kỳ vọng |
   |---|---|---|
   | 1 | Mua | Entitled ngay, UI đổi không cần restart |
   | 2 | Kill + mở lại | Vẫn entitled |
   | 3 | Xoá app, cài lại, không bấm gì | Entitled ≤1s |
   | 4 | Refund (StoreKit Transaction Manager) | Mất quyền sau refresh |
   | 5 | Ask to Buy | Outcome `.pending`, không phải lỗi |
   | 6 | Đăng nhập Apple ID khác | Mất quyền |
   | 7 | Restore ở case 6 | Prompt đăng nhập |
   | 8 | Máy bay, máy **đã** verify trước đó | Vẫn entitled — `currentEntitlements` đọc từ transaction cache của StoreKit trên máy |
   | 9 | Máy bay + **cài mới** | `verification` về `.timedOut` sau 5s; theo mặc định `[V1]` host hiện ads |
   | 10 | Non-consumable / lifetime | Entitled vĩnh viễn, `expiryDate` nil `[RT-F2]` |
   | 11 | **Consumable** (nếu app có bán) | **KHÔNG** cấp quyền; `purchase()` vẫn trả `.purchased` `[RT-F2][RT-F7]` |
   | 12 | **Intro offer** — app có 2+ gói, chỉ 1 gói có trial | `isIntroOfferEligible` trả lời đúng gói, nhất quán qua nhiều lần chạy `[RT-F8]` |
   | 13 | **Mua trong lúc verify đang chạy** | Không mất quyền sau khi mua xong `[RT-F6]` |
   | 14 | **Mở app lần thứ hai (subscriber)** | UI free vài chục ms rồi chuyển sang Premium. Nếu nháy khó chịu thì báo lại — hệ quả đã biết của `[V3]` |

   Case 3 là lý do base tồn tại. Case 8/9 đã sửa lại theo cơ chế thật: máy đã sync
   thì offline vẫn đúng; chỉ cài-mới-offline mới mù. Case 11, 12, 13 là các bug
   red-team tìm ra — bỏ chúng đi là vứt luôn phần giá trị của vòng review. Case 14
   đo cái giá của `[V3]`: nếu nháy nặng thì đó là dữ liệu để cân nhắc thêm lại hint.

4. **`docs/codebase-summary.md` + `docs/system-architecture.md`:** thêm base và
   bảng phân vai:

   | Layer | Dùng khi | Trạng thái |
   |---|---|---|
   | `EntitlementService` | App mới | Khuyến nghị. **Chưa kiểm chứng trên thiết bị** |
   | `IAPService` / `IAPViewModel` | 4 app cũ đang dùng | Giữ nguyên. Entitlement đọc UserDefaults — **mất Premium khi reinstall**, `.pending` báo thành lỗi |

   Mô tả `IAPService` phải nói đúng hạn chế. Docs giấu bug là docs sai.

5. **`docs/code-standards.md` — bảng mục 8, không phải cây mục 1.** `[RT-F12]`
   Mục 1 là cây **thư mục**: `IAP/` chỉ có một dòng, file duy nhất được liệt kê
   trong cả cây là `MobileAds.h`. Thêm file vào đó sẽ phá quy ước và lệch ngay khi
   pod lớn thêm. Chỗ thật sự sở hữu vị trí từng type là bảng mục 8 (`:170`,
   `| IAPError | MobileAds/IAP/IAPModels.swift |`) — thêm `EntitlementService`,
   `EntitlementConfig`, `EntitlementPurchaseOutcome`, `EntitlementRestoreOutcome`,
   `EntitlementVerification`, `EntitlementFailure`.

6. **Podspec:** bump `spec.version` `1.3.0` → `1.4.0` cho đúng vệ sinh.

   Nhưng nói rõ để không ai kỳ vọng sai: **không app nào pin theo version.** Tất cả
   đang dùng `:git + :branch => 'new-MobileAds'` hoặc `:path`. Version bump ở đây
   không giao được gì cho ai — thứ quyết định app nhận code nào là **branch**.

7. **Git — không merge.** `[V4]`

   Base ở nguyên branch `feat/entitlement-base` (tách từ `ver/swiftUI`). **Không mở
   PR vào `ver/swiftUI`, không mở vào `new-MobileAds`.**

   Lý do: code chưa kiểm chứng trên thiết bị (D8). `new-MobileAds` là branch 4 app
   đang kéo về — đẩy code chưa chạy vào đó là đặt cược bằng app người khác.
   `ver/swiftUI` thì không ai kéo, merge vào chỉ để "cho xong".

   Đường đi đúng:

   ```
   feat/entitlement-base  →  app tích hợp đầu tiên trỏ Podfile vào branch này
                          →  chạy checklist 14 case
                          →  pass  →  lúc đó mới bàn merge vào đâu
                          →  fail  →  sửa trên branch, chưa ai bị ảnh hưởng
   ```

   Podfile của người tích hợp đầu tiên:

   ```ruby
   pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git",
                    :branch => 'feat/entitlement-base'
   ```

   Push branch lên remote để người khác trỏ vào được. Mô tả branch (hoặc một PR
   draft dùng làm nơi thảo luận, không merge) nêu ba điểm: (a) chỉ thêm file, 0
   dòng logic sửa ở layer cũ — chỉ doc comment; (b) **chưa kiểm chứng trên thiết
   bị, chưa merge được**; (c) đã qua một vòng red-team + một vòng validate, link
   tới `plan.md`.

8. **Nơi ghi kết quả checklist.** Người tích hợp đầu tiên chạy 14 case xong phải
   có chỗ ghi lại, nếu không thì control duy nhất của R0 bốc hơi. Ghi thẳng vào
   PR draft ở bước 7 dưới dạng bảng tick — không tạo file mới, không tạo issue.

## Success Criteria

- [ ] README có 3 bước tích hợp, **5** cái bẫy, checklist **14** case
- [ ] README nêu khuyến nghị mặc định cho `.timedOut` (coi như free, hiện ads) `[V1]`
- [ ] README nói rõ base không lưu entitlement ở đâu, và cấm host tự cache lại `[V3]`
- [ ] README nói rõ base chưa kiểm chứng — không dùng câu chữ mô tả nó như đã hoạt động
- [ ] Cảnh báo "không trộn hai layer" xuất hiện ở: mục mới trong README, mục ads
      trong README, doc comment `AppOpenModifier.swift`, doc comment `IAPViewModel.swift`
- [ ] `docs/code-standards.md`: bảng mục 8 có 6 type mới; cây mục 1 **không đổi**
- [ ] Docs có bảng phân vai, mô tả đúng hạn chế của `IAPService`
- [ ] `git diff --stat ver/swiftUI..feat/entitlement-base`: file thêm mới trong
      `MobileAds/IAP/`, docs, README, podspec, và **chỉ doc comment** ở 2 file SwiftUI
- [ ] Podspec `1.4.0`, platform vẫn `15.0`
- [ ] Branch `feat/entitlement-base` đã push lên remote; **chưa merge vào đâu** `[V4]`
- [ ] Có PR draft (không merge) làm nơi ghi kết quả checklist, mô tả đủ 3 điểm ở bước 7

## Risk Assessment

| Risk | Signal | Phản ứng |
|---|---|---|
| Docs viết như thể base đã chạy | người tích hợp tin tưởng, ship thẳng production | Bước 3 bắt buộc; reviewer PR kiểm câu chữ này trước tiên |
| Sửa doc comment ở 2 file SwiftUI bị hiểu là vi phạm D4 | reviewer chặn PR | Mô tả PR nêu rõ: comment-only, 0 dòng logic |
| Checklist ghi ra rồi không ai chạy | base nằm im, app sau vẫn tự viết lại | Gắn checklist vào PR của app tích hợp đầu tiên |
| Người sau dùng nhầm `IAPService` vì README vẫn quảng cáo `IAPViewModel` | app mới lại dính bug reinstall | Đó chính là lý do `[RT-F9]` bắt sửa cả mục ads, không chỉ thêm mục mới |
| Case 11/12/13 bị cắt vì "checklist dài quá" | ba bug red-team tìm ra quay lại | Chúng là phần duy nhất còn lại của vòng review sau khi bỏ verify — không cắt |
| Branch nằm im, không ai tích hợp → checklist không bao giờ chạy | vài tuần trôi qua, `feat/entitlement-base` không có commit mới | `[V4]` cố ý chưa merge, nên rủi ro R4 tăng. Cần một app tình nguyện làm người tích hợp đầu tiên — nếu không có, base này chỉ là code chết |
| Ai đó merge sớm vào `new-MobileAds` "cho tiện" | 4 app kéo về code chưa chạy | Bước 7 ghi rõ cấm. Điều kiện merge là checklist pass, không phải là "đã review xong" |
