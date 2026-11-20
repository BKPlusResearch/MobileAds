# Attribution: AppsFlyer & Qonversion (subspec tuỳ chọn)

Từ `2.1.0`, AppsFlyer và Qonversion là **subspec tuỳ chọn**. `pod 'MobileAds'` chỉ cài
`Core` — đúng những gì bản trước cài, không kéo thêm SDK nào. App muốn dùng thì ghi tên
subspec trong `Podfile`:

```ruby
# Chỉ Core (mặc định, như cũ)
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git", :tag => '2.1.0'

# Core + AppsFlyer + Qonversion
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git", :tag => '2.1.0',
    :subspecs => ['Core', 'AppsFlyer', 'Qonversion']
```

Mọi subspec biên dịch vào cùng module `MobileAds`: vẫn `import MobileAds`, không import SDK.
Không cài subspec thì `AppsFlyerManager` / `QonversionManager` không tồn tại — gọi chúng là
lỗi biên dịch, không phải lỗi runtime.

| Subspec | SDK | Làm gì |
|---|---|---|
| `AppsFlyer` | `AppsFlyerFramework ~> 7.0.4` | Install attribution, session, `af_ad_view` kèm ad revenue, `af_purchase` cho lần mua trong app |
| `Qonversion` | `Qonversion ~> 6.18.0` | Subscription analytics ở chế độ `.analytics` |

## Khởi tạo

Trong `application(_:didFinishLaunchingWithOptions:)`, **sau** `EntitlementService.shared.bootstrap()`:

```swift
AppsFlyerManager.shared.configure(
    devKey: "<AppsFlyer dev key>",
    appleAppID: "<App Store ID dạng số>",
    launchOptions: launchOptions
)
QonversionManager.shared.configure(projectKey: "<Qonversion project key>")
```

Gọi AppsFlyer trước: khi cả hai subspec cùng được cài, Qonversion gắn AppsFlyer install ID
(`appsFlyerUserID`) vào user để đối chiếu doanh thu theo nguồn cài đặt.

Không cần forward purchase bằng tay. Mỗi manager tự đăng ký nhận sự kiện từ
`EntitlementService` khi được `configure`.

## Hành vi

### AppsFlyer

- **Chờ ATT.** Session chỉ `start()` khi ATT đã có câu trả lời (hoặc sau 60 giây), để install
  đầu tiên mang IDFA khi user cho phép. App vẫn tự xin ATT như cũ; manager chỉ chờ kết quả.
  Dùng `registerSessionReadyListener` của SDK 7.x — `start()` mỗi lần vào foreground.
- **`af_purchase`** chỉ cho lần mua qua `EntitlementService.purchase(_:)`, với
  `af_revenue` = số tiền thực bị trừ của transaction đó: `0` cho free trial, giá intro cho
  intro offer trả phí, còn lại là giá store. Kèm `af_currency`, `af_content_id` (product ID),
  `af_order_id` (transaction ID).
- **Không** ghi nhận gia hạn, refund hay mua trên thiết bị khác — thiết bị không thấy chúng
  tại thời điểm xảy ra. Muốn có doanh thu gia hạn trong AppsFlyer thì bật integration
  server-to-server từ Qonversion; khi đó **phải bỏ** `af_purchase` phía client, nếu không
  doanh thu bị đếm hai lần.
- **Ad revenue (`af_ad_view`).** Mỗi paid event AdMob mà `AdRevenueManager.logRevenue` nhận
  được, AppsFlyer nhận một in-app event `af_ad_view` kèm `af_revenue`, `af_currency` và
  `af_adrev_ad_type` — cùng lúc và cùng giá trị với Facebook `AD_IMPRESSION`, giống cách Adjust
  từng gửi event có revenue. Không dùng `logAdRevenue` (Ad Revenue theo impression của
  AppsFlyer). Không phải sửa call site nào. Test ad unit của Google không phát paid event, nên
  chỉ thấy event này với ad unit thật.
- `AppsFlyerManager.shared.logEvent(_:values:)` cho event khác; `appsFlyerUID` để lấy install ID.

### Qonversion

- `launchMode: .analytics`: `EntitlementService` vẫn là nơi duy nhất finish transaction và
  quyết định premium. Qonversion chỉ quan sát.
- Gửi đúng transaction vừa xảy ra: lần mua trong app và mọi transaction đến qua
  `Transaction.updates` (gia hạn, Ask to Buy, refund, mua trên thiết bị khác). Restore thành
  công thì sync toàn bộ.
- **Không sync lúc launch.** Qonversion đọc app receipt mỗi lần gửi; máy không có receipt
  (cài từ Xcode, simulator) thì nó yêu cầu refresh receipt — hiện prompt "Sign in to Apple
  Account". Chỉ gửi khi có transaction là tránh được việc này.
- Gia hạn khi app đóng: cấu hình App Store Server Notifications trỏ về Qonversion trên dashboard.

## Kiểm tra

- Log: `🚀 Qonversion initialized with userID: QON_…` khi launch.
- AppsFlyer: request tới `att.conversions.appsflyersdk.com` ngay sau khi trả lời ATT ở lần
  cài đầu, `att.launches.appsflyersdk.com` ở những lần foreground sau
  (`xcrun simctl spawn <udid> log show --predicate 'eventMessage CONTAINS "appsflyersdk.com"'`).
  Dùng SDK Integration Test trên dashboard AppsFlyer để xác nhận install.
- Mua bằng tài khoản sandbox → transaction hiện ở chế độ Sandbox trên dashboard Qonversion,
  event `af_purchase` hiện trong AppsFlyer.

## Ghi chú cho người bảo trì

Core không phụ thuộc SDK nào ở đây. Liên kết duy nhất là protocol nội bộ
`EntitlementTransactionObserver` (`MobileAds/IAP/EntitlementTransactionObservers.swift`):
`EntitlementService` thông báo sau khi đã xử lý xong, trên một task riêng, nên observer chậm
không làm trễ kết quả mua hay gia hạn. Thêm SDK attribution mới = một subspec mới với một
class tuân theo protocol này.
