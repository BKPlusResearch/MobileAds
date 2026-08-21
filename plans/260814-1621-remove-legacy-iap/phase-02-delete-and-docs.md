---
phase: 2
title: "Xóa layer + docs"
status: completed
completed: 2026-08-15
priority: P1
effort: "6h"
dependencies: [1]
---

# Phase 2: Xóa layer + docs

> **Phase này làm 5 app không build được.** Đó là trạng thái cuối đã chọn (E13),
> không phải tai nạn. Đọc `## Điều quan trọng nhất` trong plan.md trước khi chạy.

## Overview

Xoá 1279 dòng khỏi pod, dọn docs từ "hai layer" về một layer, bump major, và bàn
giao cho người migrate 5 app sau.

Bản trước của phase này có điều kiện vào là "cả 5 app build sạch". Điều kiện đó
không còn — user đã bỏ 4 phase migrate và sẽ tự làm sau.

## Requirements

**Functional**
- Xoá 9 file layer cũ.
- Docs không còn mô tả pod như có 2 layer IAP.
- Podspec `2.0.0`.
- Branch/PR description cảnh báo rõ 5 app đang vỡ, kèm link Migration notes.

**Non-functional**
- Pod build sạch iOS 15 sau khi xoá.
- **Không merge** vào `new-MobileAds` hay `develop` (E8).

## Related Code Files

- Delete: `MobileAds/IAP/IAPService.swift` (247), `IAPService+Subscription.swift` (177),
  `IAPService+Receipt.swift` (181), `IAPModels.swift` (257),
  `IAPProductIdentifiable.swift` (17), `IAPKeychainStorage.swift` (184),
  `IAPUserDefaultsStorage.swift` (81), `IAPMigration.swift` (37)
- Delete: `MobileAds/SwiftUI/IAPViewModel.swift` (98)
- Modify: `MobileAds.xcodeproj/project.pbxproj` — gỡ file reference
- Modify: `MobileAds/SwiftUI/AppOpenModifier.swift` — doc comment bỏ nhắc layer cũ
- Modify: `README.md` — bỏ mục legacy; bỏ cảnh báo "đừng trộn 2 layer" (hết nghĩa);
  thêm mục "app cũ migrate thế nào" trỏ về Migration notes
- Modify: `docs/codebase-summary.md`, `docs/system-architecture.md`, `docs/code-standards.md`
- Modify: `MobileAds.podspec` — `2.0.0`, sửa `spec.description`

## Implementation Steps

1. **Điều kiện vào** — kiểm cả 3, thiếu một là dừng:
   - P0 xong: branch đã rebase, không repo nào còn `:path`, danh sách consumer đã chốt
   - P1 xong: `onUnfinished` hoạt động, pod build sạch
   - Migration notes trong plan.md đã đầy đủ cho cả 5 app

2. Ghi SHA của pod (rollback).

3. Grep lần cuối tìm consumer bị sót:
   `grep -rn "pod 'MobileAds'" --include=Podfile ~/work_space/BKPlus`
   rồi với mỗi repo grep 5 symbol. Ra repo lạ → dừng, cập nhật Migration notes trước.

4. Xoá 9 file. Gỡ reference khỏi `project.pbxproj` (dùng `xcodeproj` gem, như plan
   trước đã dùng để thêm).

5. Build pod. Sửa chỗ gãy trong pod (dự kiến chỉ doc comment `AppOpenModifier`).

6. `grep -rn "IAPService\|IAPViewModel\|IAPProductIdentifiable\|IAPError\|ProductType" MobileAds/` → 0.

7. Docs: bỏ mọi mô tả 2 layer. Cảnh báo "đừng trộn hai layer" ở 4 chỗ — chỗ thứ tư
   biến mất cùng `IAPViewModel.swift`; 3 chỗ còn lại xoá vì hết nghĩa.
   `docs/code-standards.md`: bỏ `IAPError` khỏi bảng error owner, giữ `EntitlementFailure`.

8. README: thêm mục ngắn "Nâng từ 1.x lên 2.0" trỏ về Migration notes trong plan.
   Người migrate sẽ tìm ở README trước, không phải trong `plans/`.

