# MobileAds — Chuẩn tracking Firebase Analytics

Spec duy nhất cho tên event, param và user property của mọi app BKPlus iOS. Dev, QA và AI agent đọc rồi làm theo.

Phạm vi: chỉ Firebase Analytics. Không gồm AppsFlyer, Qonversion hay SDK attribution khác.

Rule AIKit trỏ tới spec này: `/Users/shjn/work_space/My App/AIKit/rules/analytics-tracking.md`.

Tên event, param và định danh code giữ tiếng Anh.

## Mục lục

- [1. Format tên event](#1-format-tên-event) · [2. Danh sách action cố định](#2-danh-sách-action-cố-định) ·
  [3. Event bắt buộc cho mỗi màn](#3-event-bắt-buộc-cho-mỗi-màn) · [4. Paywall](#4-paywall) ·
  [5. Kết quả mua](#5-kết-quả-mua) · [6. Ad full-screen (AOA, inter)](#6-ad-full-screen-aoa-inter) ·
  [7. Các ad khác](#7-các-ad-khác) · [8. Param chuẩn và custom dimension](#8-param-chuẩn-và-custom-dimension) ·
  [9. User property bắt buộc](#9-user-property-bắt-buộc) · [10. Tracking plan của mỗi app](#10-tracking-plan-của-mỗi-app) ·
  [11. Checklist release](#11-checklist-release) · [12. Migrate app cũ](#12-migrate-app-cũ) ·
  [Ví dụ ios099](#ví-dụ-ios099)
- API pod: [API tracking trong pod](#api-tracking-trong-pod)

## 1. Format tên event

```
{app}_{screen}_{action}
```

- `{app}` = `iosNNN`, lấy theo tên repo. Ví dụ repo `ios099-demo` → `ios099`.
- Chỉ dùng ký tự `[a-z0-9_]`. Không chữ hoa, không dấu cách, không dấu gạch ngang.
- Tổng độ dài ≤ 40 ký tự (giới hạn Firebase).
- Mã màn (`{screen}`) ≤ 14 ký tự. Với `iosNNN_` chiếm 7 ký tự, còn 33 ký tự cho `{screen}_{action}`.
- Mã màn là danh từ ngắn, ổn định, không đổi theo bản release. Ví dụ `splash`, `home`, `paywall`, `settings`.

Ví dụ: `ios099_home_view`, `ios099_paywall_buy_click`.

## 2. Danh sách action cố định

Chỉ dùng các action sau. DEBUG validator từ chối action ngoài danh sách.

| Nhóm | Action | Khi nào |
|---|---|---|
| Điều hướng | `view` | Màn xuất hiện |
| | `back` | User quay lại |
| | `close` | User đóng màn/sheet/popup |
| | `next` | User sang bước kế (onboarding) |
| | `skip` | User bỏ qua bước |
| Bấm nút | `{target}_click` | User bấm một nút. `{target}` là danh từ ngắn, ví dụ `create_click` |
| Luồng tác vụ | `start`, `complete`, `success`, `fail`, `cancel` | Vòng đời của một tác vụ |
| Ad | `show`, `show_fail`, `close` | Chỉ trong tên ad. Xem [mục 6](#6-ad-full-screen-aoa-inter) và [mục 7](#7-các-ad-khác). Validator chỉ nhận `_show` / `_show_fail` khi tên chứa `_aoa_`, `_inter_` hoặc `_ad_` |
| Mua | `purchase` | Kết quả mua IAP. Xem [mục 5](#5-kết-quả-mua) |
| Ad khác | `request`, `load`, `load_fail`, `reward` | Chỉ trong `{app}_ad_*`. Xem [mục 7](#7-các-ad-khác) |

Không dùng:

- `tap` → dùng `{target}_click`.
- `open` → dùng `view`.
- `impression` → dùng `view` (màn) hoặc `show` (ad).
- `show` ngoài ad → dùng `view`.
- `dismiss` → dùng `close`.

## 3. Event bắt buộc cho mỗi màn

- `_view` khi màn xuất hiện. Một lần mỗi lần xuất hiện.
- `_{target}_click` cho mỗi nút dẫn sang màn khác.
- `_back` hoặc `_close` cho mỗi đường thoát.
- Onboarding đánh số theo thứ tự: `onb1`, `onb2`, `onb3`…

Ví dụ màn `home` có nút "Tạo" dẫn sang màn `create`:

- `ios099_home_view`
- `ios099_home_create_click`

Màn `create` có nút back:

- `ios099_create_view`
- `ios099_create_back`

Màn nào thay đổi nội dung theo state mà user thấy là màn khác (ví dụ kết quả) thì cho mã màn riêng.

## 4. Paywall

Mã màn là `paywall`. Event:

| Event | Khi nào |
|---|---|
| `{app}_paywall_view` | Paywall hiện |
| `{app}_paywall_plan_click` | User chọn một gói |
| `{app}_paywall_buy_click` | User bấm mua |
| `{app}_paywall_close` | User đóng paywall |
| `{app}_paywall_restore_click` | User bấm khôi phục |

- Bắt buộc param `source` = mã màn gốc đã mở paywall (ví dụ `home`, `settings`, `splash`).
- `source` không được rỗng và không được là `unknown`.
- Không đặt tên gói vào tên event. Tên gói đi vào param `plan`.

## 5. Kết quả mua

Mã màn là `iap`. Event:

| Event | Khi nào |
|---|---|
| `{app}_iap_trial_start` | Bắt đầu dùng thử |
| `{app}_iap_intro_purchase` | Mua với giá giới thiệu |
| `{app}_iap_paid_purchase` | Mua trả tiền đầy đủ |
| `{app}_iap_purchase_success` | Giao dịch thành công (mọi loại) |
| `{app}_iap_purchase_fail` | Giao dịch lỗi |
| `{app}_iap_purchase_cancel` | User huỷ ở hộp thoại mua |

Param kèm theo:

- `plan`: mã gói.
- `source`: mã màn gốc, lấy từ paywall.
- `value`: số tiền thực.
- `currency`: mã tiền tệ ISO, ví dụ `USD`.

`purchase_fail` thêm `error_code`.

## 6. Ad full-screen (AOA, inter)

Màn nằm trong tên event:

```
{app}_{screen}_{aoa|inter}_{show|close|show_fail}
```

- Pod tự bắn. App không gọi log cho các event này.
- Màn lấy từ `ScreenTracker.current` lúc ad được show.
- "show" là thời điểm SDK gọi `adWillPresentFullScreenContent`. Không phải lúc gọi `show*` hay lúc ad load xong.
- `close` là lúc ad đóng. `show_fail` là lúc SDK báo present lỗi.
- Ví dụ: `ios099_splash_aoa_show`, `ios099_create_inter_close`.

Param gửi kèm tự động:

| Param | Áp dụng | Giá trị |
|---|---|---|
| `to_screen` | inter | Màn đích, từ `showInterstitialAd(..., toScreen:)`. Có thể bỏ |
| `placement` | AOA | `splash` hoặc `resume`, từ `showAppOpenAd(..., placement:)` |

App chỉ cần giữ màn hiện tại đúng. Xem [API tracking trong pod](#api-tracking-trong-pod).

**Splash:** gọi `ScreenTracker.enter("splash")` trước khi SHOW AOA (màn được chốt lúc show, không phải lúc load). Nếu không, event AOA có màn `unknown`.

## 7. Các ad khác

Native, banner, rewarded và rewarded inter dùng tên chung, màn đi vào param:

```
{app}_ad_{native|banner|reward|reward_inter}_{request|load|load_fail|show|show_fail|click|close|reward}
```

- Param `screen` bắt buộc.
- Request và load của AOA, inter cũng theo dạng này: `{app}_ad_aoa_request`, `{app}_ad_inter_load_fail`. Param `screen` bắt buộc.
- `reward` chỉ có ở `reward` và `reward_inter`.
- Ví dụ: `ios099_ad_native_show` kèm `screen=home`.

**Vì sao không đặt màn vào tên:** Firebase giữ tối đa 500 tên event mỗi app. Bảng tính cho một app 40 màn:

| Cách đặt tên | Số tên event |
|---|---|
| AOA + inter, 3 state, màn trong tên: 2 × 3 × 40 | 240 |
| Native, banner, reward, reward_inter, 8 state, màn trong tên: 4 × 8 × 40 | 1280 |
| Ad khác dùng tên chung + param `screen`: 4 × 8 | 32 |

Nếu cả bốn format đều đặt màn vào tên thì vượt 500. Nên chỉ AOA và inter (doanh thu cao, cần soi theo màn) đặt màn vào tên, và chỉ với 3 state.

## 8. Param chuẩn và custom dimension

Param chuẩn:

| Param | Ý nghĩa |
|---|---|
| `source` | Mã màn hoặc điểm vào dẫn tới event này |
| `screen` | Mã màn chứa ad (cho ad dùng tên chung) |
| `to_screen` | Mã màn đích (inter) |
| `feature` | Mã tính năng đang dùng |
| `plan` | Mã gói IAP |
| `placement` | Vị trí ad, ví dụ `splash`, `resume` |
| `ab_branch` | Nhánh A/B của user |
| `error_code` | Mã lỗi dạng số hoặc chuỗi ngắn |

Quy tắc:

- BigQuery export có đủ mọi param của mọi event mà không cần đăng ký gì.
- Chỉ đăng ký custom dimension trong GA4 cho **các param chuẩn ở bảng trên**, để xem trực tiếp trên giao diện GA4.
- Param riêng của app chỉ cần có trong BigQuery. Không đăng ký.
- Mỗi event tối đa 25 param. Giá trị chuỗi tối đa 100 ký tự.
- Tên param cũng theo `[a-z0-9_]`.

## 9. User property bắt buộc

| Property | Giá trị |
|---|---|
| `is_premium` | `true` hoặc `false` |
| `ab_branch` | Nhánh A/B hiện tại |
| `first_open_version` | Version app lúc mở lần đầu. Pod tự set một lần, và chỉ đánh dấu đã set khi Firebase đã configure |

Với user cài app trước khi app áp dụng chuẩn này, `first_open_version` là version đầu tiên chạy đoạn code này, không phải version lúc cài. Muốn thời điểm cài thật, dùng `first_open_time` tự động của Firebase.

Gọi `FirebaseLogger.shared.setStandardUserProperties(isPremium:abBranch:)` khi trạng thái premium hoặc nhánh A/B thay đổi, và lúc khởi động.

## 10. Tracking plan của mỗi app

- Mỗi app có một tracking plan.
- Đặt ở `docs/event-tracking.md`. App mới dùng `docs/tracking-plan.md`.
- Bảng gồm các cột: màn → mã → event → param.
- Tracking plan phải khớp code. Thêm màn hoặc event thì sửa plan trong cùng PR.

Mẫu:

| Màn | Mã | Event | Param |
|---|---|---|---|
| Trang chủ | `home` | `ios099_home_view`, `ios099_home_create_click` | — |
| Paywall | `paywall` | `ios099_paywall_view`, `ios099_paywall_buy_click` | `source`, `plan` |

## 11. Checklist release

Làm trước mỗi bản release:

- [ ] Script audit không lỗi: `MobileAds/scripts/tracking-audit.sh <repo-path> <app-code>`. Ví dụ `tracking-audit.sh ~/work_space/BKPlus/ios099-demo ios099`. Script in từng lỗi dạng `ERROR <file>:<line> <tên> — <lý do>` rồi dòng `SUMMARY events=<n> errors=<n> warnings=<n>`; thoát mã 0 khi sạch, 1 khi có lỗi, 2 khi gọi sai tham số. Tên ghép lúc runtime chỉ bị cảnh báo, không được kiểm.
- [ ] Chạy funnel chính trên simulator, đọc log `🔥`. Thấy đủ chuỗi event từ splash tới mua.
- [ ] Không còn `source=unknown` ở event paywall và IAP.
- [ ] Không còn màn `unknown` trong tên event AOA, inter.
- [ ] Tracking plan ([mục 10](#10-tracking-plan-của-mỗi-app)) khớp code.
- [ ] Custom dimension của các param chuẩn đã đăng ký trong GA4.

## 12. Migrate app cũ

Đổi prefix làm gãy liên tục dữ liệu. Event `app002_*` và `ios002_*` là hai tên khác nhau.

Trước khi release bản đổi tên:

1. Hỏi team Monet xem có dashboard hoặc conversion nào dựa trên tên cũ không.
2. Nếu có, báo trước bản release để họ đổi sang tên mới.
3. Không log song song tên cũ và tên mới.

Sau khi release:

- So sánh số liệu trước và sau bằng `app_version` trong BigQuery.
- `dismiss` đổi thành `close` cùng đợt đổi prefix.

## API tracking trong pod

App đặt mã app một lần lúc khởi động:

```swift
AnalyticsConfig.appCode = "ios099"
```

Chưa đặt thì event chuẩn không được gửi. Lời gọi của app (`enter`, `track`) báo `assert` trong DEBUG. Event do pod tự bắn (ad AOA/inter) bỏ qua im lặng, nên app nâng pod mà chưa áp dụng chuẩn không bị crash.

Theo dõi màn:

| API | Việc làm |
|---|---|
| `ScreenTracker.enter(_ screen: String)` | Đẩy màn vào stack, log `{app}_{screen}_view` |
| `ScreenTracker.enter(_ screen: String, params:)` | Như `enter(_:)`, kèm params cho event `_view` |
| `ScreenTracker.leave(_ screen: String)` | Gỡ màn khỏi stack |
| `ScreenTracker.current` | Màn trên cùng stack. `"unknown"` khi stack rỗng |
| `ScreenTracker.track(_ action: String, params:)` | Log `{app}_{current}_{action}` |
| `ScreenTracker.track(screen:action:params:)` | Log `{app}_{screen}_{action}` |

Cách gọi:

- UIKit: `ScreenTracker.enter` trong `viewDidAppear`, `ScreenTracker.leave` trong `viewDidDisappear`.
- SwiftUI: modifier `.trackedScreen("home")`.
- Splash gọi `ScreenTracker.enter("splash")` trước khi show AOA.
- `enter`, `leave`, `track` chỉ gọi trên main thread (DEBUG kiểm bằng `dispatchPrecondition`).

Hai màn xếp chồng trực tiếp lên nhau không được dùng chung mã màn. Pod không push trùng khi màn đó đang ở đỉnh stack (để chịu được vuốt back bị huỷ, vốn gọi `viewDidAppear` lại mà không có `viewDidDisappear`), nên nếu hai màn chung mã thì `leave` của màn trên làm stack rỗng.

Ad full-screen làm màn bên dưới disappear rồi appear lại. Pod giữ màn đó trong stack suốt thời gian ad hiện và bỏ qua lần `enter` khi ad đóng, nên không có `_view` thứ hai và `current` không thành `unknown`. Nếu màn đó bị `leave` trong lúc ad hiện, pod chỉ áp dụng `leave` khi có `enter` của màn khác (hoặc ad mới bắt đầu), nên stack không giữ màn đã đóng.

Mọi màn user có thể tới đều phải được track. Màn không track được push lên trong lúc ad che một màn đã track có thể làm `_view` kế tiếp của màn đã track đó bị bỏ qua.

Stack giúp khi sheet `pageSheet` đóng: màn bên dưới không nhận `viewDidAppear`, nhưng sau `leave` của sheet thì `current` quay về màn đó.

Param ad:

- `showInterstitialAd(..., toScreen: String? = nil)` → param `to_screen`.
- `showAppOpenAd(..., placement: String? = nil)` (`splash` hoặc `resume`) → param `placement`.

User property: `FirebaseLogger.shared.setStandardUserProperties(isPremium:abBranch:)`.

**DEBUG validator** kiểm mọi event chuẩn:

- Tên khớp `[a-z0-9_]`, ≤ 40 ký tự.
- Action nằm trong [danh sách cố định](#2-danh-sách-action-cố-định).
- Vi phạm: DEBUG `assertionFailure`. Release log tên đã cắt còn 40 ký tự.

## Ví dụ ios099

App giả định `ios099` có 5 màn: `splash`, `onb1`, `home`, `create`, `paywall`.

Chuỗi event của một user từ mở app tới mua:

| # | Event | Param | Ghi chú |
|---|---|---|---|
| 1 | `ios099_splash_view` | | App gọi `ScreenTracker.enter("splash")` |
| 2 | `ios099_splash_aoa_show` | `placement=splash` | Pod tự bắn |
| 3 | `ios099_splash_aoa_close` | `placement=splash` | Pod tự bắn |
| 4 | `ios099_onb1_view` | | |
| 5 | `ios099_onb1_next` | | Sang bước kế |
| 6 | `ios099_home_view` | | |
| 7 | `ios099_ad_native_show` | `screen=home` | Ad dùng tên chung |
| 8 | `ios099_home_create_click` | | Nút dẫn sang `create` |
| 9 | `ios099_create_view` | | |
| 10 | `ios099_create_start` | `feature=filter` | Bắt đầu tác vụ |
| 11 | `ios099_create_success` | `feature=filter` | Tác vụ xong |
| 12 | `ios099_create_inter_show` | `to_screen=home` | Inter khi thoát. Pod tự bắn |
| 13 | `ios099_create_inter_close` | `to_screen=home` | Pod tự bắn |
| 14 | `ios099_create_back` | | Đường thoát |
| 15 | `ios099_home_view` | | Quay lại, `view` bắn lại |
| 16 | `ios099_paywall_view` | `source=home` | |
| 17 | `ios099_paywall_plan_click` | `plan=yearly`, `source=home` | |
| 18 | `ios099_paywall_buy_click` | `plan=yearly`, `source=home` | |
| 19 | `ios099_iap_trial_start` | `plan=yearly`, `source=home`, `value=0`, `currency=USD` | |
| 20 | `ios099_iap_purchase_success` | `plan=yearly`, `source=home`, `value=0`, `currency=USD` | |
| 21 | `ios099_paywall_close` | `source=home` | |

Các event dài nhất trong ví dụ: `ios099_iap_purchase_success` (27 ký tự), `ios099_create_inter_close` (25 ký tự). Đều ≤ 40.
