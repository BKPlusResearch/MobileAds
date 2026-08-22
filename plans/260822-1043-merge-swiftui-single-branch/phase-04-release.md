# Phase 04 — Push và release

**Status:** chờ duyệt · **Chưa chạy bất kỳ lệnh nào**

Đây là bước duy nhất không lùi được: đẩy tag ra ngoài và dời nhánh mà nhiều project
đang tiêu thụ.

## Trạng thái hiện tại (local)

```
new-MobileAds: 0a92da3 -> 78ff400   (fast-forward)
ver/swiftUI:   6de0d61 -> 78ff400   (fast-forward)
tag 2.0.0:     mới, trên 78ff400
```

Cả hai đều ff — đã verify bằng `git merge-base --is-ancestor`. Không cần force-push,
lịch sử không bị viết lại.

## Blast radius

Project track `ver/swiftUI` **không pin tag** sẽ nhận ở lần `pod update` kế tiếp:

| Thay đổi | Chiều |
|---|---|
| Firebase 12.13 → 12.18, GMA 13.3 → 13.8, Pangle 7.9 → 8.2, và loạt adapter khác | rủi ro — SDK bump thật, cần test lại |
| Fix `defer { is*Loading = false }` | lợi — hết kẹt cờ loading sau load fail |
| Fix app-open resume (3 defect) | lợi — hết chồng ad, hết kẹt preload |

Nên báo các team trước khi push, không push âm thầm.

## Các bước

```bash
git push origin new-MobileAds
git push origin ver/swiftUI
git push origin 2.0.0
```

Sau đó báo các project: chuyển từ track nhánh sang `:tag => '2.0.0'`.

## Acceptance criteria

- [ ] `git ls-remote --tags origin` có `2.0.0`
- [ ] Hai nhánh remote cùng trỏ `78ff400`
- [ ] Một app consumer chạy `pod update MobileAds` với tag pin và build được
- [ ] Các team đang track nhánh đã được báo

## Quyết định còn treo trước khi push

**`setEnableShowAds` không có hiệu lực ở mọi đường UIKit.** Pod chỉ lưu cờ; không
đường `load*`/`show*` nào đọc. Chỗ duy nhất đọc là modifier app-open SwiftUI. App set
cờ rồi tưởng đã tắt ads cho user premium thì user vẫn thấy quảng cáo.

Gộp fix vào `2.0.0` hay để `2.1.0`? Gộp thì tag này trọn vẹn hơn nhưng phạm vi rộng
ra (chạm mọi đường show). Để sau thì `2.0.0` đúng phạm vi "gộp nhánh" nhưng phát hành
kèm một cái bẫy đã biết.

## Rollback

Trước push: xoá tag local, reset nhánh — không ai thấy gì.

Sau push: `2.0.0` coi như bất biến, sai thì cắt `2.0.1`. Nhánh vẫn lùi được nhưng
phải force-push, và app track nhánh đã kịp `pod update` thì không lùi giúp được.
