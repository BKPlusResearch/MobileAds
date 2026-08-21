---
phase: 0
title: "Kiểm kê + branch topology"
status: completed
completed: 2026-08-14
priority: P1
effort: "6h"
dependencies: []
---

# Phase 0: Kiểm kê + branch topology

> **Đã xong 2026-08-14.** Kết quả đầy đủ ở [`plan.md` § P0 — Kết quả](./plan.md#p0--kết-quả-2026-08-14):
> consumer inventory, branch topology, bảng rollback SHA.
>
> **Bước 3 (rebase) đã bị RÚT, không thực hiện.** Tiền đề của nó sai: `feat/entitlement-base`
> **không** thiếu ATT-before-SDK-init, background guard, mediation adapter hay podspec
> pins — `git patch-id` cho thấy `033b839`≡`3db0fdf`, `0ba1adc`≡`8b058df`,
> `de31b9e`≡`d6bb5fb`, và 20 dòng `spec.dependency` trùng **từng byte** ở cả hai nhánh.
> Khoảng cách `8 17` là khoảng cách **SHA**, không phải nội dung. Thay vào đó: tag
> `1.4.0` tại `c3bb450`, giữ nguyên lịch sử PR #3. Xem E9/E9' trong plan.md.
>
> Bước 5 dùng **tag** pin thay vì branch pin (E11'): branch còn di chuyển được, tag thì không.

> Phase này tồn tại vì red-team: bản đầu để việc kiểm kê consumer ở **cuối** plan,
> tức sau khi đã xoá file. Lúc đó phát hiện thiếu một app thì đã muộn. Nó phải ở đầu.

## Overview

Đếm lại toàn bộ consumer của pod, đưa branch pilot về trạng thái dùng được, và
cắt mọi `:path` thành branch pin. Không sửa một dòng code app nào.

## Requirements

**Functional**
- Danh sách consumer đầy đủ, có bằng chứng, không dựa vào con số của plan trước.
- Branch pilot chứa mọi commit của `new-MobileAds`.
- Không repo nào còn trỏ `:path` vào working tree của pod.
- Chốt branch topology: base branch, thứ tự merge với PR #3, đích merge cuối.

**Non-functional**
- Không đổi hành vi app nào.
- Ghi SHA trước-khi-sửa của mọi repo bị chạm.

## Architecture

Ba việc độc lập, làm được song song:

```
A. Kiểm kê consumer      →  danh sách app phải migrate (kỳ vọng: 5)
B. Rebase branch pilot   →  feat/entitlement-base ⊇ new-MobileAds
C. Cắt :path             →  4 repo trỏ branch pin
```

## Related Code Files

- Modify: `ios-themearts/AppTheme/Podfile:32` — `:path` → branch
- Modify: `ios013-blood-pressure/Exoventra/Podfile:13` — `:path` → branch
- Modify: `ios035-wifi-location/Zorvanta/Podfile:9` — `:path` → branch
- Modify: `ios033-gps-camera/GPS Camera/Podfile:11` — `:path` → branch
- Modify: `MobileAds` branch `feat/entitlement-base` — rebase
- Create: mục "Consumer inventory" trong plan.md (cập nhật bảng evidence nếu lệch)

## Implementation Steps

1. **Kiểm kê consumer.** Chạy và ghi kết quả vào plan:

   ```bash
   cd ~/work_space/BKPlus
   grep -rn "pod 'MobileAds'" --include=Podfile . | grep -v "^./MobileAds/"
   for d in */; do
     n=$(grep -rl "IAPService\|IAPViewModel\|IAPProductIdentifiable\|IAPError\|ProductType" \
          "$d" "--include=*.swift" 2>/dev/null | grep -v Pods | wc -l)
     [ "$n" -gt 0 ] && echo "$d: $n file"
   done
   ```

   Phân loại mỗi repo: **dùng IAP của pod** (phải migrate) / **chỉ dùng ads**
   (chỉ bị ảnh hưởng qua `:path`) / **không dùng pod**.

   Kỳ vọng theo scout hiện tại: 5 app phải migrate sau (Silly, xmascall,
   iOS-ar-sketch, ios-themearts, silly-clone). Ra khác — dừng và báo, đừng tự điều
   chỉnh plan; con số này là đầu vào của Migration notes và của cảnh báo trên branch.

2. **Trả lời unresolved question #2**: silly-clone sống hay chết. Sống → nó là app
   thứ 5 phải migrate sau, ghi vào Migration notes. Chết → pin `fbsdk` vào tag
   pre-2.0.0 và bớt được một app.

3. **Rebase branch pilot** (E9):

   ```bash
   cd ~/work_space/BKPlus/MobileAds
   git log --oneline feat/entitlement-base..new-MobileAds   # phải rỗng khi xong
   git rebase new-MobileAds feat/entitlement-base
   ```

   Kỳ vọng conflict ở `MobileAds.podspec` (version) và có thể ở `README.md`.
   Sau rebase: build pod sạch iOS 15, và `AdMobHelper*.swift` phải khớp
   `new-MobileAds`.

4. **Chốt branch topology.** Ghi vào plan.md một mục mới, trả lời rõ:
   - Branch làm việc của plan này tách từ đâu (đề xuất: từ `feat/entitlement-base`
     sau rebase).
   - PR #3 merge trước hay sau plan này.
   - Đích merge cuối cùng (`new-MobileAds`? `develop`?).
   - `develop` là default branch và vẫn mang layer cũ — xoá có với tới đó không.

5. **Cắt `:path`** (E11). Mỗi repo trong 4 repo: đổi sang
   `:git + :branch => '<branch pilot>'`, `pod install`, build sạch.

   Làm việc này **trước** mọi thay đổi ở pod, nếu không mỗi lần checkout là đổi
   source dưới chân 4 app.

6. **Ghi SHA** của mọi repo bị chạm vào một bảng trong plan.md, cho rollback.

## Success Criteria

- [x] Bảng consumer inventory trong plan.md, mỗi dòng có bằng chứng `file:line` — 11 repo, gồm cả 3 false positive đã loại
- [x] Câu hỏi silly-clone đã có trả lời — không phải git repo; giữ ở trạng thái at-risk
- [x] ~~`git log --oneline feat/entitlement-base..new-MobileAds` → rỗng~~
      **Rút cùng bước 3.** Thay bằng kiểm tương đương **nội dung**: 20/20 `spec.dependency` trùng byte ✅
- [x] ~~Pod build sạch iOS 15 sau rebase~~ — không rebase nên không áp dụng. 4 app consumer build sạch (dưới) là bằng chứng mạnh hơn
- [x] ~~`git diff feat/entitlement-base new-MobileAds -- MobileAds/AdMobHelper/` → rỗng~~
      **Tiêu chí này sai từ đầu**: entitlement-base có thêm `showLoading` + delegate fixes (+26/−4) một cách chính đáng. Rỗng nghĩa là đã mất công việc đó
- [x] `grep … ":path => '…/MobileAds'" | grep -v '^\s*#'` → 0 ✅ (3 dòng còn lại đã comment, vô hại)
- [x] 4 repo vừa đổi Podfile đều build sạch — xem bảng dưới
- [x] Mục branch topology trả lời đủ 4 câu ở bước 4 ✅
- [x] Bảng SHA rollback có đủ mọi repo bị chạm ✅

### Kết quả build sau khi đổi pin

| Repo | `pod install` | Build |
|---|---|---|
| ios033-gps-camera | `MobileAds 1.4.0 (was 1.3.0)` | ✅ BUILD SUCCEEDED, 0 error |
| ios-themearts | `MobileAds 1.4.0 (was 1.3.0)` | ✅ BUILD SUCCEEDED, 0 error |
| ios013-blood-pressure | `MobileAds 1.4.0 (was 1.3.0)` | ✅ BUILD SUCCEEDED, 0 error |
| ios035-wifi-location | `MobileAds 1.4.0 (was 1.3.0)` | ✅ BUILD SUCCEEDED, 0 error |

`xcodebuild -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO`.
ios-themearts là repo `:path` **duy nhất** thực sự dùng IAP của pod — build sạch của
nó xác nhận tag `1.4.0` vẫn còn nguyên layer cũ, đúng như mong đợi.

## Risk Assessment

| Risk | Signal | Phản ứng |
|---|---|---|
| Rebase đẻ conflict lớn ở AdMobHelper | conflict nhiều file ads | Ưu tiên giữ bản `new-MobileAds` (nó đang chạy production); chỉ giữ phần Entitlement từ branch kia |
| Kiểm kê ra app thứ 6 | grep trả repo lạ | Dừng, báo, ước lượng lại. Đừng nhét thêm phase một cách âm thầm |
| Đổi `:path` làm 4 app kia gãy | build fail sau `pod install` | Đó chính là lý do làm ở P0 — rẻ nhất lúc chưa sửa gì |
| Branch topology không quyết được vì phụ thuộc người khác | bước 4 treo | Đây là blocker thật. Báo, đừng đoán rồi đi tiếp |
| Rebase xong quên `pod install` ở các app | app build bằng pod cũ, kết quả test vô nghĩa | Bước 5 bắt build lại từng repo |
