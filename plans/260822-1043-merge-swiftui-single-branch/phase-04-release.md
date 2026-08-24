# Phase 04 — Push và release

**Status:** chờ duyệt · **Chưa chạy bất kỳ lệnh nào**

Đây là bước duy nhất không lùi được: đẩy tag ra ngoài và dời nhánh mà nhiều project
đang tiêu thụ.

## Trạng thái hiện tại (local)

```
new-MobileAds: 0a92da3 -> <tip>    (fast-forward)
ver/swiftUI:   6de0d61 -> <tip>    (fast-forward)
tag 2.0.0:     mới, trên 78ff400
```

Cả hai đều ff — đã verify bằng `git merge-base --is-ancestor`. Không cần force-push,
lịch sử không bị viết lại.

Tag nằm trên `78ff400` — commit code + docs cuối cùng. Nhánh đi tiếp một commit nữa
là chính plan này; plan không nằm trong pod (`spec.source_files` chỉ phủ `MobileAds/`)
nên không ảnh hưởng nội dung phát hành.

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

## Quyết định đã chốt trước khi push

**Gỡ `setEnableShowAds`.** Cờ này chỉ được *lưu*, không đường `load*`/`show*` nào đọc;
chỗ duy nhất đọc là modifier app-open SwiftUI, mà modifier đó đã có tham số `isEnabled:`
riêng. Phương án đã chọn: gỡ hẳn `setEnableShowAds(_:)` và `checkEnableShowAds()` khỏi
pod thay vì làm nó có hiệu lực pod-wide — không phải chạm mọi đường show, và xoá luôn
cái bẫy "đặt cờ rồi tưởng đã tắt ads".

Hệ quả: breaking so với `1.4.0`. App đang gọi hai hàm này vỡ compile và phải tự gate
call site bằng trạng thái premium của mình. Đã ghi trong README mục
"Tắt ads cho user premium".

## Rollback

Trước push: xoá tag local, reset nhánh — không ai thấy gì.

Sau push: `2.0.0` coi như bất biến, sai thì cắt `2.0.1`. Nhánh vẫn lùi được nhưng
phải force-push, và app track nhánh đã kịp `pod update` thì không lùi giúp được.
