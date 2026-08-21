---
title: "Entitlement Base"
description: "Thêm EntitlementService tổng quát vào pod (entitlements-first, host truyền config). Chỉ thêm file, không đụng IAPService, không wire vào app nào."
status: completed
priority: P1
effort: "12h"
tags: [iap, storekit, shared-library]
created: 2026-08-14
branch: feat/entitlement-base
---

# Entitlement Base

## Overview

Thêm vào pod một base IAP **tổng quát**, lấy `Transaction.currentEntitlements` làm
nguồn sự thật. Host app truyền product ID vào và tự dựng paywall — base không biết
gì về app nào, không tự hiện UI.

**Phạm vi đã thu hẹp hai lần, có chủ ý.** Bản đầu phủ shim tương thích + rollout 4
app. Bản hai phủ tích hợp ios033. Cả hai đã cắt. Còn lại đúng một việc: viết base
và tài liệu hoá nó.

## Ba ràng buộc định hình plan này

**1. Chỉ thêm, không sửa.** `IAPService` và layer cũ ở nguyên trạng. 4 app đang
dùng nó (Silly, xmascall, ios-themearts, iOS-ar-sketch) không bị ảnh hưởng, không
cần bump pod, không cần test lại. Đổi lại: pod mang **hai layer IAP song song** cho
tới khi ai đó migrate — chi phí đã biết và chấp nhận.

*(Ngoại lệ duy nhất, thêm sau red-team: Phase 2 sửa **doc comment** trong
`AppOpenModifier.swift` và `IAPViewModel.swift`. Comment, không phải logic — vì
chính hai file đó đang chỉ host gate ads qua layer cũ.)*

**2. Không app nào wire vào.** Base viết tổng quát, host tự implement.

**3. Base ship ở trạng thái chưa từng chạy.** Không có host app, và repo không có
hạ tầng test dùng được: target `TestAdsTests` có `TEST_HOST` trỏ tới `TestAds.app`
— app target đó **không còn trong project**; toàn repo **0 file test**, 0 file
`.storekit`.

Hệ quả của (3): mọi hành vi trong plan này là **suy luận từ tài liệu StoreKit 2,
chưa phải quan sát**. Một vòng red-team ngày 2026-08-14 đã tìm và sửa **4 Critical
+ 5 High + 3 Medium chỉ bằng cách đọc** — xem `## Red Team Review`. Phần chỉ lộ ra
lúc chạy thì vẫn không có gì bắt. Bù lại, Phase 2 bắt buộc README mang checklist
sandbox 14 case cho người tích hợp đầu tiên.

## Bằng chứng nền

| Sự kiện | Bằng chứng |
|---|---|
| `IAPService` đọc entitlement từ UserDefaults, không có StoreKit trong đường đi | `MobileAds/IAP/IAPService+Subscription.swift:25-46` |
| `.pending` (Ask to Buy) bị throw thành lỗi | `MobileAds/IAP/IAPService.swift:125-127` |
| `.inGracePeriod` khai báo (`IAPModels.swift:21`), đọc ở `:210`, **không nơi nào gán** → dead branch | `MobileAds/IAP/IAPModels.swift:21,210` |
| Không app nào gọi `validateReceiptWithApple()` | grep toàn workspace, 1 hit duy nhất là định nghĩa tại `IAPService+Receipt.swift:37` |
| Layer ads không đọc IAP **ở mức code**, nhưng **tài liệu tích hợp thì có** — `isEnabled: !iapVM.isPurchased` | `MobileAds/SwiftUI/AppOpenModifier.swift:11,67`; `README.md:8` |
| Chỉ cần khởi tạo `IAPViewModel` là `IAPService.shared` + listener của nó bật lên | `IAPViewModel.swift:35-37` → `IAPService.swift:19,43-48` |
| Đã có 2 app tự viết lại entitlements-first vì layer cũ không dùng được | `iOS-clean-phone-bkplus/CleanPhone/Services/IAP/IAPService.swift:57-63`, `ios033-gps-camera/.../PremiumStore.swift:46-62` |
| Pod platform **iOS 15** và **Swift 5.5** → không dùng được `ContinuousClock`/`Duration`/`Task.sleep(for:)` (iOS 16+) | `MobileAds.podspec:78,95` |
| 5 app đang pin `platform :ios, '15.0'` → không nâng platform pod được | Podfile của Silly, xmascall, ios-themearts, iOS-ar-sketch, TVChromeCast |
| Không có hạ tầng test | `xcodebuild -list`; `TEST_HOST = TestAds.app` (`project.pbxproj:811,829`) trỏ target không tồn tại |
| `ios-themearts` bán consumable **lẫn** subscription trong cùng app | `ios-themearts/.../ThemeProductIdentifier.swift:26-31`, workaround cho đúng bug này tại `IAPServiceAdapter.swift:86-94` |

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | `EntitlementService`: entitlement derive từ `currentEntitlements`, không từ storage | P1 |
| 2 | Tổng quát — host truyền product ID; đúng cho subscription, non-consumable, và **không cấp quyền nhầm từ consumable** | P1 |
| 3 | Chỉ thêm file; 4 app đang dùng `IAPService` không bị ảnh hưởng | P1 |
| 4 | README đủ để tích hợp đúng ngay lần đầu, kèm checklist sandbox 14 case | P1 |
| 5 | Intro-offer eligibility xác định và group-scoped; `.pending` là kết quả hợp lệ | P2 |

