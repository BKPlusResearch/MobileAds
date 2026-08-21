---
title: "Red team đục thủng plan tôi vừa viết: 8 Critical, 3 là lỗi thiết kế"
date: 2026-08-14
summary: "3 reviewer tìm 27 finding trên plan remove-legacy-iap; 20 accept, 1 reject sau khi tự verify. Plan viết lại từ 5 phase/32h thành 7 phase/68h."
---

# Red team đục thủng plan tôi vừa viết: 8 Critical, 3 là lỗi thiết kế

## What happened

Viết plan xóa legacy IAP layer khỏi MobileAds pod (`260814-1621-remove-legacy-iap`). Chạy red-team 3 reviewer (Security Adversary/Fact Checker, Failure Mode Analyst/Flow Tracer, Assumption Destroyer/Scope Auditor). 27 finding thô → dedupe → 20 accept, 1 reject. **8 Critical.**

Plan viết lại: 5 phase/32h → 7 phase/68h.

## Ba Critical là lỗi thiết kế của tôi, không phải chi tiết bỏ sót

**E2 sai.** Tôi quyết "base không giao hàng hộ — host tự cộng coin ở nhánh `purchase()`" vì nó nghe sạch về kiến trúc. Nhưng StoreKit giao consumable qua `Transaction.updates` trong ít nhất 4 tình huống thường gặp (Ask to Buy duyệt sau, app bị kill, mua máy khác, interrupted), và ở đó host **không thấy transaction nào cả** — `handle()` finish rồi bỏ đi. Tiền trừ, coin không tồn tại, không có redelivery.

Cay nhất: comment cảnh báo đúng vấn đề này **đã có sẵn** trong `EntitlementService.swift:268-272`. Tôi tự viết nó ở plan trước (sau một vòng review khác), rồi bỏ qua chính nó khi viết plan này.

**Goal 3 không thể tồn tại.** Tôi viết đồng thời "28 callsite không đổi dòng nào" và "chỉ mở khoá khi `verification == .verified`". `Bool` không mang nổi ba trạng thái. Hai criteria nằm cách nhau 5 dòng trong cùng một checklist và loại trừ nhau. Tệ hơn: không có gì post notification khi verify xong lúc launch → subscriber thấy ads suốt session.

**Đếm sai app.** "4 app" là con số tôi nhận từ plan trước mà không tự kiểm. Grep toàn workspace ra **5** app dùng IAP của pod (`silly-clone`, branch `fbsdk`, 25 file) và **4** repo trỏ `:path` vào working tree của pod chứ không phải 1.

## Reviewer cũng sai, và verify cứu được 40 file

Failure Mode Analyst nói `iOS-clean-phone-bkplus` mất `IAPViewModel` khi xóa → +16h, 16 file. Verify: app đó có `IAPViewModel` **của riêng nó** (`CleanPhone/Features/IAP/IAPViewModel.swift`), gọi `IAPViewModel(iapService:)` trong khi pod's `init()` không nhận tham số; grep pod IAP symbols → 0 hit. Reject.

Bài học đối xứng: reviewer hostile tìm ra thứ tôi mù, nhưng nhận claim của nó không kiểm thì plan phồng vô cớ. Cả hai chiều đều phải verify.

## Decision

- Đảo E2 → E2': base gọi `onUnfinished(receipt) async -> Bool` do host cấp, **trước** `finish()`, chỉ finish khi host trả `true`. Mức đảo tối thiểu, base vẫn không biết app bán gì.
- Bỏ Goal 3, thay bằng shim tri-state `premiumState() -> (isPremium, isKnown)` + sink post notification.
- Thêm Phase 0: kiểm kê consumer + rebase branch pilot lên `new-MobileAds` (nó thiếu 8 commit, gồm ATT-before-SDK-init) + cắt 4 `:path`.
- Thêm Phase 5 cho silly-clone.
- Tách E7 → E7': gỡ wiring `sharedSecret` ≠ rotate secret. Secret là literal hardcode, còn trong binary đã ship và git history. Rotate là issue riêng, plan này không đóng.
- P3→P4→P5 tuần tự, không song song (cùng sửa một branch base thì đổi base làm gate hết giá trị).
- Gate consumable riêng ở P4 — P2 chạy trên xmascall mà app đó không bán consumable, nên gate "cứng" mù đúng chỗ nguy nhất.

## Next steps

- Trả lời 6 unresolved question trước khi cook. Hai câu chặn cứng: ai chạy checklist trên thiết bị thật, và silly-clone còn sống không.
- Xác nhận 2 coin SKU của themearts đăng ký đúng loại Consumable ở App Store Connect — nếu sai, guard `productType` không cứu và một gói coin cấp premium vĩnh viễn.
- Mở issue rotate 2 shared secret.

> Historical work record — not durable authority. Prefer docs/specs/ADRs for current decisions.
