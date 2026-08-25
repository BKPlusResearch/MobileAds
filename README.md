## MobileAds

MobileAds is a Swift framework that wraps the Google Mobile Ads SDK and provides:

- A central helper `AdMobHelper` to manage SDK init, consent, and all ad formats.
- Strongly-typed status callbacks for Interstitial, Rewarded, App Open, and Banner.
- A `NativeAdService` with configurable XIB-based native ad views.
- A flexible `AdUnitIdentifiable` protocol so each app can define its own ad unit enum.
- **UIKit and SwiftUI from one pod** — SwiftUI gets `UIViewRepresentable` banner/native
  views plus `.interstitialAd` / `.rewardedAd` / `.rewardedInterstitialAd` / `.appOpenAd`
  modifiers over the same `AdMobHelper`. Xem [docs/ads-swiftui.md](docs/ads-swiftui.md).

## Tài liệu

Trang này giữ những gì **cả UIKit lẫn SwiftUI dùng chung**: cài đặt, khai báo ad unit,
`configAds`, quy tắc full-screen, cache/giao diện native, cờ bật/tắt ads. Phần riêng
của từng surface nằm ở ba tài liệu bên dưới.

| Tài liệu | Nội dung |
|---|---|
| [docs/ads-uikit.md](docs/ads-uikit.md) | `BannerAdView`, Interstitial, Rewarded, Rewarded Interstitial, native call site UIKit, App Open (app tự nối dây) |
| [docs/ads-swiftui.md](docs/ads-swiftui.md) | Cầu nối `configAds`, `BannerAdSwiftUI`, `NativeAdSwiftUI`, 3 modifier full-screen, `.appOpenAd` |
| [docs/in-app-purchases.md](docs/in-app-purchases.md) | `EntitlementService`, consumables, checklist sandbox, nâng cấp 1.x → 2.0 |
| [NATIVE_AD_CACHE.md](NATIVE_AD_CACHE.md) | Chi tiết cơ chế cache native ad |
| [MobileAds/AdRevenue/README.md](MobileAds/AdRevenue/README.md) | Ad revenue fan-out (Firebase / TikTok / Facebook), migration 2.0.0 → 2.0.1 |

## Tính năng chính

- **Quản lý AdMob tập trung với `AdMobHelper`**
  - Khởi tạo SDK và xử lý consent qua `configAds(from:)`.
  - Hỗ trợ: Interstitial, Rewarded, Rewarded Interstitial, App Open, Native (banner đi qua `BannerAdView`).

- **API rõ ràng cho từng loại quảng cáo**
  - `BannerAdView.loadAd(...)` + callback trạng thái `BannerAdStatus`.
  - `loadInterstitialAd(...)` / `showInterstitialAd(...)` với `InterstitialAdStatus`.
  - `loadRewardedAd(...)` / `showRewardedAd(...)` với `RewardedAdStatus`.
  - `loadRewardedInterstitialAd(...)` / `showRewardedInterstitialAd(...)`.
  - `loadAppOpenAd(...)` / `showAppOpenAd(...)` với `AppOpenAdStatus`.

- **Tự do định nghĩa Ad Unit ID trong app**
  - Protocol `AdUnitIdentifiable`.
  - App tự define `enum AppAdUnitID` với test ID & production ID theo nhu cầu.

- **Native Ads chuyên sâu với `NativeAdService`**
  - Load và gắn native ad vào container view với XIB (`NativeAdViewSmall`, `NativeAdViewMedium`).
  - Hỗ trợ loading view (`NativeAdSmallLoadingView`).

- **🆕 Native Ad Cache System**
  - Preload native ads cho hiển thị tức thì, loại bỏ thời gian chờ loading.
  - Cache tự động expire sau 1 giờ (theo policy của AdMob).
  - Type-safe cache keys định nghĩa riêng cho từng app.
  - Tự động fallback về network nếu cache không available.
  - Xem chi tiết: [NATIVE_AD_CACHE.md](NATIVE_AD_CACHE.md)

- **Tuỳ biến giao diện Native Ad toàn app**
  - Singleton `NativeAdConfiguration.shared` để cấu hình font, màu chữ, màu nền, gradient nút CTA.

- **🆕 `BannerAdView` — Banner tự quản lý (không dùng singleton)**
  - Drop-in `UIView` subclass tích hợp sẵn shimmer loading (`BannerAdLoadingView`).
  - Tự skip nếu banner đã được load, tự dọn sạch khi reuse.
  - Không đụng đến `AdMobHelper.shared` → tránh singleton conflict khi nhiều banner cùng lúc.
  - API đơn giản: `loadAd(adUnitID:rootViewController:isCollapsible:collapsiblePlacement:)` và `clearAd()`.