## Non-goals

- Không sửa **logic** `IAPService`, `IAPViewModel`, storage, receipt layer.
- Không migrate app nào, không wire vào app nào — kể cả ios033.
- Không dựng sample app / test target / StoreKitTest (đã cân nhắc, đã bỏ — D8).
- Server-side receipt validation.
- Paywall UI dùng chung, ad layer logic, attribution layer.
- Rotate `sharedSecret` — vấn đề có thật của 4 app kia, plan khác.

## Kiến trúc

```
MobileAds/IAP/
├── IAPService.swift + friends      ← nguyên trạng, 4 app cũ dùng
└── EntitlementService.swift        ← MỚI, chưa app nào dùng
    EntitlementConfig.swift
    EntitlementOutcome.swift
```

Host app tích hợp:

```
Host app (tự implement paywall, gate, ads)
        │  configure(productIDs:) → bootstrap() → refresh()
        │  đọc: verification, isEntitled, products, isIntroOfferEligible
        ▼
EntitlementService (ObservableObject, @MainActor, singleton)
        ▼
Transaction.currentEntitlements + Transaction.updates
```

### Mô hình trạng thái

Ba trạng thái, không phải Bool — đây là sửa Critical F1:

| Property | Ý nghĩa | Dùng để quyết định? |
|---|---|---|
| `verification: .pending / .verified / .timedOut` | StoreKit đã trả lời chưa | **Có** |
| `isEntitled` | `false` cho tới khi `.verified`; không có nguồn nào ngoài `verify()` | Chỉ khi `.verified` |

**Base không lưu entitlement ở bất kỳ đâu** (V3). `UserDefaults` chỉ còn đúng một
key: `restorePrompted`. Không còn giá trị entitlement nào trong storage để giả mạo.

### Luồng khởi động — `bootstrap()` không async

```
t=0ms   host gọi bootstrap()          → trả về ngay, không await được
t=0ms   timeout 5s được arm TRƯỚC
t=0ms   loadProducts() ‖ verify()     → thật sự song song
t=~     verify xong                   → verification = .verified
t=5s    nếu vẫn .pending              → .timedOut, mặc định: coi như free, hiện ads
```

Nguyên tắc host phải tuân: **không mở khoá gì khi `verification != .verified`.**
Không có cache nào để "tạm tin", và host cũng không được tự dựng một cái.

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | [Phase 1: EntitlementService](./phase-01-entitlement-service.md) | Completed |
| 2 | [Phase 2: Docs + release](./phase-02-docs-release.md) | Completed |

Dependency: 1 → 2. Một repo duy nhất: `MobileAds`.

## Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| D1 | `currentEntitlements` là nguồn sự thật | Reinstall/đổi máy, grace period, refund, family sharing đúng miễn phí |
| D2 | Restore là đường cứu hộ, không phải đường chính. **Nút Restore luôn hiện** | Guideline 3.1.1; cần cho case máy đăng nhập Apple ID khác |
| D3 | Base đặt trong `MobileAds/IAP/` | Theo `docs/code-standards.md` mục 1 |
| D4 | Chỉ thêm vào pod, không sửa logic `IAPService` | 4 app không bị ảnh hưởng, không cần bump, không cần regression test |
| D5 | Host truyền product ID qua `EntitlementConfig` | Base tổng quát, không biết app nào |
| ~~D6~~ | ~~`productIDs` rỗng = nhận mọi transaction~~ | **XOÁ sau red-team.** Fail-open: consumable và non-renewing hết hạn lọt qua. Lý do viện dẫn (app cũ chưa `configure()`) mô tả tình huống mà Non-goals đã cấm. Thay bằng D9 |
| D7 | Cờ `shouldProactivelyPromptRestore` do base cấp, UI do host tự hiện | Base là thư viện, không tự bung dialog |
| D8 | Ship không qua kiểm chứng thiết bị | Đã cân nhắc sample app + StoreKitTest (~6h) và smoke test tạm; chọn bỏ cả hai. Bù bằng README + checklist |
| **D9** | **Fail closed.** `productIDs` bắt buộc, non-empty, không có `init()` rỗng. `configure()` một lần duy nhất, không nới được lúc runtime | Thay D6. Ngăn cấp quyền từ purchase không liên quan, và ngăn tập sản phẩm bị mở rộng sau khi app đã chạy |
| **D10** | **Back-deploy iOS 15**: `ProcessInfo.systemUptime` + `Task.sleep(nanoseconds:)` | 5 app đang pin `platform :ios, '15.0'`; nâng pod lên 16 là breaking change cho tất cả |
| **D11** | **Ba trạng thái verification**, không phải Bool `hasVerified` | Timeout không được đóng dấu "đã verify" lên giá trị cache. Host cần phân biệt "chưa biết" với "đã hết hạn chờ" để tự chọn chính sách |
| **V1** | Ở `.timedOut`, README khuyến nghị **coi như free, hiện ads** | Ưu tiên doanh thu. Giá phải trả: subscriber mạng tệ thấy ads vài giây đầu. Host được chọn khác nhưng phải có lý do |
| **V2** | **Finish cả transaction `.unverified`** | Entitlement derive từ `currentEntitlements`, độc lập hàng đợi `updates` — transaction unverified không cấp quyền ở cả hai đường, nên finish nó không mất gì. Dứt điểm redelivery |
| **V3** | **Xoá hẳn cache entitlement.** Không expose hint, và vì không ai đọc nữa nên bỏ luôn cả key | Bề mặt tấn công của F1 biến mất hoàn toàn. Giá phải trả: subscriber thấy UI free vài chục ms đầu mỗi lần mở app |
| **V4** | **Không merge.** Base ở nguyên `feat/entitlement-base` cho tới khi checklist pass | 4 app đang kéo `new-MobileAds`; đẩy code chưa chạy vào đó là cược bằng app người khác. Merge vào `ver/swiftUI` thì không ai nhận được gì |

## Success Criteria

- [ ] Pod build sạch trên iOS 15 simulator
- [ ] `grep -rnE "ContinuousClock|Duration|sleep\(for:" MobileAds/IAP/Entitlement*.swift` → 0 hit
- [ ] `EntitlementConfig` không có `init()` rỗng; `productIDs` không có default
- [ ] `grep -n "UserDefaults" MobileAds/IAP/EntitlementService.swift` → chỉ ra
      `restorePrompted`, không có key entitlement nào
