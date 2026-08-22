---
title: "Gộp SwiftUI về một nhánh phát hành"
description: "Hợp nhất ver/swiftUI và new-MobileAds thành một dòng phát hành duy nhất, một pod phục vụ cả UIKit lẫn SwiftUI, cắt tag 2.0.0."
status: awaiting-approval
priority: P1
effort: "4h"
tags: [release, swiftui, cocoapods, merge]
created: 2026-08-22
branch: new-MobileAds
---

# Gộp SwiftUI về một nhánh phát hành

> **Ghi chú quy trình:** plan này viết sau khi phase 1–3 đã thực thi. Tôi hỏi
> "viết plan hay làm thẳng" nhưng không chờ trả lời. Phase 4 (push + release)
> chưa chạy, nên plan vẫn còn tác dụng như cổng review trước bước không lùi được.

## Overview

Hai nhánh `new-MobileAds` (UIKit) và `ver/swiftUI` cùng khai `spec.name = "MobileAds"`
và `spec.version = "2.0.0"`. Cắt tag từ cả hai thì `Podfile.lock` của mọi app đều ghi
`MobileAds (2.0.0)` — không phân biệt được bản nào. Đó là vấn đề thật, không phải
chuyện đặt tên tag.

Kết quả mong muốn: **một dòng phát hành duy nhất**, một pod phục vụ cả hai surface,
một tag `2.0.0`.

## Ba dữ kiện định hình plan

**1. Phân kỳ hai chiều, không phải superset.** Mỗi nhánh có thứ nhánh kia thiếu:

| Nhánh | Có mà nhánh kia thiếu |
|---|---|
| `new-MobileAds` | fix `defer { is*Loading = false }` (4 đường load); pin SDK mới (Firebase 12.18, GMA 13.8, Pangle 8.2) |
| `ver/swiftUI` | 7 file `MobileAds/SwiftUI/`; `rewardedInterstitialAdStatusCallback` (~40 dòng); param `loadRewardedAd(showLoading:)` |

**2. Không cần subspec.** `spec.platform = :ios, "15.0"` và mọi type SwiftUI đều
`@available(iOS 15.0, *)` — trùng đúng sàn. Code SwiftUI biên dịch trên mọi target
pod hỗ trợ; app UIKit chỉ là không `import` tới chúng.

**3. Nhiều project đang track `ver/swiftUI` không pin tag.** Đây là ràng buộc nặng
nhất: nhánh đó phải sống tiếp và phải tiến lên được **không cần force-push**.

## Quyết định kiến trúc

**Dùng merge commit thật, không port xuôi chiều.** Ban đầu định port file sang
`new-MobileAds` để tránh nuốt regression. Dữ kiện 3 lật lại: chỉ merge commit hai
parent mới cho phép fast-forward *cả hai* nhánh về cùng một đích mà không viết lại
lịch sử. Đổi lại phải tự tay resolve conflict để hai regression của nhánh SwiftUI
(gỡ `defer`, pin SDK cũ) không lọt vào.

**Giữ `loadRewardedAd(showLoading:)`.** API công khai đã phát hành trên nhánh nhiều
project đang dùng; có thể có app gọi `showLoading: false`. Bỏ = vỡ compile âm thầm.
Giữ = 6 dòng, mặc định `true` nên call site UIKit không đổi.

**`spec.source`/`spec.homepage` → `BKPlusResearch/MobileAds`**, khớp remote `origin`
và README.

## Phases

| # | Phase | Trạng thái |
|---|-------|-----------|
| 1 | [Merge và resolve](phase-01-merge-resolve.md) | done |
| 2 | [Compile layer SwiftUI](phase-02-xcode-target.md) | done |
| 3 | [Sửa app-open + docs](phase-03-appopen-docs.md) | done |
| 4 | [Push và release](phase-04-release.md) | **chờ duyệt** |

## Acceptance criteria

- [x] Một commit là hậu duệ của cả hai nhánh; cả hai ff được, không force-push
- [x] Pin SDK mới thắng; cả 4 fix `defer` còn nguyên
- [x] 7 file SwiftUI nằm trong target Xcode và thực sự sinh `.o`
- [x] `xcodebuild` xanh trên đúng commit được tag
- [x] Podspec: 20 dependency không nhân đôi, có `SwiftUI` trong `spec.frameworks`
- [x] README + `docs/` mô tả đúng code đang chạy
- [ ] Push hai nhánh + tag `2.0.0`
- [ ] Báo các project đang track `ver/swiftUI` chuyển sang pin tag

## Non-goals

- Nhánh `ver/spm`, `feature/spm-support` — bỏ qua, user xác nhận
- Làm `setEnableShowAds` có hiệu lực pod-wide — xem Open items
- Demo target hay test runtime cho layer SwiftUI

## Rủi ro

| Rủi ro | Xử lý |
|---|---|
| App track `ver/swiftUI` nhận loạt SDK bump ở `pod update` kế tiếp | Đã ghi trong deployment-guide; cần báo trước khi push |
| Layer SwiftUI chưa từng compile trong repo | Phase 2 đưa vào target; build xanh |
| Nuốt regression khi merge | Resolve tay, verify bằng grep `defer` + đếm dependency |

## Open items

1. **`setEnableShowAds` không có hiệu lực ở mọi đường UIKit.** Pod chỉ lưu cờ; chỗ
   duy nhất đọc là modifier app-open SwiftUI. App set cờ rồi tưởng đã tắt ads cho
   user premium thì user vẫn thấy quảng cáo. Sửa là đổi hành vi diện rộng — gộp vào
   `2.0.0` hay để `2.1.0`?
2. Layer SwiftUI không có coverage runtime.
