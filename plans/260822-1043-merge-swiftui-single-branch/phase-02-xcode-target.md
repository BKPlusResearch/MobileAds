# Phase 02 — Compile layer SwiftUI

**Status:** done · **Commit:** `99fae53`

## Phát hiện dẫn tới phase này

`MobileAds.xcodeproj/project.pbxproj` **giống hệt nhau trên cả hai nhánh** và chứa
**0 tham chiếu** tới 7 file `MobileAds/SwiftUI/`. Project khai báo từng file nguồn
một (168 ref `.swift`, `objectVersion = 55`, không dùng synchronized folder của
Xcode 16).

Nghĩa là trên `ver/swiftUI`, code SwiftUI nằm ngoài target framework. Nó chỉ tới tay
người dùng qua glob `spec.source_files` khi consumer chạy `pod install` — **chưa ai
compile nó trong repo này**. Đây là rủi ro thật của cả kế hoạch gộp, không phải việc
dọn dẹp cho đẹp.

## Cách làm

Dùng gem `xcodeproj` (đi kèm CocoaPods) thay vì sửa pbxproj bằng tay:

```ruby
grp = mg['SwiftUI'] || mg.new_group('SwiftUI', 'SwiftUI')
files.each do |f|
  ref = grp.new_reference(f)
  target.source_build_phase.add_file_reference(ref)
end
```

Nhóm `SwiftUI` đặt theo đúng quy ước nhóm `IAP` sẵn có (`path` set, `name` nil,
`source_tree = "<group>"`).

## Validation

- Target sources: 43 → 50
- `xcodebuild build -workspace MobileAds.xcworkspace -scheme MobileAds -destination 'generic/platform=iOS Simulator'` → `** BUILD SUCCEEDED **`
- Cả 7 file sinh `.o` trong DerivedData — chứng minh được compile thật, không bị bỏ qua âm thầm:

```
AppOpenModifier.o  BannerAdSwiftUI.o  InterstitialModifier.o  NativeAdSwiftUI.o
RewardedInterstitialModifier.o  RewardedModifier.o  ViewControllerResolver.o
```

## Rollback

`git revert 99fae53` — chỉ đụng pbxproj, không đổi code.