- [ ] `verification = .verified` chỉ gán ở đúng một hàm
- [ ] `handle()` gọi `finish()` ở cả hai nhánh verified và unverified
- [ ] `bootstrap()` không phải `async`
- [ ] Luồng derive loại consumable, loại non-renewing hết hạn, giữ `expirationDate == nil`
- [ ] Không hardcode product ID / tên app / chuỗi hiển thị nào trong base
- [ ] README có 3 bước tích hợp, 5 cái bẫy, checklist 14 case
- [ ] README + PR nói rõ base chưa kiểm chứng trên thiết bị
- [ ] Cảnh báo "không trộn hai layer" ở cả 4 chỗ (README mục mới, README mục ads,
      doc comment `AppOpenModifier`, doc comment `IAPViewModel`)
- [ ] `git diff --stat ver/swiftUI..feat/entitlement-base`: file thêm mới + docs +
      README + podspec + **chỉ doc comment** ở 2 file SwiftUI. 0 dòng logic sửa
- [ ] Podspec `1.4.0`, platform vẫn `15.0` (bump chỉ để vệ sinh — không app nào pin theo version)
- [ ] Branch `feat/entitlement-base` đã push, **chưa merge vào đâu**
- [ ] Silly / xmascall / ios-themearts / iOS-ar-sketch: không cần làm gì

## Risks

| # | Risk | Mức | Xử lý |
|---|---|---|---|
| R0 | **Base chưa từng chạy.** Red-team tìm 12 lỗi chỉ bằng đọc; lỗi runtime vẫn không có gì bắt | High | Đã chấp nhận có ý thức (D8). README + checklist 14 case là control duy nhất |
| R1 | Host dùng `@Observable` forward thay vì mirror → UI không cập nhật | High | Bẫy compile được nên không lộ lúc build. README mục riêng |
| R2 | Pod mang 2 layer IAP song song, và tài liệu ads hiện có đang trỏ vào layer cũ | High | `[RT-F9]`: Phase 2 sửa cảnh báo ở cả 4 chỗ. **Không** chặn được bằng runtime assert vì phải sửa `IAPService` — D4 cấm. Hạn chế đã biết |
| R3 | Ai đó "đơn giản hoá" ba trạng thái về lại Bool, hoặc trả `productIDs` về optional | High | Mọi chỗ đánh dấu `[RT-Fn]`; mục Red Team Review giải thích vì sao |
| R4 | **Base nằm im, không ai tích hợp.** V4 cố ý chưa merge, nên rủi ro này tăng chứ không giảm | High | Cần một app tình nguyện làm người tích hợp đầu tiên. Không có thì base này là code chết — và checklist, control duy nhất của R0, không bao giờ chạy |
| R5 | Subscriber thấy UI free vài chục ms đầu mỗi lần mở app (hệ quả V3) | Medium | Đánh đổi đã chấp nhận. Nếu nháy khó chịu: thêm hint như property tách biệt, tuyệt đối không làm giá trị khởi tạo của `isEntitled` |
| R6 | Ai đó merge sớm vào `new-MobileAds` "cho tiện" | High | 4 app sẽ kéo về code chưa chạy. Điều kiện merge là **checklist pass**, không phải "đã review xong" |

## Red Team Review

### Session — 2026-08-14

**Findings:** 12 (12 accepted, 0 rejected) — sau khi lọc trùng từ 16 finding thô
của 2 reviewer.
**Severity breakdown:** 4 Critical, 5 High, 3 Medium
**Reviewers:** Security Adversary (Fact Checker), Assumption Destroyer (Fact Checker)