- **Trạng thái & loading view rõ ràng**
  - Các flag `isInterstitialLoading`, `isRewardedLoading`, `isAppOpenLoading`, `isBannerLoading`, ...
  - Loading overlay cho Interstitial, Rewarded, App Open.

- **🆕 In-App Purchase entitlements-first với StoreKit 2 (2.0.0 — breaking)**
  - Singleton `EntitlementService.shared` — layer IAP duy nhất của pod.
  - Entitlement suy ra từ `Transaction.currentEntitlements` mỗi lần check, **không cache**, nên cài lại app / đổi máy / refund / Family Sharing do StoreKit lo.
  - Fetch products, purchase, restore với async/await; outcome có kiểu thay vì `throw`.
  - Hook `onUnfinished` để credit consumable **trước khi** finish transaction.
  - App tự cấp product ID qua `EntitlementConfig`; pod không hardcode product nào và không hiện UI.
  - ⚠️ Layer `IAPService` cũ đã bị gỡ ở 2.0.0 — xem [nâng cấp 1.x → 2.0](docs/in-app-purchases.md#nâng-cấp-từ-1x-lên-20).

- **🆕 Ad revenue tracking tự động với `AdRevenueManager` (2.0.1)**
  - Mọi `paidEventHandler` (Banner, Interstitial, Rewarded, Rewarded Interstitial, App Open, Native) tự bắn revenue — app không cần code thêm.
  - Ba đích đến: Firebase Analytics (`ad_impression_ios`), TikTok Business SDK, Facebook `AD_IMPRESSION` (tối ưu giá trị ad in-app trên Meta Ads — xem [tài liệu Facebook](https://developers.facebook.com/docs/app-events/guides/maximize-in-app-ad-revenue/)).
  - Không cần cấu hình gì ở manager này; mỗi SDK đích do manager của nó khởi tạo.
  - ⚠️ 2.0.1 gỡ Adjust SDK khỏi pod: `ADJustManager` → `AdRevenueManager`, `ADJAdType` → `AdType`, `AppADJustConfig` biến mất. App còn dùng Adjust thì tự thêm `pod 'Adjust'` — xem [bảng migration](MobileAds/AdRevenue/README.md#migrating-from-200).

## Mục lục

- [Requirements](#requirements) · [Installation](#installation) · [Quick start](#quick-start)
- **Nền tảng chung** — [1. Khai báo AdUnitID](#1-khai-báo-adunitid-trong-app-adunitidentifiable) ·
  [2. Khởi tạo SDK & consent](#2-khởi-tạo-sdk--consent) ·
  [3. Quy tắc full-screen](#3-quy-tắc-chung-cho-full-screen-ads) ·
  [4. Native: cache & giao diện](#4-native-ads--cache--giao-diện) ·
  [5. Tắt ads cho user premium](#5-tắt-ads-cho-user-premium)
- **Theo surface** — [Ads trên UIKit](docs/ads-uikit.md) · [Ads trên SwiftUI](docs/ads-swiftui.md)
- **[In-App Purchases](docs/in-app-purchases.md)**

## Requirements

- iOS 15.0+
- Xcode 26.0+
- Swift 5.5+

## Installation

### CocoaPods
[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

To integrate MobileAds into your Xcode project using CocoaPods, specify it in your `Podfile`:

Pin theo tag để build lặp lại được. Một tag phục vụ cả UIKit lẫn SwiftUI:

```
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git", :tag => '2.0.1'
```

| Tag | Nội dung |
|---|---|
| `2.0.1` | Bản hiện tại trong `MobileAds.podspec` — gỡ Adjust SDK, đổi tên `ADJustManager` → `AdRevenueManager`. **Tag chỉ có sau khi release được cắt.** |
| `2.0.0` | Còn Adjust; `EntitlementService` là layer IAP duy nhất. |
| `1.4.0` | Bản cuối còn layer `IAPService` cũ. |

Danh sách tag thực tế: `git ls-remote --tags https://github.com/BKPlusResearch/MobileAds.git`.

> App nào đang trỏ vào nhánh `ver/swiftUI` không pin tag thì chuyển sang pin tag.
> Nhánh đó vẫn còn và đã được đưa về đúng nội dung này, nhưng pin tag mới là thứ
> giữ cho build lặp lại được.

Then, run the following command:

```bash
$ pod install
```

## Quick start

Ba bước từ số không tới ad đầu tiên.

**1. Khai báo ad unit** — enum của app, pod không hardcode gì:

```swift
import MobileAds

enum AppAdUnitID: String, AdUnitIdentifiable {
    case banner       = "ca-app-pub-3940256099942544/2934735716"
    case interstitial = "ca-app-pub-3940256099942544/4411468910"
    case nativeFeed   = "ca-app-pub-3940256099942544/3986624511"

    var adUnitIDString: String { rawValue }
}
```

**2. Khởi tạo — từ một VC đang foreground, không phải `didFinishLaunching`:**

```swift
final class SplashViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AdMobHelper.shared.configAds(from: self) {
            // consent xong, ATT có kết quả, SDK đã init — giờ mới load ad
        }
    }
}
```

`configAds` chạy tuần tự UMP → ATT → init SDK. Thứ tự này bắt buộc và có timeout 30s;
lý do ở [mục 2](#2-khởi-tạo-sdk--consent). App SwiftUI cần một cầu nối nhỏ để có
`UIViewController` — xem [ads-swiftui.md](docs/ads-swiftui.md#1-cầu-nối-cho-configads).

**3. Hiện ad đầu tiên:**

```swift
// UIKit — native, có cache sẵn
AdMobHelper.shared.loadNativeAd(
    containerView: adContainer,
    adUnitID: AppAdUnitID.nativeFeed,
    rootViewController: self,
    viewType: .medium
)
```

```swift
// SwiftUI — cùng ad unit, cùng helper bên dưới
NativeAdSwiftUI(adUnitID: AppAdUnitID.nativeFeed, viewType: .medium)
    .frame(height: 300)
```

Từ đây rẽ theo surface: [ads-uikit.md](docs/ads-uikit.md) hoặc
[ads-swiftui.md](docs/ads-swiftui.md).

---

## Nền tảng chung

Năm mục dưới đây áp dụng cho cả hai surface. Đọc xong mới sang tài liệu của surface
bạn dùng.

### 1. Khai báo AdUnitID trong app (AdUnitIdentifiable)

Trong app (không phải trong framework), bạn tự định nghĩa enum cho ad unit:

```swift
import MobileAds

enum AppAdUnitID: AdUnitIdentifiable {
    case appOpen
    case bannerHome
    case interstitialExit
    case rewardedCoin
    case nativeFeed

    var adUnitIDString: String {
    #if DEBUG
        return testID
    #else
        return productionID
    #endif
    }

    private var testID: String {
        switch self {
        case .appOpen:         return "ca-app-pub-3940256099942544/5575463023"
        case .bannerHome:      return "ca-app-pub-3940256099942544/6300978111"
        case .interstitialExit:return "ca-app-pub-3940256099942544/4411468910"
        case .rewardedCoin:    return "ca-app-pub-3940256099942544/5224354917"
        case .nativeFeed:      return "ca-app-pub-3940256099942544/2247696110"
        }
    }

    private var productionID: String {
        switch self {
        case .appOpen:         return "ca-app-pub-xxxx/yyyy_appopen"
        case .bannerHome:      return "ca-app-pub-xxxx/yyyy_banner_home"
        case .interstitialExit:return "ca-app-pub-xxxx/yyyy_interstitial_exit"
        case .rewardedCoin:    return "ca-app-pub-xxxx/yyyy_rewarded_coin"
        case .nativeFeed:      return "ca-app-pub-xxxx/yyyy_native_feed"
        }
    }
}
```

### 2. Khởi tạo SDK & consent

`configAds` chạy tuần tự và chỉ gọi `completion` khi cả ba bước đã xong:

```
UMP consent  →  ATT  →  initialize SDK  →  completion
```

Thứ tự UMP trước, ATT sau là **bắt buộc** theo tài liệu Google: UMP chỉ load được
IDFA explainer message khi tracking status còn `.notDetermined`. Gọi ATT trước sẽ
vô hiệu hoá message đó vĩnh viễn.

`completion` chỉ chạy khi ATT đã thực sự có kết quả — không phải khi callback của
`requestTrackingAuthorization` fire. Hai thứ đó khác nhau: callback trả về ngay
lập tức (báo `.notDetermined`, không hiện gì) khi app chưa `.active`, hoặc khi
prompt từ phiên trước còn treo chưa trả lời. Nếu tin callback, SDK sẽ init và ad
request bắt đầu bắn trong lúc alert vẫn đang hiển thị.

Có timeout 30s để một lần launch không bị treo vĩnh viễn nếu prompt không bao giờ
hiện được.

**Gọi từ một view controller đang foreground (ví dụ splash), không phải từ
`didFinishLaunching`** — cả UMP form lẫn ATT prompt đều cần presenter còn sống:

```swift
import MobileAds

final class SplashViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        AdMobHelper.shared.configAds(from: self) {
            // Tới đây: consent đã xong, ATT đã có kết quả, SDK đã init.
            // Giờ mới an toàn để load ad hoặc đọc Remote Config.
        }
    }
}
```

App SwiftUI không có sẵn `UIViewController` để truyền vào — dựng cầu nối theo
[ads-swiftui.md](docs/ads-swiftui.md#1-cầu-nối-cho-configads).

### 3. Quy tắc chung cho full-screen ads

Áp dụng cho Interstitial, Rewarded, Rewarded Interstitial và App Open, trên cả hai
surface — không cần app tự làm lại:

- **Không bao giờ present khi app đang ở background.** `applicationState == .background`
  làm ad render nửa vời: `adWillPresentFullScreenContent` không fire, overlay
  "Loading ads…" không được gỡ, cờ `is*Showing` kẹt `true` và user quay lại gặp
  một ad không tắt được. Các hàm `show*` phát hiện trạng thái này thì gỡ overlay
  và **giữ lại ad đã load** cho lần sau, thay vì present. `.inactive` (khoảnh khắc
  chuyển sang foreground mà App Open resume dùng) vẫn được coi là an toàn.
- **Mỗi lúc chỉ một full-screen ad.** Format nào đang show thì các format khác
  bỏ qua; gọi lại chính format đang show sẽ `throw AdMobHelperError.adAlreadyShowing`.
- **Show tự đặt cờ bỏ qua App Open kế tiếp.** Interstitial / Rewarded /
  Rewarded Interstitial đều set `shouldSkipNextAppResume = true`, để lần quay lại
  app ngay sau đó không bị chồng thêm một ad nữa. Cách tiêu thụ cờ này là chỗ hai
  surface khác nhau: [UIKit tự nối dây](docs/ads-uikit.md#6-app-open--app-resume),
  [SwiftUI để modifier lo](docs/ads-swiftui.md#5-app-open--khác-đường-uikit).
- **Click vào ad được đánh dấu tự động** qua delegate (`markAdClick()`), phục vụ
  cùng cơ chế resume ở trên.

### 4. Native ads — cache & giao diện

Ba điều quyết định cách tích hợp, giống nhau ở cả `AdMobHelper.shared.loadNativeAd`
(UIKit) lẫn `NativeAdSwiftUI`:

- **Cache là single-use, và bị xoá khi ad ghi nhận *impression*** — không phải lúc
  gắn vào view. Ad hiện ra rồi thì key đó rỗng; muốn màn sau vẫn có ad tức thì thì
  phải preload lại.
- **Entry hết hạn sau 1 giờ.** Quá hạn coi như cache miss.
- **Miss thì tự fallback về network**, không cần app xử lý.

Chi tiết cache key, preload nhiều ad một lượt: [NATIVE_AD_CACHE.md](NATIVE_AD_CACHE.md).

**Tuỳ biến giao diện** — singleton, áp cho mọi native ad của cả hai surface:

```swift
NativeAdConfiguration.shared.headlineFont = UIFont.systemFont(ofSize: 16, weight: .bold)
NativeAdConfiguration.shared.bodyFont = UIFont.systemFont(ofSize: 14)
NativeAdConfiguration.shared.useGradientForCallToAction = true
NativeAdConfiguration.shared.callToActionGradientStartColor = .systemPurple
NativeAdConfiguration.shared.callToActionGradientEndColor = .systemPink
```

Cả hai đường load đều nhận `configuration:` riêng cho từng chỗ đặt; để `nil` thì
dùng singleton này.

### 5. Tắt ads cho user premium

**Pod không có cờ bật/tắt ads toàn cục.** Quyết định có hiện ad hay không là việc của
app: gate ngay tại call site của mình, bằng trạng thái premium của app.

```swift
// `state` phân biệt "đã premium" với "chưa biết" — xem docs/in-app-purchases.md.
// Chưa biết thì mặc định vẫn hiện ad; đổi policy đó là quyết định của app.
guard !PremiumGate.shared.state.isPremium else { return }
try await AdMobHelper.shared.loadInterstitialAd(adUnitID: AppAdUnitID.interstitialExit)
```

Trên SwiftUI, modifier [`.appOpenAd`](docs/ads-swiftui.md#5-app-open--khác-đường-uikit)
nhận sẵn tham số `isEnabled:` cho đúng việc này.

Khi user vừa lên premium, gọi thêm `clearAllAds()` để bỏ ad đã nạp sẵn:

```swift
AdMobHelper.shared.clearAllAds()                // xoá ad đã load + reset mọi cờ
```

`clearAllAds()` là thứ có tác dụng ngay: bỏ toàn bộ ad đã cache (interstitial,
rewarded, rewarded interstitial, app open, banner), reset các cờ `is*Loading` /
`is*Showing`, xoá cờ resume và gỡ loading view. Dùng khi user lên premium hoặc khi
cần đưa helper về trạng thái sạch — không phải sau mỗi lần show.

---

## License

MobileAds is released under the MIT license. See LICENSE for details.
