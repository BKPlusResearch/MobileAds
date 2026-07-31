# Phase 4: Native Ad SwiftUI

**Priority:** P2
**Status:** Pending
**Effort:** 1h
**Depends on:** Phase 1

## Overview

Wrap `NativeAdService` display trong `UIViewRepresentable` cho SwiftUI. Native ads sử dụng XIB-based views (Small/Medium) nên wrapper cần quản lý container view lifecycle cẩn thận.

## Key Insights (từ review)

- ❌ **Plan cũ gọi sai API**: `AdMobHelper.shared.loadNativeAd(containerView:...)` — method này nằm ở `AdMobHelper+NativeCache.swift`, KHÔNG phải ở `AdMobHelper+Native.swift`
- ✅ **API đúng**: `AdMobHelper.shared.loadNativeAd(containerView:adUnitID:rootViewController:viewType:configuration:enableCache:statusCallback:)` từ `+NativeCache` extension
- Native view dùng XIB (NativeAdViewSmall.xib, NativeAdViewMedium.xib)
- `NativeAdService.NativeAdViewType`: `.small`, `.medium`
- Shimmer loading đã built-in trong `NativeAdService`

## Related Code Files

### Tạo mới
- `MobileAds/SwiftUI/NativeAdSwiftUI.swift`

### Tham chiếu (không sửa)
- [AdMobHelper+NativeCache.swift](file:///Users/shjn/work_space/BKPlus/MobileAds/MobileAds/AdMobHelper/AdMobHelper+NativeCache.swift#L288-L310) — `loadNativeAd(containerView:...)`
- [NativeAdService.swift](file:///Users/shjn/work_space/BKPlus/MobileAds/MobileAds/AdMobHelper/NativeAdService.swift#L117-L130) — `NativeAdViewType` enum

## Implementation Steps

### 1. Tạo `MobileAds/SwiftUI/NativeAdSwiftUI.swift`

```swift
import SwiftUI

@available(iOS 15.0, *)
public struct NativeAdSwiftUI: UIViewRepresentable {
    let adUnitID: AdUnitIdentifiable
    let viewType: NativeAdService.NativeAdViewType
    var configuration: NativeAdConfiguration?
    var enableCache: Bool
    var onLoaded: ((Bool) -> Void)?

    public init(
        adUnitID: AdUnitIdentifiable,
        viewType: NativeAdService.NativeAdViewType = .medium,
        configuration: NativeAdConfiguration? = nil,
        enableCache: Bool = true,
        onLoaded: ((Bool) -> Void)? = nil
    ) {
        self.adUnitID = adUnitID
        self.viewType = viewType
        self.configuration = configuration
        self.enableCache = enableCache
        self.onLoaded = onLoaded
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        // Lưu config vào coordinator
        context.coordinator.adUnitID = adUnitID
        context.coordinator.viewType = viewType
        context.coordinator.configuration = configuration
        context.coordinator.enableCache = enableCache
        context.coordinator.onLoaded = onLoaded

        // Observe window attachment
        context.coordinator.observation = container.observe(
            \.window, options: [.new]
        ) { view, _ in
            guard view.window != nil else { return }
            context.coordinator.loadAdIfNeeded(in: view)
        }

        return container
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        // Reload nếu adUnitID hoặc viewType thay đổi
        let currentKey = "\(adUnitID.adUnitIDString)_\(viewType)"
        if context.coordinator.loadedKey != currentKey {
            context.coordinator.adUnitID = adUnitID
            context.coordinator.viewType = viewType
            context.coordinator.configuration = configuration
            context.coordinator.enableCache = enableCache
            context.coordinator.onLoaded = onLoaded
            context.coordinator.loadedKey = nil
            context.coordinator.loadAdIfNeeded(in: uiView)
        }
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject {
        var adUnitID: AdUnitIdentifiable?
        var viewType: NativeAdService.NativeAdViewType = .medium
        var configuration: NativeAdConfiguration?
        var enableCache: Bool = true
        var onLoaded: ((Bool) -> Void)?
        var loadedKey: String?
        var observation: NSKeyValueObservation?

        func loadAdIfNeeded(in containerView: UIView) {
            guard let adUnitID = adUnitID,
                  loadedKey != "\(adUnitID.adUnitIDString)_\(viewType)",
                  let vc = containerView.nearestViewController ?? containerView.window?.rootViewController
            else { return }

            loadedKey = "\(adUnitID.adUnitIDString)_\(viewType)"

            // ✅ Gọi đúng API từ AdMobHelper+NativeCache
            AdMobHelper.shared.loadNativeAd(
                containerView: containerView,
                adUnitID: adUnitID,
                rootViewController: vc,
                viewType: viewType,
                configuration: configuration,
                enableCache: enableCache,
                statusCallback: onLoaded
            )
        }

        deinit {
            observation?.invalidate()
        }
    }
}
```

### Usage Example

```swift
struct ArticleView: View {
    var body: some View {
        ScrollView {
            // Content
            Text("Article content...")

            // Native ad
            NativeAdSwiftUI(
                adUnitID: AppAdUnit.nativeMedium,
                viewType: .medium,
                enableCache: true
            )
            .frame(height: 300)

            // Small native ad
            NativeAdSwiftUI(
                adUnitID: AppAdUnit.nativeSmall,
                viewType: .small
            )
            .frame(height: 120)
        }
    }
}
```

## Todo List

- [ ] Tạo `MobileAds/SwiftUI/NativeAdSwiftUI.swift`
- [ ] Verify gọi đúng `AdMobHelper+NativeCache` API
- [ ] Build verify

## Success Criteria

- Native Small/Medium hiển thị đúng trong SwiftUI
- Shimmer loading view hiển thị khi đang load
- Cache hoạt động (load lần 2 nhanh hơn)
- Không load lặp khi SwiftUI re-render

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| XIB load fail (bundle mismatch) | Blank view | `Bundle.main` vs framework bundle — cần verify |
| Container view height không đủ | Layout cut off | Host app phải set `.frame(height:)` |
| SnapKit constraints conflict | Layout break | NativeAdService dùng SnapKit nội bộ — OK |