| # | Finding | Severity | Disposition | Applied To |
|---|---|---|---|---|
| F1 | Timeout đặt `hasVerified = true` trong khi `isEntitled` vẫn là giá trị cache → cache được đóng dấu "đã verify" | Critical | Accept | P1 s3/s4/s7/s8, D11 |
| F2 | `EntitlementConfig()` fail-open; consumable và non-renewing hết hạn lọt qua; `configure()` nới được lúc runtime | Critical | Accept | P1 s1/s5/s6, D6→D9 |
| F3 | `ContinuousClock`/`Duration`/`Task.sleep(for:)` là iOS 16+, pod pin iOS 15 + Swift 5.5 → không compile | Critical | Accept | P1 s3/s8/s9, D10 |
| F4 | `bootstrap()` await `loadProducts()` **trước** khi arm timeout, và kết thúc bằng `await verifyTask.value` không bound → chặn launch; sơ đồ mâu thuẫn pseudocode | Critical | Accept | P1 s8, plan.md |
| F5 | `currentEntitlements` không có kênh lỗi; cài-mới-offline trả rỗng bị đọc thành "không có quyền" và ghi đè cache | High | Accept (thu hẹp cơ chế) | P1 Architecture, P2 checklist 8/9 |
| F6 | `verify()` không chống chồng lấn — verify cũ ghi đè kết quả mua mới | High | Accept | P1 s6 |
| F7 | `purchase()` gắn thành công vào entitlement toàn cục → consumable luôn báo `.failed` dù đã trừ tiền | High | Accept | P1 s11 |
| F8 | `subscriptionGroupID` khai rồi không đọc; eligibility lấy theo thứ tự dictionary; mặc định `true` | High | Accept | P1 s14, P2 checklist 12 |
| F9 | "Đừng trộn 2 layer" chỉ là docs, trong khi `IAPViewModel.init()` tự bật listener của `IAPService` và README/`AppOpenModifier` đang chỉ host gate ads qua layer cũ | High | Accept | P2 file list + s2 |
| F10 | `shouldSuggestRestore` là computed đọc UserDefaults (không publish), cờ không bao giờ reset → rủi ro 3.1.1 | Medium | Accept | P1 s15, P2 s2 |
| F11 | `.failed(String)` bê text hệ thống vào API công khai; huỷ sign-in khi Restore hiện thành lỗi | Medium | Accept (thu hẹp) | P1 s2/s13 |
| F12 | `docs/code-standards.md` mục 1 là cây thư mục, không chứa file; bảng type mục 8 mới là target đúng | Medium | Accept | P2 s5 |

**Hai chỗ thu hẹp so với reviewer:**
- F2 có nhánh "Frida hook gọi `configure()`" — nếu attacker inject được code thì
  mọi thứ đã sập, không phải threat model của app này. Phần đứng vững và đã áp
  dụng: timing với Remote Config, và việc `configure()` public không giới hạn.
- F5 phát biểu gốc là "offline → rỗng → mất quyền". Cơ chế đúng hẹp hơn: máy **đã
  từng sync** thì `currentEntitlements` phục vụ từ cache trên máy và **vẫn đúng khi
  offline**; chỉ **cài mới + offline** mới mù. Đã sửa checklist case 8/9 theo cơ
  chế thật thay vì theo phát biểu gốc.

**Ba lỗi đáng ghi nhớ về quy trình:**
1. F1, F3, F6 đều do bê pattern từ `ios033/PremiumStore.swift` — một app iOS 18 có
   host chạy thật — vào ngữ cảnh thư viện iOS 15 không ai chạy, mà không điều
   chỉnh theo ràng buộc mới.
2. F8 là bug mà `ios033/TrialLedger.swift:33-44` **đã gặp và đã sửa**, có comment
   giải thích. Spec bản đầu viết lại đúng bản sai.
3. Checklist Phase 2 — thứ duy nhất mua được để bù cho D8 — ban đầu **không có**
   case nào cho intro offer, consumable, hay race. Ba case đó (11, 12, 13) là phần
   giá trị còn lại của vòng review; cắt chúng là vứt luôn vòng review.

### Whole-Plan Consistency Sweep
- Files reread: `plan.md`, `phase-01-entitlement-service.md`, `phase-02-docs-release.md`
- Decision deltas checked: 5 (D6 xoá; D9/D10/D11 thêm; `hasVerified` → `verification`;
  `shouldSuggestRestore` → `shouldProactivelyPromptRestore`; `bootstrap()` async → sync)
- Reconciled stale references: 7 (sơ đồ luồng khởi động trong `plan.md`; bảng mô hình
  trạng thái; success criteria cả 3 file; checklist case 8/9; effort 9h → 12h;
  ngoại lệ doc-comment cho D4; số case checklist 10 → 13)
