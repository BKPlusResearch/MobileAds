---
title: "SwiftUI Support Layer for MobileAds"
description: "Add SwiftUI wrapper layer using UIViewRepresentable and ViewModifier patterns while keeping UIKit core intact"
status: pending
priority: P1
effort: 7h
branch: new-MobileAds
tags: [feature, swiftui, ios]
blockedBy: []
blocks: []
created: 2026-04-22
---

# SwiftUI Support Layer for MobileAds

## Overview

Thêm SwiftUI wrapper layer cho MobileAds framework. Sử dụng `UIViewRepresentable` cho embedded ads (Banner, Native) và `ViewModifier` cho fullscreen ads (Interstitial, Rewarded, RewardedInterstitial, AppOpen). Giữ nguyên UIKit core — không breaking changes.

## Dependencies

- Google Mobile Ads SDK (GMA) — UIKit-only, bắt buộc wrapping
- SnapKit — dùng trong Native cache display
- Adjust/TikTok/Facebook/Firebase — không thay đổi

## Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | [Infrastructure Bridge](./phase-01-infrastructure-bridge.md) | Pending |
| 2 | [Banner Ad SwiftUI](./phase-02-banner-ad.md) | Pending |
| 3 | [Fullscreen Ad Modifiers](./phase-03-fullscreen-modifiers.md) | Pending |
| 4 | [Native Ad SwiftUI](./phase-04-native-ad.md) | Pending |
| 5 | [App Open Ad Modifier](./phase-05-app-open.md) | Pending |
| 6 | [IAPViewModel SwiftUI](./phase-06-iap-viewmodel.md) | Pending |
| 7 | [Finalize & Verify](./phase-07-finalize.md) | Pending |

## Validation Log

### Session 1 — 2026-04-22
**Trigger:** Post-plan validation interview
**Questions asked:** 5

#### Questions & Answers

1. **[Architecture]** ViewControllerResolver dùng `didMove(toParent:)` vs KVO `\.window` — chọn approach nào?
   - Options: didMove only | KVO only | Both (context-dependent)
   - **Answer:** Both — `didMove(toParent:)` cho VC-based bridge (fullscreen), KVO cho UIView-based bridge (embedded)
   - **Rationale:** Mỗi approach phù hợp với context khác nhau, không nên force 1 pattern

2. **[Scope]** IAPViewModel (ObservableObject wrapper) có thêm vào plan không?
   - Options: Thêm Phase 6 | Bỏ qua | Plan riêng
   - **Answer:** Thêm vào Phase 6
   - **Rationale:** IAPService đã UI-agnostic, chỉ cần thin wrapper — effort nhỏ, value cao

3. **[Assumptions]** iOS deployment target — `@available(iOS 15.0, *)` đúng không?
   - Options: iOS 15+ | iOS 14 | iOS 16+
   - **Answer:** iOS 15+
   - **Rationale:** SwiftUI onChange(of:) và scenePhase stable từ iOS 15

4. **[Risk]** KVO observe `\.window` trên UIView — fallback strategy?
   - Options: KVO + asyncAfter fallback | KVO only | Bỏ KVO dùng onAppear
   - **Answer:** KVO primary + `asyncAfter(0.1)` fallback
   - **Rationale:** KVO có thể unreliable trên một số iOS versions, cần safety net

5. **[Tradeoff]** Fullscreen modifiers: load-on-demand vs preload?
   - Options: Load-on-demand | Preload API | Host app preload
   - **Answer:** Load-on-demand cho MVP
   - **Rationale:** KISS — host app có thể tự preload nếu muốn UX tốt hơn

#### Confirmed Decisions
- **VC Bridge pattern**: Dual approach (didMove + KVO) — context-dependent
- **IAPViewModel**: Added to Phase 6
- **iOS target**: iOS 15.0+
- **KVO fallback**: asyncAfter(0.1) safety net
- **Preload strategy**: Load-on-demand MVP, host app có thể tự preload

#### Action Items
- [x] Thêm Phase 6: IAPViewModel
- [x] Rename Phase 6 → Phase 7 (Finalize)
- [x] Update BannerAdSwiftUI: thêm asyncAfter fallback cho KVO
- [x] Update plan.md effort: 6h → 7h
