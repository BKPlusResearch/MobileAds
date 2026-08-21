# Port entitlements-first IAP sang new-MobileAds

Status: done (2026-08-21) | Branch: new-MobileAds | Source: ver/swiftUI

## Contract

- **Outcome:** `new-MobileAds` chỉ còn một layer IAP — `EntitlementService` (entitlements-first, StoreKit 2). Legacy `IAPService` bị gỡ. Pod bump 2.0.0, build pass, docs khớp thực tại nhánh.
- **Constraints:** chỉ lấy phần IAP. Không kéo SwiftUI layer (nhánh này không có), không kéo mediation/ATT commit (đã cherry-pick trùng, hash khác). Giữ nguyên commit riêng của nhánh (`ae8c22f`, adapter shim). Không đụng 2911 file `.claude/`/`.agentkit/` đang deleted trong working tree.
- **Non-goals:** port SwiftUI wrappers; merge `ver/swiftUI`; viết StoreKit test configuration; rotate shared secret.
- **Acceptance:**
  1. `MobileAds/IAP/` chỉ chứa 3 file `Entitlement*.swift`
  2. `git grep -iE "IAPService|IAPViewModel|IAPProductIdentifiable|IAPError"` → 0 hit toàn repo
  3. `xcodebuild -workspace MobileAds.xcworkspace -scheme MobileAds` build succeeded
  4. podspec = 2.0.0, summary/description mô tả đúng layer duy nhất, **không** nhắc SwiftUI
  5. README có mục nâng cấp 1.x → 2.0 với bảng ánh xạ API + cảnh báo `isEntitled` bất đồng bộ

## Phases

| # | Việc | File |
|---|---|---|
| 1 | Cherry-pick `4521b46` + `cecb595` — thêm 3 file Entitlement + đăng ký pbxproj | phase-1 |
| 2 | Cherry-pick `c44b53b` dạng `-n`, chỉ giữ phần code: xoá 9 file legacy + dọn pbxproj | phase-2 |
| 3 | podspec 1.3.0 → 2.0.0, viết lại summary/description cho nhánh không SwiftUI | phase-3 |
| 4 | Viết lại docs tay: README (22 chỗ), code-standards (4), codebase-summary (1), project-overview-pdr (2), system-architecture (8), FirebaseLogger/README (1) | phase-4 |
| 5 | Verify: build + grep + rà public contract | phase-5 |

## Kết quả

Commits: `62c648d`, `d7ae295`, `4b47253`, `1fbfc0c`, `4b3ad3e`.

Cả 5 acceptance criteria đạt. `xcodebuild -scheme MobileAds` → BUILD SUCCEEDED; 3 file Entitlement compile vào target với 0 warning.

Ngoài phạm vi ban đầu, phải sửa thêm một lỗi có sẵn để build được: `c8590ed` đã xoá `PremiumAdsAdapterCompatibilityShim.swift` nhưng để sót 4 tham chiếu trong pbxproj, khiến nhánh không build được từ trước khi port. Sửa ở commit riêng `4b3ad3e`.

Bỏ không cherry-pick: phần docs của `c44b53b` (viết cho nhánh có SwiftUI layer) — docs được viết lại tay cho thực tại nhánh này.

## Rủi ro

- **pbxproj**: hai nhánh lệch 4 dòng → conflict khả năng thấp; nếu conflict thì resolve giữ cả mediation refs của nhánh này lẫn Entitlement refs mới.
- **Breaking change**: app đang dùng pod 1.3.0 sẽ không compile với 2.0.0. Đã được user chấp nhận ở gate brainstorm. Giảm nhẹ bằng upgrade guide + khuyến nghị pin tag cũ.
- **`c44b53b` phần docs**: cố tình bỏ, không cherry-pick — nội dung viết cho nhánh có SwiftUI.