- Unresolved contradictions: 0

## Validation Log

### Session 1 — 2026-08-14

Verification pass **bỏ qua** theo guard của workflow: `## Red Team Review` đã tồn
tại với evidence đầy đủ. Quét `[UNVERIFIED]` → 0 tag còn sót.

**Phát hiện ngoài lề trong lúc quét** (red-team bỏ sót): không app nào pin pod theo
version — tất cả dùng `:git + :branch => 'new-MobileAds'` hoặc `:path`. Kéo theo
hai hệ quả: `spec.version` bump không giao gì cho ai, và branch mới là thứ quyết
định app nhận code nào. Đây là dữ kiện dẫn tới câu hỏi V4.

**4 câu hỏi, 4 quyết định:**

| # | Câu hỏi | Quyết định | Hệ quả |
|---|---|---|---|
| V1 | Chính sách mặc định ở `.timedOut` | Coi như free, hiện ads | README nêu khuyến nghị; P1 mô hình trạng thái; P2 bẫy #1, checklist case 9 |
| V2 | Transaction `.unverified` xử sao | **Finish luôn** | P1 s12 viết lại; bỏ cấu trúc dedupe |
| V3 | `cachedEntitlementHint` có public không | **Private** → kéo theo **xoá hẳn cache** | P1 s3/s4/s7 + mục mới "Vì sao không còn cache"; P2 bẫy #2, checklist case 14 |
| V4 | Merge vào branch nào | **Không merge**, giữ `feat/entitlement-base` | P2 s6/s7/s8 viết lại; R4 nâng lên High, thêm R6 |

**Hai chỗ tôi tự sửa lập luận của chính mình:**

1. **V2 — cảnh báo trước đó của tôi sai.** Bản red-team tôi viết "không finish
   transaction unverified vì một giao dịch hợp lệ trượt verify sẽ mất luôn". Sai:
   entitlement derive từ `currentEntitlements`, độc lập hoàn toàn với hàng đợi
   `Transaction.updates`. Transaction `.unverified` không cấp quyền ở cả hai đường,
   và nếu verify trượt tạm thời thì `currentEntitlements` vẫn chứa entitlement đó
   sau khi điều kiện hết. Finish nó không mất gì.

2. **V3 kéo theo một đơn giản hoá tôi không hỏi trước.** Nếu hint không public,
   không ai đọc nó nữa → cái Bool trong `UserDefaults` thành code chết. Xoá luôn cả
   key. Kết quả ngoài mong đợi: base không còn lưu entitlement ở bất kỳ đâu, nên
   bề mặt tấn công của F1 biến mất hoàn toàn thay vì chỉ bị chặn.

## Implementation Log

### Session — 2026-08-14

Cả 2 phase implement xong trên `feat/entitlement-base` (tách từ `ver/swiftUI`).
Build sạch iOS 15 simulator (arm64 + x86_64), 0 warning trong 3 file mới. Mọi
success criteria pass. **Chưa push, chưa merge** — chờ quyết định.

**Hai vòng code review** (cùng 1 reviewer, vòng 2 review delta):

| Vòng | Kết quả |
|---|---|
| 1 | 10/12 criteria pass; criterion 9 **FAIL**. 5 High + 4 Medium + 6 Low, tất cả CONFIRMED (traced in code) |
| 2 | **12/12 pass**. H1–H5 + M1–M4 đóng hẳn. Fix H5 đẻ ra 2 Medium mới (D1, D2) → đã sửa nốt |

