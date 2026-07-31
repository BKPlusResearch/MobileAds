# Phase 7: Finalize & Verify

<!-- Updated: Validation Session 1 - Renamed from Phase 6, added IAPViewModel to file summary -->

**Priority:** P1
**Status:** Pending
**Effort:** 30min
**Depends on:** Phase 1–6

## Overview

Cập nhật podspec, tạo public API barrel file, và full build verification.

## Related Code Files

### Sửa
- [MobileAds.podspec](file:///Users/shjn/work_space/BKPlus/MobileAds/MobileAds.podspec)

### Tạo mới (optional)
- `MobileAds/SwiftUI/MobileAds+SwiftUI.swift` — barrel re-exports (nếu cần)

## Implementation Steps

### Step 1: Cập nhật `MobileAds.podspec`

Thêm SwiftUI framework dependency:

```ruby
spec.frameworks = "UIKit", "SwiftUI"  # Thêm SwiftUI
```

Cập nhật `spec.summary` và `spec.description` để mention SwiftUI support.

Cập nhật source files pattern nếu cần:
```ruby
spec.source_files = "MobileAds/**/*.{h,m,swift}"
```
→ Verify pattern này đã cover `MobileAds/SwiftUI/*.swift`

### Step 2: Full Build Verification

```bash
# 1. Pod lint
pod lib lint MobileAds.podspec --allow-warnings --verbose

# 2. Build cho iOS Simulator
xcodebuild -workspace Example.xcworkspace \
  -scheme MobileAds \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

### Step 3: File Summary

Sau khi hoàn thành tất cả phases:

| File | Action | Phase |
|------|--------|-------|
| `MobileAds/SwiftUI/ViewControllerResolver.swift` | NEW | 1 |
| `MobileAds/SwiftUI/BannerAdSwiftUI.swift` | NEW | 2 |
| `MobileAds/SwiftUI/InterstitialModifier.swift` | NEW | 3 |
| `MobileAds/SwiftUI/RewardedModifier.swift` | NEW | 3 |
| `MobileAds/SwiftUI/RewardedInterstitialModifier.swift` | NEW | 3 |
| `MobileAds/SwiftUI/NativeAdSwiftUI.swift` | NEW | 4 |
| `MobileAds/SwiftUI/AppOpenModifier.swift` | NEW | 5 |
| `MobileAds/SwiftUI/IAPViewModel.swift` | NEW | 6 |
| `AdMobHelper.swift` | MODIFY | 3 |
| `AdMobHelper+RewardedInterstitial.swift` | MODIFY | 3 |
| `AdMobHelper+FullScreenDelegate.swift` | MODIFY | 3 |
| `MobileAds.podspec` | MODIFY | 7 |

**Tổng: 8 files mới, 4 files sửa**

## Todo List

- [ ] Cập nhật `MobileAds.podspec` — thêm SwiftUI framework
- [ ] Verify source_files pattern cover SwiftUI/
- [ ] Full build verification
- [ ] Cập nhật README.md — thêm SwiftUI usage section

## Success Criteria

- `pod lib lint` pass
- Build thành công cho iOS 15+ target
- Không break existing UIKit apps (backward compat)
- Tất cả SwiftUI views/modifiers accessible qua `import MobileAds`
