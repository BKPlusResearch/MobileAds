# Phase 01 — Merge và resolve

**Status:** done · **Commit:** `6615b7c`

## Mục tiêu

Một commit là hậu duệ của cả `new-MobileAds` lẫn `ver/swiftUI`, mang code SwiftUI
nhưng giữ trạng thái mới hơn của dòng UIKit.

## Cách làm

```bash
git checkout -b merge/swiftui-into-uikit new-MobileAds
git merge ver/swiftUI --no-commit --no-ff
```

10 conflict: `.gitignore`, `MobileAds.podspec`, `Podfile.lock`, `README.md`, 6 file
`docs/`.

## Resolve

| File | Lấy | Lý do |
|---|---|---|
| `MobileAds.podspec` | ours (dep block) | pin SDK mới; nhánh SwiftUI cũ hơn |
| `Podfile.lock` | ours | khớp pin mới |
| `docs/*` | ours | bản cập nhật 2.0.0 chính xác hơn |
| `README.md` | ours | bản đã sửa nhiều claim sai; nhánh SwiftUI hầu như không tài liệu hoá layer của chính nó (1 bullet + 1 snippet) |
| `.gitignore` | hợp nhất tay | giữ `.claude/`, `.agentkit/` của ours + `.repomixignore` của theirs; **không** ignore `plans` vì ours track có chủ đích |

Sau resolve, sửa `spec.source`/`spec.homepage` → `BKPlusResearch/MobileAds`.

## File Swift tự merge — đã verify tay

`AdMobHelper+Rewarded.swift` là chỗ nguy hiểm nhất: nhánh SwiftUI vừa **thêm**
`showLoading` vừa **gỡ** `defer`. Kết quả merge giữ cả `showLoading` lẫn `defer`,
không nhân đôi việc clear cờ — đúng như mong muốn.

## Validation

```bash
grep -rn "defer { is.*Loading = false }" MobileAds/AdMobHelper/   # 4 hit
grep -c "spec.dependency" MobileAds.podspec                        # 20, không nhân đôi
grep -rn "rewardedInterstitialAdStatusCallback" MobileAds/         # 9 hit, đủ 4 site delegate
ls MobileAds/SwiftUI/                                              # 7 file
```

Kết quả: `git log -1 --format='%p'` → `0a92da3 6de0d61` (hai parent).

## Rollback

Nhánh `merge/swiftui-into-uikit` tách rời; xoá nhánh là xong, chưa đụng nhánh chính.