**Ba finding bắt nguồn từ chính pseudocode của plan** — cùng loại lỗi mà mục
`Red Team Review` đã tự cảnh báo ("bê pattern từ ios033 vào ngữ cảnh thư viện mà
không điều chỉnh"):

- **H2 (High).** P1 s14 viết `?? candidates.first`. `isEligibleForIntroOffer` là
  câu hỏi **mức group**, nên product không có intro offer vẫn trả `true` → hứa
  trial trên gói tính tiền ngay. Đúng cái bug mà s14 nói là đang sửa. Đã bỏ hẳn
  fallback. Chính là F8 quay lại theo đường khác.
- **H1 (High).** Không có `Task.isCancelled` trước `publish()`. `refresh()` là
  public async nên thừa kế cancellation của caller; `.task { await refresh() }`
  (đúng cách README bảo gọi) bị SwiftUI cancel lúc view biến mất → đọc dở dang,
  `active = false`, và `publish()` đóng dấu `.verified` lên một **false negative**.
  Subscriber tụt xuống free. Đây là F1 ở dạng khác: plan chặn được đường timeout,
  không chặn đường cancellation.
- **H3 (High).** `refreshIntroEligibility()` chỉ gọi ở đuôi `verify()`, mà
  `verify()` (đọc cache trên máy) gần như luôn xong trước `loadProducts()` (round-
  trip mạng) → tính eligibility trên catalog rỗng, và không bao giờ tính lại;
  debounce 30s chặn luôn đường phục hồi.

**Sai lệch có chủ ý so với spec** (đều đã verify, không phải bỏ sót):

| # | Spec | Thực tế | Lý do |
|---|---|---|---|
| 1 | Không đụng file ngoài danh sách | `MobileAds.xcodeproj/project.pbxproj` +12 dòng | Project dùng explicit file reference. Không đăng ký thì target không compile 3 file mới và criterion "pod build sạch" **không kiểm được**. Consumer vẫn nhận file qua podspec glob. Là scaffolding, 0 dòng logic |
| 2 | P1 s13: `(error as? StoreKitError) == .userCancelled` | `mapFailure(_:)` dùng pattern match | `StoreKitError` **không** conform `Equatable` → không compile. Bonus: map đúng network/storefront/notAllowed thay vì gộp mọi throw thành `.failed(.network)` |
| 3 | P2 s5: bảng type "mục 8" (`:170`) nhận 6 type | `EntitlementFailure` vào bảng §6; 5 type còn lại ở `codebase-summary.md` §3 | `:170` nằm trong **§6 Error Handling** (§8 là Testing) — plan ghi nhầm số mục. Bảng đó scope là *error enum*; nhét service class vào là mô tả sai. User chọn phương án này |
| 4 | Checklist 14 case | **16 case** | Case 15 (group không có intro offer) và 16 (offline launch rồi mở paywall) là hai đường fail-open review tìm ra. Logic của plan — "cắt case 11/12/13 là vứt vòng review" — áp dụng y hệt |
| 5 | P1 s7: `if active { markRestorePrompted() }` | `shouldProactivelyPromptRestore = false` | M4: `markRestorePrompted()` ghi **persisted** key, tức ghi nhận một prompt chưa từng hiện → lần lapse sau không bao giờ gợi ý restore nữa |

**Giữ nguyên, không đảo quyết định của user:** V2 (finish cả transaction
unverified) — reviewer nêu rủi ro với consumable; đã **thu hẹp doc comment** thay
vì đổi hành vi, vì V2 là quyết định đã chốt ở Validation Log.

**R0 không đổi.** Vẫn 0 file test, 0 `.storekit`. Hai vòng review tìm ra 5 High +
6 Medium **chỉ bằng đọc** — củng cố chứ không làm giảm luận điểm của R0: phần chỉ
lộ lúc chạy vẫn không có gì bắt. Reviewer đề xuất thêm `.storekit` config trước
khi app đầu tiên tích hợp; ngoài scope plan này.

### Whole-Plan Consistency Sweep (validation)
- Files reread: `plan.md`, `phase-01-entitlement-service.md`, `phase-02-docs-release.md`
- Decision deltas checked: 4 (V1–V4)
- Reconciled stale references: 9 (bảng mô hình trạng thái ở cả 2 file; sơ đồ luồng
  khởi động; `cachedEntitlementHint` xoá khỏi skeleton/`init()`/`publish()`;
  `cacheKey` xoá; P1 s12 viết lại; success criteria cả 3 file; checklist 13 → 14
  case; số bẫy README 4 → 5; chiến lược branch ở P2 + risk table)
- Unresolved contradictions: 0