9. Podspec `2.0.0` + sửa `spec.description` (đang quảng cáo "IAPViewModel
   ObservableObject for reactive purchase state").

10. **Branch/PR description** — ba điểm, điểm đầu phải ở dòng đầu:
    - **Breaking: 5 app hiện không build được** (Silly, xmascall, iOS-ar-sketch,
      ios-themearts, silly-clone). Danh sách + lý do + link Migration notes.
    - **Không merge vào `new-MobileAds` hay `develop`** cho tới khi 5 app migrate xong.
    - Base vẫn chưa kiểm chứng trên thiết bị.

11. Xác nhận issue rotate shared secret (E7') đã mở và còn open. Plan này không đóng nó.

## Success Criteria

- [x] `MobileAds/IAP/` chỉ còn `EntitlementConfig.swift`, `EntitlementOutcome.swift`, `EntitlementService.swift` ✅
- [x] `grep -rn "IAPService\|IAPViewModel\|…" MobileAds/` → **0** (2 doc comment còn sót ở `EntitlementService.swift:10-12` và `AppOpenModifier.swift:15-19` đã viết lại)
- [x] Pod build sạch iOS 15 — BUILD SUCCEEDED, 0 error, sau khi xoá
- [x] `git diff --stat`: **1292 dòng xoá** (1279 của 9 file + 13 của doc comment sửa lại)
- [x] Podspec `2.0.0` — **lệch có chủ ý**: `spec.description` **vẫn nhắc** `IAPViewModel`, nhưng chỉ ở câu thông báo breaking change ("layer has been removed"). Tiêu chí gốc nhắm vào việc *quảng cáo* nó như một tính năng; câu đó đã bỏ. Nói rõ cái gì đã mất là điều người đọc podspec cần nhất
- [x] Docs không còn chỗ nào mô tả 2 layer song song
- [x] `docs/code-standards.md` bảng error owner không còn `IAPError`
- [x] README có mục "Upgrading from 1.x to 2.0" — bảng ánh xạ API + bẫy `isEntitled` bất đồng bộ + trỏ về Migration notes
- [x] **Branch chưa merge vào `new-MobileAds`, `develop`, `ver/swiftUI`** — `feat/remove-legacy-iap` là branch local, chưa push, chưa mở PR
- [ ] Branch/PR description có cảnh báo 4 app vỡ ở dòng đầu — **chưa làm**, chưa push branch nên chưa có PR
- [x] Issue rotate secret còn open — `BKPlusResearch/ios033-gps-camera#1`. Link vào PR khi mở PR
- [x] Rollback: SHA đã ghi — `c3bb450` là base của cả P1 lẫn P2

### Lệch so với kế hoạch

- **P1 và P2 chung một điểm rollback.** Plan đòi mỗi phase một SHA revert riêng, nhưng
  user chốt không commit, nên cả hai phase nằm chung trong working tree trên
  `feat/remove-legacy-iap` @ `c3bb450`. Revert được bằng `git checkout .` nhưng **không
  tách riêng P1 với P2 được**. Commit P1 riêng sẽ khôi phục tính chất đó.
- **Bước 10 (PR description) chưa chạy** vì branch chưa push. Nội dung cảnh báo đã soạn
  sẵn trong plan.md, chỉ còn dán vào khi mở PR.
- **Bước 3 (grep lần cuối tìm consumer)** dùng lại kết quả kiểm kê của P0 — chạy cùng
  ngày, không có repo nào thay đổi ở giữa.

## Risk Assessment

| Risk | Signal | Phản ứng |
|---|---|---|
| **Ai đó merge vào `new-MobileAds` → 3 app vỡ ngay** | PR được approve rồi merge theo thói quen | Bước 10 đặt cảnh báo ở dòng đầu description. E8. Đây là rủi ro số một |
| Consumer thứ 6 lộ ra sau khi xoá | build gãy ở repo không ai nhớ | Bước 3 grep lại. P0 đã chốt danh sách, đây là lần đối chiếu cuối |
| Còn repo `:path` | xoá file là app vỡ tức thì, không đợi merge | Bước 1 kiểm lại kết quả P0 |
| Merge revert ATT/mediation của `new-MobileAds` | ads mất ATT gating | E9 rebase ở P0; kiểm `git log` trước khi merge |
| Migration notes thiếu → người migrate tự dò lại | vài ngày công lặp lại | Bước 1 điều kiện vào. Notes là sản phẩm bàn giao, không phải phụ lục |
| Coi việc gỡ `sharedSecret` là xong chuyện bảo mật | secret vẫn hợp lệ ở Apple | Bước 11. E7' tách rõ: gỡ wiring ≠ rotate |
| 5 app nằm vỡ vô thời hạn | vài tuần trôi qua không ai migrate | Đã chấp nhận (E13). Nhưng nếu kéo dài thì cân nhắc revert P2 và giữ 2 layer |
