# Phase 2: Banner Ad SwiftUI

**Priority:** P1
**Status:** Pending
**Effort:** 1h
**Depends on:** Phase 1

## Overview

<!-- Updated: Validation Session 1 - Added asyncAfter fallback for KVO -->

Wrap `BannerAdView` (UIKit) trong `UIViewRepresentable` cho SwiftUI.

## Key Insights (từ review)

- ❌ **Race condition**: `updateUIView` gọi khi view chưa có `window` → `rootViewController` = nil
- ✅ **Fix**: Dùng `Coordinator` + `didMoveToWindow` notification thay vì load trong `updateUIView`
- `BannerAdView.loadAd()` cần: `adUnitID`, `rootViewController`, `isCollapsible`, `collapsiblePlacement`
- Banner đã có cache logic nội bộ (1h expiry)

## Related Code Files

### Tạo mới
- `MobileAds/SwiftUI/BannerAdSwiftUI.swift`

### Tham chiếu (không sửa)
- [BannerAdView.swift](file:///Users/shjn/work_space/BKPlus/MobileAds/MobileAds/AdMobHelper/BannerAdView.swift) — `loadAd(adUnitID:rootViewController:isCollapsible:collapsiblePlacement:)`

## Implementation Steps

### 1. Tạo `MobileAds/SwiftUI/BannerAdSwiftUI.swift`

```swift
import SwiftUI

@available(iOS 15.0, *)
public struct BannerAdSwiftUI: UIViewRepresentable {
    let adUnitID: AdUnitIdentifiable
    var isCollapsible: Bool = false
    var collapsiblePlacement: BannerCollapsiblePlacement = .bottom

    public init(
        adUnitID: AdUnitIdentifiable,
        isCollapsible: Bool = false,
        collapsiblePlacement: BannerCollapsiblePlacement = .bottom
    ) {
        self.adUnitID = adUnitID
        self.isCollapsible = isCollapsible
        self.collapsiblePlacement = collapsiblePlacement
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> BannerAdView {
        let view = BannerAdView()
        // Lưu config vào coordinator
        context.coordinator.adUnitID = adUnitID
        context.coordinator.isCollapsible = isCollapsible
        context.coordinator.collapsiblePlacement = collapsiblePlacement

        // Observe khi view được add vào window
        context.coordinator.observation = view.observe(
            \.window, options: [.new]
        ) { view, _ in
            guard view.window != nil else { return }
            context.coordinator.loadAdIfNeeded(in: view)
        }

        // Fallback: asyncAfter(0.1) nếu KVO không fire (per Validation Q4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.loadAdIfNeeded(in: view)
        }

        return view
    }

    public func updateUIView(_ uiView: BannerAdView, context: Context) {
        // Chỉ reload nếu adUnitID thay đổi
        let currentID = adUnitID.adUnitIDString
        if context.coordinator.loadedAdUnitID != currentID {
            context.coordinator.adUnitID = adUnitID
            context.coordinator.isCollapsible = isCollapsible
            context.coordinator.collapsiblePlacement = collapsiblePlacement
            context.coordinator.loadedAdUnitID = nil // Reset để load lại
            context.coordinator.loadAdIfNeeded(in: uiView)
        }
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject {
        var adUnitID: AdUnitIdentifiable?
        var isCollapsible: Bool = false
        var collapsiblePlacement: BannerCollapsiblePlacement = .bottom
        var loadedAdUnitID: String?
        var observation: NSKeyValueObservation?

        func loadAdIfNeeded(in view: BannerAdView) {
            guard let adUnitID = adUnitID,
                  loadedAdUnitID != adUnitID.adUnitIDString,
                  let vc = view.nearestViewController ?? view.window?.rootViewController
            else { return }

            loadedAdUnitID = adUnitID.adUnitIDString
            view.loadAd(
                adUnitID: adUnitID,
                rootViewController: vc,
                isCollapsible: isCollapsible,
                collapsiblePlacement: collapsiblePlacement
            )
        }

        deinit {
            observation?.invalidate()
        }
    }
}
```

**Giải quyết race condition bằng cách nào?**
1. KVO observe `\.window` trên BannerAdView
2. Khi `window != nil` → view đã trong hierarchy → `nearestViewController` sẽ trả VC
3. `loadedAdUnitID` ngăn load lặp
4. `updateUIView` chỉ reload khi `adUnitID` thực sự thay đổi

### Usage Example

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            // Content
            Text("Hello")

            // Banner ở bottom
            BannerAdSwiftUI(
                adUnitID: AppAdUnit.banner,
                isCollapsible: true,
                collapsiblePlacement: .bottom
            )
            .frame(height: 60)
        }
    }
}
```

## Todo List

- [ ] Tạo `MobileAds/SwiftUI/BannerAdSwiftUI.swift`
- [ ] Verify KVO observation hoạt động đúng lifecycle
- [ ] Build verify

## Success Criteria

- Banner load thành công trong SwiftUI view
- Không load lặp khi SwiftUI re-render
- Load lại khi `adUnitID` thay đổi
- Collapsible banner hoạt động

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| KVO `\.window` không fire | Ad không load | Fallback: `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)` |
| `nearestViewController` nil | Ad không load | Fallback: `view.window?.rootViewController` |
| Memory leak qua observation | Leak | `deinit` invalidate observation |
