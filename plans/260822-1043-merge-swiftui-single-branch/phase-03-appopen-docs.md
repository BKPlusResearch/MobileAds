# Phase 03 — Sửa app-open + docs

**Status:** done · **Commits:** `3133f05`, `7671891`, `78ff400`

## Ba defect trong `AppOpenModifier`

Phát hiện khi đọc code để viết tài liệu — không phải mục tiêu ban đầu của phase.

**1. `.active` không chỉ đến từ background.** Nó còn đến từ `.inactive`: kéo control
center, mở app switcher, có cuộc gọi đến. Modifier cũ show ad ở mọi lần `.active`,
nên một cú kéo control center cũng bung ad full-screen. Đường UIKit miễn nhiễm vì
`willEnterForegroundNotification` không fire trong các trường hợp đó.

**2. `.active` show mà không kiểm `shouldSkipNextAppResume`.** Cờ chỉ được đọc ở
nhánh `.background` để quyết preload. Vừa xem interstitial quay lại app vẫn bị chồng
thêm ad — đúng tình huống cờ này sinh ra để chặn.

**3. Không ai reset cờ.** Cờ bật bởi mỗi lần show full-screen (3 site), reset chỉ ở
`resetAppResumeSkipFlag()` và `clearAllAds()` — modifier không gọi cái nào. Sau ad
full-screen đầu tiên cờ kẹt `true` vĩnh viễn, nhánh `.background` thôi preload.

## Quyết định: sửa trong pod, trước khi tag

Tag `2.0.0` chưa push nên sửa lúc này miễn phí; để sau là cắt `2.0.1` ngay và bắt mọi
consumer pin lại. Quan trọng hơn: điểm bán của bản gộp là "một pod, hai surface, cùng
hành vi" — để `.appOpenAd` âm thầm bỏ qua cờ mà README mô tả như bảo vệ cấp pod chính
là mâu thuẫn mà việc gộp sinh ra để xoá. Phương án "app tự gọi
`resetAppResumeSkipFlag()`" bắt mọi app SwiftUI viết lại đúng đoạn lifecycle glue mà
modifier sinh ra để gánh hộ.

## Cách sửa

Thêm `@State private var didEnterBackground`; `.background` set cờ này, `.active`
yêu cầu nó trước khi show rồi tiêu thụ `shouldSkipNextAppResume` và gọi
`resetAppResumeSkipFlag()`. Gộp hai chỗ gọi preload trùng nhau vào helper `preload()`.

Không đổi API công khai.

## Validation — bốn kịch bản

| Kịch bản | Mong đợi | Đường đi |
|---|---|---|
| Khởi động lần đầu | chỉ preload | `hasPreloaded = false` → preload, return |
| Peek control center | không show | `didEnterBackground = false` → return |
| Background thật | preload rồi show | `.background` preload → `.active` show |
| Sau interstitial | bỏ lượt, reset cờ | `.active` thấy cờ → reset, return; lần background sau preload lại |

`xcodebuild` xanh sau khi sửa.

## Docs

- README: thêm mục SwiftUI (signature thật của 2 view + 4 modifier), sửa mục Rewarded
  Interstitial (giờ có `statusCallback`), install snippet trỏ tag `2.0.0`
- `docs/`: thêm layer SwiftUI vào module map + sơ đồ kiến trúc, cập nhật đếm file
  (47 → 49), thay open question đã giải bằng open item còn lại
- Gỡ doc comment cũ nhắc `iapVM.isPurchased` (type đã bị xoá ở 2.0.0)

## Ngoài phạm vi, đã ghi lại

`release-manifest.json` (366 KB) bỏ track theo yêu cầu — còn trên đĩa, đã ignore.
