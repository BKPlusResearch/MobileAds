---
title: "Remove Legacy IAP"
description: "Sửa lỗ mất consumable trong base, dọn branch/:path, rồi xóa layer IAP cũ khỏi pod. 5 app CỐ Ý để vỡ — chủ repo tự migrate sau."
status: in-progress
priority: P1
effort: "20h"
tags: [iap, storekit, breaking-change]
created: 2026-08-14
branch: feat/remove-legacy-iap
---

# Remove Legacy IAP

## Overview

Ba việc, trong pod: sửa lỗ mất consumable trong `EntitlementService`, dọn branch
topology + `:path`, rồi xóa `IAPService` + `IAPViewModel` + storage layer
(1279 dòng).

Plan tiếp nối của [`260814-1008-entitlement-base`](../260814-1008-entitlement-base/plan.md)
(đã implement, PR #3 draft, chưa merge).

## Điều quan trọng nhất: app sẽ vỡ **khi merge**, và đó là cố ý

> **Cập nhật sau P0/P1/P2 (2026-08-15).** Mục dưới đây viết trước khi thực hiện. Nó vẫn
> đúng về **ý định**, nhưng sai về **thời điểm**:
>
> - Bản gốc: "sau khi P2 chạy xong, 5 app đều không build được."
> - Thực tế: P2 **đã chạy xong** và **không app nào vỡ**. 4 repo `:path` đã pin
>   `:tag => '1.4.0'` ở P0, nên chúng miễn nhiễm; 3 app kia pin `new-MobileAds`, branch
>   này chưa merge vào đó; silly-clone pin `fbsdk`, không đụng tới.
>   Bằng chứng: ios-themearts build sạch trong khi pod working tree đã xoá layer.
> - Vỡ xảy ra **khi merge**, không phải khi xoá. Xem [bán kính ảnh hưởng](#bán-kính-ảnh-hưởng-hiện-tại-sau-p0).
> - Số app phải migrate là **4** (Silly, xmascall, iOS-ar-sketch, ios-themearts) + silly-clone
>   ở trạng thái unknown, không phải 5 chắc chắn.
>
> Hệ quả với E8 **không đổi, và còn quan trọng hơn**: chính vì hiện tại không có gì vỡ,
> rất dễ tưởng nhầm là merge được.

Bản trước của plan này có 4 phase migrate 5 app. **User đã bỏ chúng và sẽ tự
migrate sau.** Hệ quả phải nói thẳng, không được giấu trong risk table:

Sau khi P2 chạy xong, **Silly, xmascall, iOS-ar-sketch, ios-themearts,
silly-clone đều không build được** cho tới khi có người migrate chúng. Đây không
phải rủi ro — đây là trạng thái cuối đã chọn của plan.

Kéo theo hai ràng buộc cứng:

- **Không merge vào `new-MobileAds`** (Silly, xmascall, ar-sketch đang kéo) hay
  `develop` (default branch). Branch của plan này phải nằm riêng cho tới khi 5 app
  migrate xong. Xem E8.
- Mục [Migration notes](#migration-notes--cho-người-migrate-5-app-sau) ở cuối là
  bàn giao. Nó giữ lại bằng chứng mà vòng red-team đã tìm ra; không có nó thì người
  migrate phải tự dò lại từ đầu.

## Bản này viết lại sau red-team

Bản đầu có **8 Critical**. Ba là lỗi thiết kế, không phải chi tiết bỏ sót:

- **E2 sai.** "Base không giao hàng hộ, host tự cộng ở nhánh `purchase()`" — nhưng
  StoreKit giao consumable qua `Transaction.updates` trong ít nhất 4 tình huống
  thường gặp, và ở đó host **không thấy transaction nào cả**. `handle()` finish rồi
  bỏ đi. Tiền đã trừ, coin không bao giờ tồn tại. → P1 sửa.
- **Đếm sai app.** 5 app dùng IAP của pod, không phải 4; 4 repo trỏ `:path` vào
  working tree, không phải 1. → P0 kiểm lại.
- **Branch pilot thiếu 8 commit của `new-MobileAds`**, gồm ATT-before-SDK-init.
  Merge nó là revert ATT. → P0 rebase.

## Bằng chứng nền

Bảng đã sửa sau red-team — bản đầu lệch ~6 số dòng và thiếu 1 app.

| Sự kiện | Bằng chứng |
|---|---|
| **`handle()` finish mọi transaction, không trả gì cho host** | `EntitlementService.swift:253-257` (verified), `:268-273` (unverified — có sẵn comment cảnh báo đúng vấn đề này) |
| `purchase()` finish **trước** khi return | `EntitlementService.swift:371-374` |
| `verify()` loại consumable | `EntitlementService.swift:206` |
| `purchase()` từ chối product ngoài `productIDs` | `EntitlementService.swift:341` |
| **5 app** dùng IAP của pod | Silly, xmascall, iOS-ar-sketch, ios-themearts, **silly-clone** |
| silly-clone là consumer thật, dùng `typealias` | `silly-clone/SillySmile/Helper/IAPService.swift:13`; `AppDelegate.swift:29`; 25 file |
| **4 repo trỏ `:path`** vào working tree của pod | `ios-themearts/AppTheme/Podfile:32`, `ios013-blood-pressure/Exoventra/Podfile:13`, `ios035-wifi-location/Zorvanta/Podfile:9`, `ios033-gps-camera/GPS Camera/Podfile:11` |
| ~~Branch pilot thiếu 8 commit của `new-MobileAds`~~ — **SAI, đã bác ở P0** | `git rev-list --left-right --count` → `8 17` đúng về **SHA**, sai về **nội dung**. `git patch-id`: `033b839`≡`3db0fdf` (ATT), `0ba1adc`≡`8b058df` (background guard), `de31b9e`≡`d6bb5fb` (podspec pins). Mediation: 20 dòng `spec.dependency` **giống hệt từng byte** ở cả hai nhánh. Shim PremiumAds: `d680c16` thêm rồi `c8590ed` xoá → **0 file ở cả hai**. `baa5db0`/`bc1434a` chỉ là `.claude/`+`.agentkit/` |
| `feat/entitlement-base` là **superset nội dung** của `new-MobileAds` | Diff `2953 file / -636898 dòng` **toàn bộ** là AI tooling (`.claude/skills` 2711 file, `plans/`, `release-manifest.json`), do `604e3f7` cố ý gitignore. Swift: `AdMobHelper` **+26/−4 nghiêng về entitlement-base** (`showLoading`, delegate fixes); podspec `1.4.0 > 1.3.0` + `SwiftUI` framework |
| `new-MobileAds` **không có** file `Entitlement*` nào | `git ls-tree -r origin/new-MobileAds \| grep -i entitlement` → rỗng |
| 3 app kéo `new-MobileAds`, 1 app kéo `fbsdk` | `Silly/ios006-silly-smile/Podfile:23`, `xmascall/Podfile:19`, `iOS-ar-sketch/ar-sketch-ios/Podfile:14`, `silly-clone/Podfile:25` |
| `sharedSecret`: **5 site** (không phải 4), và pod **có** đọc | `Silly/.../AppDelegate.swift:29`, `xmascall/.../AppDelegate.swift:45`, `ios-themearts/.../IAPServiceAdapter.swift:34,41`, **`silly-clone/SillySmile/AppDelegate.swift:29`**; đọc tại `IAPService+Receipt.swift:77-78`, khai tại `IAPService.swift:27` |
| clean-phone / ios013 / ios035 / ios033 **không** dùng IAP của pod | grep `IAPService.shared\|IAPProductIdentifiable\|sharedSecret` → 0 hit. Chỉ bị ảnh hưởng qua `:path` |
| Base chưa từng chạy trên thiết bị | `260814-1008-entitlement-base` R0; repo 0 file test, 0 `.storekit` |

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | Base có **kênh giao hàng** cho transaction đến từ `Transaction.updates` — consumable không mất | P1 |
| 2 | Branch topology rõ ràng; không repo nào còn `:path`; không merge nào revert ATT/mediation | P1 |
| 3 | Xóa 1279 dòng khỏi pod, 0 tham chiếu còn sót **trong pod** | P1 |
| 4 | Bàn giao đủ để chủ repo migrate 5 app sau mà không phải dò lại | P1 |

## Non-goals

- **Migrate 5 app** — user tự làm sau. Plan này chỉ bàn giao.
- Server-side receipt validation.
- Rotate shared secret — việc riêng, phải mở issue (E7').
- Đổi sản phẩm/giá/paywall UI của app nào.

## Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| E1 | `.purchased` mang `EntitlementPurchaseReceipt` | Host cần transactionID để giao hàng consumable |
| ~~E2~~ | ~~Không thêm delivery callback vào base~~ | **ĐẢO sau red-team.** Consumable từ `Transaction.updates` thì host không thấy gì. Thay bằng E2' |
| **E2'** | **Base gọi `onUnfinished(receipt) async -> Bool` do host cấp, TRƯỚC `finish()`; chỉ finish khi host trả `true`** | Mức đảo tối thiểu. Base vẫn không biết app bán gì |
| ~~E7~~ | ~~Xóa luôn receipt layer, không port~~ | **Sửa.** Pod **có** đọc `sharedSecret` (`IAPService+Receipt.swift:77-78`) |
| **E7'** | **Xoá wiring ≠ xoá secret.** Rotate ở App Store Connect là việc riêng, phải mở issue | Secret là literal hardcode, còn trong binary đã ship và git history, vẫn hợp lệ ở Apple |
| **E8** | **Không merge vào `new-MobileAds`, `develop`, hay `ver/swiftUI` cho tới khi 4 app migrate xong.** Branch nằm riêng | 3 app kéo `new-MobileAds`; `develop` là default branch; **`ver/swiftUI` là base của PR #3 và là pin của clean-phone** — P0 phát hiện, bản đầu bỏ sót |
| ~~E9~~ | ~~Rebase `feat/entitlement-base` lên `new-MobileAds` TRƯỚC khi làm gì~~ | **RÚT ở P0 — tiền đề sai.** ATT, background guard, mediation, podspec pins **đều đã có** trên branch (patch-id + byte-diff, xem Evidence). Rebase sẽ replay 17 commit gồm cả việc xoá `.claude/` lên `new-MobileAds` và force-push đè head của PR #3, đổi lấy **0 lợi ích chức năng**. User chốt: bỏ rebase |
| **E9'** | **Không đụng `feat/entitlement-base`. Tag `1.4.0` tại `c3bb450` làm điểm pin** | Giữ nguyên lịch sử PR #3. Tag khớp `spec.version` sẵn có nên không phải sửa podspec |
| ~~E11~~ | ~~Mọi `:path` consumer đổi sang **branch** pin~~ | **Sửa: pin sang _tag_, không phải branch.** Branch vẫn di chuyển được; tag thì không |
| **E11'** | **4 repo `:path` pin `:tag => '1.4.0'`** | Miễn nhiễm với mọi force-push/di chuyển branch về sau |
| **E13** | **5 app cố ý để vỡ.** Trạng thái cuối của plan, không phải tai nạn | User quyết. Ràng buộc kéo theo là E8 |

## P0 — Kết quả (2026-08-14)

### Consumer inventory

Grep toàn `~/work_space/BKPlus`, phân loại theo **có dùng IAP của pod hay không**,
không dựa vào con số của plan trước.

| Repo | Pin | Dùng IAP pod? | Bằng chứng |
|---|---|---|---|
| Silly (`ios006-silly-smile`) | `:branch => 'new-MobileAds'` | **Có** | `Podfile:23`; `Helper/IAPService.swift:13` typealias |
| xmascall | `:branch => 'new-MobileAds'` | **Có** | `Podfile:19` |
| iOS-ar-sketch | `:branch => 'new-MobileAds'` | **Có** | `ar-sketch-ios/Podfile:14` |
| ios-themearts | ~~`:path`~~ → **`:tag => '1.4.0'`** | **Có** (consumable) | `AppTheme/Podfile:34` |
| silly-clone | `:branch => 'fbsdk'` | **Có** (danh nghĩa) | `Podfile:25`. **Không phải git repo** — xem dưới |
| ios033-gps-camera | ~~`:path`~~ → **`:tag => '1.4.0'`** | Không | `GPS Camera/Podfile:13`; grep IAP → 0 |
| ios013-blood-pressure | ~~`:path`~~ → **`:tag => '1.4.0'`** | Không | `Exoventra/Podfile:13`; grep IAP → 0 |
| ios035-wifi-location | ~~`:path`~~ → **`:tag => '1.4.0'`** | Không | `Zorvanta/Podfile:11`; grep IAP → 0 |
| iOS-clean-phone-bkplus | `:branch => 'ver/swiftUI'` | Không | Tự khai `IAPViewModel` (`Features/IAP/IAPViewModel.swift:8`), `IAPServiceProtocol`/`IAPServiceImpl` (`Services/IAP/IAPService.swift:14,26`); `MobileAds.IAP*`/`sharedSecret` → 0 hit. **Xác nhận red-team reject là đúng** |
| iOS-screen-mirroring | — | Không | Không có `pod 'MobileAds'`. Hit `ProductType` là type riêng (`PremiumIAPViewModel.swift`) |
| TVChromeCast | — | Không | Không có `pod 'MobileAds'`. `IAPService.swift` là của app, không `import MobileAds` |

**Không có consumer thứ 6.** Hai repo lạ mà grep bắt được (`iOS-screen-mirroring`,
`TVChromeCast`) đều không phụ thuộc pod — false positive do `ProductType`/`IAPError`
là tên chung.

**silly-clone (unresolved question #2):** `git rev-parse` → *fatal: not a git
repository*. Không `.git`, không remote, mtime `2026-05-01`. Là bản chép local,
không migrate qua git được. Nó pin `fbsdk` — branch plan này **không đụng tới** —
nên nó không bao giờ vỡ vì plan này. **User chốt: vẫn giữ trong danh sách ở trạng
thái unknown/at-risk**, phòng khi có remote thật mà máy này không thấy.

### Branch topology (P0 bước 4)

| Câu hỏi | Trả lời |
|---|---|
| Branch làm việc tách từ đâu | `feat/entitlement-base` **nguyên trạng** tại `c3bb450` (không rebase — E9 đã rút) |
| PR #3 trước hay sau | **Không đụng.** Vẫn draft, base `ver/swiftUI`. Plan này không phụ thuộc nó |
| Đích merge cuối | **Chưa có.** Branch nằm riêng vô thời hạn tới khi 4 app migrate xong |
| `develop` có với tới không | **Không.** `develop` là default branch, vẫn mang layer cũ. Ngoài scope |

**PR #3 base là `ver/swiftUI`, không phải `new-MobileAds`/`develop`** — bản đầu bỏ
sót. Và **clean-phone pin đúng `ver/swiftUI`** (`Podfile:13`), nên merge PR #3 sẽ
đẩy `EntitlementService` vào clean-phone. An toàn (clean-phone tự sở hữu IAP của
nó), nhưng phải biết trước. E8 đã thêm `ver/swiftUI` vào danh sách cấm merge.

### Rollback SHA

| Repo / ref | SHA trước khi sửa | Hoàn tác |
|---|---|---|
| `MobileAds` `feat/entitlement-base` | `c3bb450` | Không sửa. Tag local `rollback/pre-rebase-entitlement-base` |
| `MobileAds` tag `1.4.0` | (mới) `4de943f` → `c3bb450` | `git push --delete origin 1.4.0` |
| `MobileAds` `new-MobileAds` | `baa5db0` | Không sửa |
| `MobileAds` `develop` | `86f2b44` | Không sửa |
| `MobileAds` `ver/swiftUI` | `52a9fa7` | Không sửa |
| ios033-gps-camera | `b213ad3` (br `new-MobileAds`) | Podfile + Podfile.lock |
| ios-themearts | `5708b36` (br `feature/widget`) | Podfile + Podfile.lock |
| ios013-blood-pressure | `71e017b` (br `feat/ads-monetization`) | Podfile + Podfile.lock |
| ios035-wifi-location | `d574938` (br `dev/v1.0.2`) | Podfile + Podfile.lock |

Cả 4 repo `:path` đã `pod install` sạch, `MobileAds 1.4.0 (was 1.3.0)`. Chúng
từng khoá ở `1.3.0` dù working tree ở `1.4.0` — tức lần install gần nhất làm khi
pod đang ở nhánh khác. Đổi sang tag vừa cắt `:path` vừa dứt điểm cái lệch đó.

### E7' — issue rotate secret

`BKPlusResearch/MobileAds` **tắt issues** (`gh api` → `has_issues=false`), token
hiện tại có `push` nhưng không `admin` nên không tự bật được. **User chốt: mở issue
ở `BKPlusResearch/ios033-gps-camera`** (issues enabled), body trỏ chéo về pod.

## Success Criteria

- [x] Base: `onUnfinished` được gọi trước `finish()` ở nhánh verified của `handle()`
- [x] Base: trả `false` từ hook → transaction **không** bị finish
- [x] Base: `onUnfinished == nil` → hành vi y hệt trước
- [x] `.purchased` mang receipt; README có ví dụ consumable
- [x] ~~`git log --oneline feat/entitlement-base..new-MobileAds` → rỗng (đã rebase)~~
      **Thay** (E9 rút — tiêu chí cũ đo SHA, không đo nội dung): `git show new-MobileAds:MobileAds.podspec | grep dependency`
      giống hệt bản của `feat/entitlement-base`, và `git diff new-MobileAds feat/entitlement-base -- MobileAds/AdMobHelper/`
      chỉ chứa phần **thêm** của entitlement-base. ✅ Đạt tại `c3bb450` (20/20 dependency trùng byte; AdMobHelper +26/−4)
- [x] `grep -rn ":path => '…/MobileAds'" --include=Podfile ~/work_space/BKPlus | grep -v '^\s*#'` → 0
      ✅ 4 dòng active đã đổi sang `:tag => '1.4.0'`. Còn 3 dòng **đã comment** ở clean-phone/ar-sketch/xmascall — vô hại, ngoài scope
- [x] `MobileAds/IAP/` chỉ còn 3 file `Entitlement*.swift`
- [x] `grep -rn "IAPService\|IAPViewModel\|IAPProductIdentifiable\|IAPError\|ProductType" MobileAds/` → 0
      **Lưu ý pattern:** sau khi sửa C3, `EntitlementOutcome.swift:38,43` có
      `Product.ProductType` — đó là type **của StoreKit**, không phải `ProductType` của pod
      đã xoá. Grep đúng phải là `\bProductType\b` không đứng sau `Product.`, hoặc kiểm 2 hit
      này bằng mắt. Type của pod đã chết thật
- [x] Pod build sạch iOS 15 — trước và sau khi xoá, cả hai BUILD SUCCEEDED
- [x] Podspec `2.0.0`; docs không còn mô tả 2 layer
- [x] **Branch chưa merge vào `new-MobileAds`, `develop`, `ver/swiftUI`** — `feat/remove-legacy-iap` còn local, chưa push
- [ ] PR/branch description nói rõ: 4 app hiện không build được, kèm link Migration notes — **chưa làm**, chờ push branch
- [x] Issue rotate shared secret đã mở, còn open — **BKPlusResearch/ios033-gps-camera#1**
      (repo pod tắt issues). Ghi 5 site assignment, không chứa giá trị secret nào
- [~] Mỗi phase có SHA trước-khi-sửa, revert được bằng một lệnh — **đạt một nửa.** Cả P1
      lẫn P2 cùng base `c3bb450`, revert được bằng `git checkout .`, nhưng **không tách
      riêng P1 với P2**. Nguyên nhân: user chốt không commit. Commit P1 riêng là khôi phục được

## Risks

| # | Risk | Mức | Xử lý |
|---|---|---|---|
| R1 | **Ai đó merge vào `new-MobileAds` → 3 app vỡ ngay** | **Critical** | E8. Branch description phải cảnh báo ngay dòng đầu. Đây là rủi ro số một của plan này |
| R2 | 5 app nằm vỡ vô thời hạn vì không ai migrate | High | Chấp nhận có ý thức (E13). Migration notes là thứ duy nhất giảm được ma sát |
| R3 | ~~4 repo `:path` vỡ khi pod đổi~~ | ~~High~~ **Đóng** | E11' xong ở P0: cả 4 pin `:tag => '1.4.0'`, `pod install` + build sạch. Tag bất biến nên rủi ro này hết hẳn, không chỉ giảm |
| ~~R4~~ | ~~Merge làm revert ATT/mediation~~ | **Bác bỏ** | Tiền đề sai. ATT/background-guard/podspec-pins đã có sẵn trên branch (patch-id), mediation dependency trùng byte. Không có gì để revert. Xem Evidence + E9 |
| **R4'** | Ai đó merge PR #3 vào `ver/swiftUI` mà không biết clean-phone pin nhánh đó | Medium | E8 đã thêm `ver/swiftUI`. Thực tế an toàn (clean-phone tự sở hữu IAP), nhưng phải là quyết định có ý thức |
| R5 | Hook `onUnfinished` bị "đơn giản hoá" đi sau này | High | Đây là C1 của red-team. `## Red Team Review` giải thích vì sao nó tồn tại |
| R6 | Secret vẫn hợp lệ sau khi plan "xong" | High | E7' tách rõ; success criteria bắt mở issue riêng |
| R7 | Migration notes lỗi thời trước khi có người dùng | Medium | Nó ghi `file:line`; người migrate phải grep lại, notes chỉ chỉ đường |
| R8 | Base vẫn chưa từng chạy trên thiết bị | High | Không đổi so với plan trước. Plan này không thêm gate nào vì không app nào migrate |

## Phases

| # | Phase | Status |
|---|-------|--------|
| 0 | [Phase 0: Kiểm kê + branch topology](./phase-00-inventory-and-branch.md) | **Done** (2026-08-14) — rebase bị rút, xem E9 |
| 1 | [Phase 1: Base delivery API](./phase-01-base-delivery-api.md) | **Done** (2026-08-15) |
| 2 | [Phase 2: Xóa layer + docs](./phase-02-delete-and-docs.md) | **Done** (2026-08-15) — trừ bước 10 (PR description), chờ push branch |

Dependency: 0 → 1 → 2.

## P1 + P2 — Kết quả (2026-08-15)

Branch `feat/remove-legacy-iap`, tách từ `c3bb450`. **Chưa commit, chưa push, chưa có PR.**

| Việc | Kết quả |
|---|---|
| `EntitlementPurchaseReceipt` | Thêm mới, `Equatable`, 3 field. `.purchased` mang nó |
| `onUnfinished` | Thêm vào `EntitlementConfig`. `handle()` gọi trước `finish()` ở nhánh verified; `false` → không finish |
| Doc `productIDs` | Viết lại: tập **mua được** ≠ tập **cấp quyền**; `productType` mới là bảo vệ thật |
| Xoá layer cũ | 9 file, **1279 dòng**. `MobileAds/IAP/` còn đúng 3 file `Entitlement*` |
| `project.pbxproj` | 8 file reference gỡ bằng `xcodeproj` gem; 0 dangling |
| Podspec | `1.4.0` → **`2.0.0`**, description viết lại, parse OK |
| Grep 5 symbol trong `MobileAds/` | **0 hit** |
| Pod build iOS 15 | BUILD SUCCEEDED, **0 error** — cả sau P1 lẫn sau P2 |

### Vòng code review — 6 lỗi đã sửa (2026-08-15)

Review sau khi implement tìm 3 Critical + 3 High, **tất cả đã verify lại bằng source
trước khi sửa**, và đã sửa hết.

| # | Lỗi | Sửa |
|---|---|---|
| **C1** | README bảo host cộng coin **chỉ** trong `onUnfinished`, nhưng `purchase()` **không** gọi hook → mua ở foreground là mất tiền. **Lỗi do chính vòng implement này viết ra** | `purchase()` đi qua cùng `deliverIfNeeded()`. Hook thành điểm giao hàng duy nhất **và đủ**. Lời khuyên trong README giờ mới đúng |
| **C2** | `handle()` gọi hook cho cả transaction **đã refund/revoke** → tặng coin cho người đã đòi lại tiền. `verify():202` có guard, `handle()` thì không | Guard `revocationDate == nil` trước khi gọi hook; vẫn `finish()` + `refresh()` |
| **C3** | Hook bắn cho **mọi** product type. Host phòng thủ trả `false` cho renewal → renewal kẹt redelivery vĩnh viễn **và** `refresh()` bị bỏ qua | Hook chỉ gọi cho `.consumable`; thêm `productType` vào receipt; `refresh(force:)` chạy **bất kể** kết quả giao hàng |
| **H2** | Closure không `@Sendable`/`@MainActor` → host viết `nonisolated func` là chạy off-main, Swift 5.5 không cảnh báo | `(@MainActor @Sendable (…) async -> Bool)?`; receipt `Sendable` |
| **H3** | `false` dựa hoàn toàn vào `Transaction.updates` phát lại — Apple không cam kết điều đó | `drainUnfinished()` đọc `Transaction.unfinished` ở cuối `runBootstrap()` |
| **H4** | Transaction đến trước `configure()` bị `finish()` không giao hàng → mất vĩnh viễn | `config == nil` → **không** finish, để redelivery |

Điểm đáng ghi nhớ: **C1 là lỗi tài liệu, không phải lỗi code.** Code làm đúng thiết kế
đã chốt; câu văn trong README mô tả sai thiết kế đó, theo hướng làm mất tiền. Reviewer
bắt được vì đối chiếu README với source thay vì đọc mỗi source.

### Bằng chứng quan trọng nhất: tag pin đã có tác dụng

Pod working tree đang ở `feat/remove-legacy-iap` (layer cũ **đã bị xoá**), mà
**ios-themearts vẫn build sạch** — chính là app dùng layer cũ nhiều nhất (12 file).
`Podfile.lock` của nó vẫn ghi `MobileAds (1.4.0)`.

Đây là thứ mà bản kế hoạch gốc (pin **branch**) sẽ không có: pin branch thì checkout
branch này là đổi source dưới chân themearts ngay lập tức.

## PR / branch description — dán nguyên khối khi push

> **⚠️ BREAKING — KHÔNG MERGE. Branch này xoá layer IAP cũ khỏi pod.**
> Không merge vào `new-MobileAds`, `develop`, hay `ver/swiftUI` cho tới khi 4 app dưới
> đây migrate xong. 3 app đang kéo thẳng `new-MobileAds`; merge vào đó là chúng vỡ ngay
> trong lần `pod install` kế tiếp.
>
> **App phải migrate trước khi dùng được 2.0.0:** Silly (`ios006-silly-smile`), xmascall,
> iOS-ar-sketch, ios-themearts. (silly-clone dùng `fbsdk`, không phải git repo, trạng thái
> unknown.)
>
> **Hướng dẫn migrate:** `plans/260814-1621-remove-legacy-iap/plan.md` → mục *Migration notes*.
> Riêng ios-themearts bán consumable nên **bắt buộc** cấp `onUnfinished`, nếu không mất coin.
>
> **Chưa kiểm chứng trên thiết bị.** `EntitlementService` chưa từng chạy trên máy thật.
> Repo không có test, không có `.storekit`. Checklist 23 case ở README là kiểm soát duy nhất.
>
> **Bảo mật, việc riêng:** BKPlusResearch/ios033-gps-camera#1 — rotate shared secret ở
> App Store Connect. Xoá wiring **không** làm secret hết hiệu lực.

### Bán kính ảnh hưởng hiện tại (sau P0)

Sau khi P0 pin 4 repo vào tag `1.4.0`, **không app nào vỡ ở thời điểm này** — tag bất
biến nên không nhận được thay đổi nào của branch. Rủi ro chỉ hiện thực hoá khi:

| Hành động | Hậu quả |
|---|---|
| Merge vào `new-MobileAds` | Silly, xmascall, iOS-ar-sketch vỡ ngay |
| Merge vào `ver/swiftUI` | clean-phone nhận 2.0 — thực tế an toàn (tự sở hữu IAP) nhưng phải cố ý |
| Merge vào `develop` | Default branch mang bản breaking |
| Ai đó đổi pin của ios-themearts sang branch này | themearts vỡ, và là app bán consumable |

## Migration notes — cho người migrate 5 app sau

Phần này thay cho 4 phase đã bỏ. Mọi dòng đều đã verify bằng grep; số dòng có thể
trôi, grep lại trước khi tin.

### Bề mặt phải thay

| Cũ | Mới |
|---|---|
| `IAPService.shared.hasActiveSubscription()` | `EntitlementService.shared.isEntitled` |
| `IAPService.shared.fetchProducts(_:)` | `configure()` + `bootstrap()`, đọc `products` |
| `IAPService.shared.purchase(_:)` | `EntitlementService.shared.purchase(id)` → outcome |
| `IAPService.shared.restorePurchases()` | `EntitlementService.shared.restore()` |
| `IAPService.shared.sharedSecret = …` | xoá (rotate riêng — E7') |
| `catch IAPError.purchaseCancelled` | `case .cancelled` |
| `catch let e as IAPError` | `case .failed(let f)` |
| `ProductType` (pod) | khai app-side |

`IAPError` (`IAPModels.swift:226`) và `ProductType` (`:30`) chết cùng pod. Grep của
bạn phải gồm cả hai, không chỉ `IAPService`.

### Cái bẫy lớn nhất: `isEntitled` không đồng bộ

`hasActiveSubscription()` đọc `UserDefaults` nên **luôn có giá trị ngay**.
`isEntitled` là `false` cho tới khi verify xong. Mọi chỗ gate ads/paywall đọc lúc
launch sẽ thấy `false` và cho subscriber xem ads.

Không sửa được bằng shim `-> Bool`. Cần hai thứ:

```swift
// Gate phải phân biệt "chưa biết" với "không phải premium"
static func premiumState() -> (isPremium: Bool, isKnown: Bool) {
    MainActor.assumeIsolated {
        let s = EntitlementService.shared
        return (s.isEntitled, s.verification == .verified)
    }
}

// Và phải có cầu nối, nếu không UI đọc một lần rồi đứng im mãi
static func startBridge() {
    cancellable = EntitlementService.shared.$isEntitled
        .removeDuplicates()
        .sink { _ in NotificationCenter.default.post(name: .premiumStatusDidChange, object: nil) }
}
```

`startBridge()` phải được gọi tay — static của `enum` là lazy global, không chạm
là không chạy.

### Riêng từng app

**Silly** — nặng nhất, dù chỉ 3 file gọi trực tiếp.
- `Helper/IAPService.swift:13` là `typealias IAPService = MobileAds.IAPService`.
  **Sửa tại chỗ**, đừng tạo file shim mới (redeclaration). File đó cũng sở hữu
  `Notification.Name.premiumStatusDidChange` / `.premiumVCDidDismiss` ở `:16-17` —
  8 observer đang dùng, xoá file là gãy hết.
- `Helper/IAP/SubscriptionStatusTracker.swift:42` có **listener `Transaction.updates`
  riêng**, khởi động từ `SceneDelegate.swift:84`. Cộng `EntitlementService` là 2
  listener cùng finish transaction → analytics renewal/expiry hụt âm thầm. Quyết
  retire hay giữ, đừng để trôi.
- Paywall là **RxSwift** (`PremiumVM.swift:130-175`, `WeeklyPaywallVM.swift:51-128`),
  không phải async/await. Bridge, đừng rewrite.
- `ProductID.swift:10` **không** `CaseIterable` — `ProductID.allCases` không compile.

**xmascall** — nhỏ nhất, nên làm đầu tiên. 2 file gọi trực tiếp.
`ProductID.swift:10` cũng **không** `CaseIterable`.

**iOS-ar-sketch** — 2 file gọi trực tiếp. `ProductID.swift:10` đã có `CaseIterable`
nhưng khai `productType: ProductType` (`:44`) — type đó chết cùng pod.

**ios-themearts** — rủi ro tiền thật.
- Bán consumable (`ThemeProductIdentifier.swift:28,31`). **Phải cấp `onUnfinished`**,
  nếu không mất coin ở đường Ask-to-Buy / app bị kill.
- `productIDs` phải chứa **cả** coin SKU, nếu không `purchase()` từ chối (`:341`).
- Cộng coin **chỉ trong `onUnfinished`**. Sau khi sửa review (2026-08-15), `purchase()`
  cũng đẩy transaction qua chính hook đó, nên hook là điểm giao hàng **duy nhất và đầy
  đủ**. Cộng thêm ở chỗ `purchase()` trả về là **cộng đôi**. Cụ thể: bỏ nhánh cộng ở
  `CoinViewModel.swift:150`, giữ một đường qua hook.
- `CoinsService.addCoins` (`CoinsService.swift:71-77`) **không atomic**: đọc ngoài
  barrier, ghi trong barrier. Store là App Group `UserDefaults` mà WidgetExtension
  cũng ghi. Cần `creditOnce(_:transactionID:)` làm một block barrier duy nhất.
- Seam là **RxSwift** `Driver<Bool>` (`IAPService+Ext.swift:25`). Bridge phải dùng
  `$isEntitled`, **tuyệt đối không** `objectWillChange` — nó bắn ở `willSet` và
  không mang giá trị, relay sẽ luôn trễ một nhịp. Nó compile sạch nên checkpoint
  compile không bắt được.
- Observer thật là `BaseViewController.swift:114` (base class của mọi VC), không
  phải 4 màn hình. Giữ nguyên chữ ký `AppStateService`, đừng đụng base class.
- `configure()`/`bootstrap()` vào `AppDelegate.swift:30` / `AppCoordinator.swift:17,19`.
- Bỏ workaround `IAPServiceAdapter.swift:86-95` (bug cũ đã hết vì `verify()` loại
  consumable ở `:206`).
- **Xác nhận 2 coin SKU đăng ký đúng loại Consumable ở App Store Connect** trước
  khi làm. Bảo vệ ở `:206` dựa trên `Transaction.productType`; tên
  `consumable.themearts.iap.*` chỉ là quy ước, không phải bằng chứng. Sai loại thì
  một gói coin cấp premium vĩnh viễn.

**silly-clone** — fork của Silly, branch `fbsdk`. Cùng `typealias`, cùng cấu trúc.
Kiểm xem có `SubscriptionStatusTracker` không. Xác nhận app còn sống trước khi tốn
công.

### Nên kiểm trên thiết bị

Checklist 23 case trong `README.md` (17–23 là case của delivery hook 2.0) + 2 case red-team:
- Mua rồi đóng paywall trong 200ms → vẫn entitled (task bị cancel nuốt purchase)
- Cold launch khi đang là subscriber → không thấy ads/paywall ở khung nào

Với themearts thêm: Ask to Buy duyệt sau khi relaunch → coin vào; force-quit giữa
lúc mua → coin vào lần mở sau; mua 2 lần → cộng đúng 2 lần; restore → không cộng lại.

## Red Team Review

### Session — 2026-08-14

**Findings:** 21 (20 accepted, 1 rejected) — dedupe từ 27 finding thô của 3 reviewer.
**Severity breakdown:** 8 Critical, 8 High, 4 Medium (accepted)
**Reviewers:** Security Adversary (Fact Checker), Failure Mode Analyst (Flow Tracer), Assumption Destroyer (Scope Auditor)

Sau khi user bỏ 4 phase migrate, một số finding không còn phase để áp — chúng được
chuyển vào **Migration notes** thay vì bỏ đi.

| # | Finding | Severity | Disposition | Áp vào |
|---|---|---|---|---|
| C1 | Consumable mất trên mọi đường trừ `purchase()`; E2 cấm đúng cái fix | Critical | Accept | E2→E2', P1 |
| C2 | Đếm sai app: silly-clone là app thứ 5, dùng `typealias` | Critical | Accept | Evidence, P0, Migration notes |
| C3 | `:path` là 4 repo, không phải 1 | Critical | Accept | Evidence, E11, P0 |
| C4 | Branch pilot thiếu 8 commit `new-MobileAds` (ATT, mediation, pins) | Critical | Accept | E9, P0 |
| C5 | Goal 3 tự mâu thuẫn; không có notification lúc launch | Critical | Accept | → Migration notes ("bẫy lớn nhất") |
| C6 | P4 quên `configure()`/`bootstrap()` | Critical | Accept | → Migration notes (themearts) |
| C7 | Branch topology không xác định | Critical | Accept | E8, E9, P0 |
| C8 | Cộng coin ở 2 chỗ → cộng đôi | Critical | Accept | → Migration notes (themearts) |
| H1 | `sharedSecret` 4 site, pod có đọc, cần rotate riêng | High | Accept | E7', Evidence, P2 |
| H2 | Gate P2 mù consumable | High | Accept | Moot — không còn gate nào. Case consumable → Migration notes |
| H3 | Silly cũng Rx + listener thứ 2 + `typealias` đụng tên | High | Accept | → Migration notes (Silly) |
| H4 | `CoinsService.addCoins` không atomic; `addCoinsOnce` bịa | High | Accept | → Migration notes (themearts) |
| H5 | Không phase nào có rollback | High | Accept | Cả 3 phase + success criteria |
| H6 | themearts observer thật là `BaseViewController` | High | Accept | → Migration notes (themearts) |
| H7 | `IAPError`/`ProductType` chết theo `IAPModels` | High | Accept | → Migration notes (bảng ánh xạ) |
| H8 | `ProductID.allCases` không compile | High | Accept | → Migration notes (Silly, xmascall) |
| M1 | Bridge Combine→Rx; `objectWillChange` là lựa chọn sai | Medium | Accept | → Migration notes (themearts) |
| M2 | P3‖P4 song song vô hiệu hoá gate | Medium | Accept | Moot — không còn phase song song |
| M3 | Task bị cancel nuốt purchase đã trả tiền | Medium | Accept | → Migration notes (case kiểm) |
| M4 | ~6 chỗ lệch số dòng trong evidence | Medium | Accept | Evidence sửa toàn bộ |
| — | clean-phone mất `IAPViewModel` (+16h) | Critical | **Reject** | Verify: clean-phone có `IAPViewModel` riêng (`CleanPhone/Features/IAP/IAPViewModel.swift`), gọi `IAPViewModel(iapService:)` trong khi pod `init()` không nhận tham số; grep pod IAP symbols → 0 hit |

**Ba lỗi đáng ghi nhớ về quy trình:**

1. **C1, C5, C8 là lỗi thiết kế, không phải chi tiết bỏ sót.** Bản đầu chọn E2
   ("base không giao hàng hộ") vì nghe sạch về kiến trúc, mà không truy transaction
   thực sự đến từ những đường nào. Comment cảnh báo đúng vấn đề này **đã có sẵn**
   trong `EntitlementService.swift:268-272` — viết ở plan trước rồi bỏ qua chính nó.
2. **Bảng evidence bản đầu lệch ~6 số dòng** vì trích từ trí nhớ scout thay vì đọc lại.
3. **"4 app" nhận từ plan trước mà không tự kiểm.** Plan trước đúng trong ngữ cảnh
   của nó (không migrate ai); plan này đụng tới app nên con số phải đếm lại.

### Whole-Plan Consistency Sweep
- Files reread: `plan.md`, `phase-00`, `phase-01`, `phase-02`
- Decision deltas checked: 6 (bỏ P2–P5; P6→P2; E5'/E10 moot; E8 viết lại; E13 thêm;
  goal migrate app → goal bàn giao)
- Reconciled stale references: phases table 7→3; effort 68h→20h; goals 5→4;
  success criteria bỏ mọi mục về app build; risk table viết lại quanh R1 (merge sớm)
- Unresolved contradictions: 0

## Unresolved questions

1. ~~**Branch của plan này sống ở đâu, và tới bao giờ?**~~ **Đã trả lời ở P0.**
   Tách từ `feat/entitlement-base` nguyên trạng (`c3bb450`), **chưa có đích merge**,
   nằm riêng tới khi 4 app migrate xong. Cấm merge: `new-MobileAds`, `develop`,
   `ver/swiftUI`. Còn treo: **ai là người giữ branch và điều kiện merge cụ thể**.
2. ~~**silly-clone còn sống không?**~~ **Đã trả lời ở P0.** Không phải git repo
   (không `.git`, không remote, mtime `2026-05-01`). Pin `fbsdk` — plan không đụng
   → không vỡ. User chốt giữ trong danh sách ở trạng thái unknown/at-risk.
3. **Ai rotate 2 shared secret, khi nào?** Còn treo. P0 chỉ mới xác định được **chỗ
   mở issue**: `BKPlusResearch/ios033-gps-camera`, vì repo pod tắt issues.
4. **2 coin SKU của themearts đăng ký đúng loại Consumable ở App Store Connect chứ?**
   Còn treo — chỉ kiểm được ở App Store Connect, không kiểm được từ repo.
5. ~~**Có quyền ghi vào 4 repo `:path` không?**~~ **Đã trả lời ở P0.** Có: cả 4
   Podfile đã sửa, `pod install` + build sạch. (`gh api` xác nhận `push=true` trên
   `MobileAds` và `ios033-gps-camera`; 3 repo còn lại chứng minh bằng chính việc sửa.)

<!-- slug: remove-legacy-iap -->
