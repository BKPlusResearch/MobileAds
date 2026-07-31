# Phase 1: Infrastructure Bridge

**Priority:** P1 — Must Complete First
**Status:** Pending
**Effort:** 45min

## Overview

Tạo VC bridge để SwiftUI views có thể resolve `UIViewController` — dependency bắt buộc của GMA SDK cho tất cả ad types.

## Key Insights

- GMA SDK yêu cầu `UIViewController` cho: `BannerView.rootViewController`, `AdLoader(rootViewController:)`, `FullScreenAd.present(from:)`
- SwiftUI không expose VC trực tiếp → cần bridge
- `configAds(from: nil)` đã hoạt động — UMP tự resolve presenting VC → **KHÔNG cần overload mới**

## Related Code Files

### Tạo mới
- `MobileAds/SwiftUI/ViewControllerResolver.swift`

### Không sửa
- ~~`AdMobHelper.swift`~~ — `configAds(from: nil)` đã đủ, không cần overload

## Architecture

```
SwiftUI View
    └── ViewControllerResolver (UIViewControllerRepresentable)
            └── resolve UIViewController from hierarchy
                    └── callback to parent via onResolve closure
```

## Implementation Steps

### 1. Tạo `MobileAds/SwiftUI/ViewControllerResolver.swift`

```swift
import SwiftUI

/// Bridge để resolve UIViewController từ SwiftUI hierarchy.
/// Dùng nội bộ bởi BannerAdSwiftUI, NativeAdSwiftUI và Fullscreen modifiers.
@available(iOS 15.0, *)
struct ViewControllerResolver: UIViewControllerRepresentable {
    let onResolve: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        // Schedule callback sau khi VC được add vào hierarchy
        DispatchQueue.main.async {
            if let parent = vc.parent ?? vc.presentingViewController {
                onResolve(parent)
            } else {
                onResolve(vc)
            }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - UIView Extension (fallback)

extension UIView {
    /// Traverse responder chain để tìm VC gần nhất
    var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController {
                return vc
            }
            responder = next
        }
        return nil
    }
}
```

**Tại sao dùng `DispatchQueue.main.async`?**
- `makeUIViewController` được gọi trước khi VC add vào parent hierarchy
- `async` đảm bảo chờ 1 runloop tick → VC đã có parent

## Todo List

- [ ] Tạo `MobileAds/SwiftUI/ViewControllerResolver.swift`
- [ ] Build verify — `@available(iOS 15.0, *)` compiles

## Success Criteria

- `ViewControllerResolver` resolves non-nil VC trong SwiftUI app
- `UIView.nearestViewController` trả về VC đúng khi view trong window hierarchy
- No breaking changes cho existing UIKit API

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| VC chưa có parent khi resolve | Ad load fail | `DispatchQueue.main.async` delay 1 tick |
| iOS 14 deploy target | Compile error | `@available(iOS 15.0, *)` guard |
