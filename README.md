<img src="" alt="" />

## MobileAds

MobileAds is a Swift framework that wraps the Google Mobile Ads SDK and provides:

- A central helper `AdMobHelper` to manage SDK init, consent, and all ad formats.
- Strongly-typed status callbacks for Interstitial, Rewarded, App Open, and Banner.
- A `NativeAdService` with configurable XIB-based native ad views.
- A flexible `AdUnitIdentifiable` protocol so each app can define its own ad unit enum.

### Tính năng chính

- **Quản lý AdMob tập trung với `AdMobHelper`**
  - Khởi tạo SDK và xử lý consent qua `configAds(from:)`.
  - Hỗ trợ: Banner, Interstitial, Rewarded, Rewarded Interstitial, App Open, Native.

- **API rõ ràng cho từng loại quảng cáo**
  - `loadBannerAd(...)` + callback trạng thái `BannerAdStatus`.
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
  - ⚠️ Layer `IAPService` cũ đã bị gỡ ở 2.0.0 — xem mục nâng cấp trong README.

- **🆕 Facebook AD_IMPRESSION Tracking**
  - Tự động log `AD_IMPRESSION` event lên Facebook SDK khi có ad revenue.
  - Tích hợp sẵn trong `ADJustManager.logRevenue()` — không cần code thêm.
  - Hỗ trợ tất cả ad formats: Banner, Interstitial, Rewarded, App Open, Native.
  - Giúp tối ưu hoá giá trị quảng cáo in-app trên Meta Ads. Xem [tài liệu Facebook](https://developers.facebook.com/docs/app-events/guides/maximize-in-app-ad-revenue/).

## Requirements

- iOS 15.0+
- Xcode 26.0+
- Swift 5.0+

## Installation

### CocoaPods
[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

To integrate MobileAds into your Xcode project using CocoaPods, specify it in your `Podfile`:

Bản phát hành mới nhất (`1.4.0` — cũng là bản cuối còn layer `IAPService` cũ):

```
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git", :tag => '1.4.0'
```

Bản 2.0.0 nằm trên nhánh mặc định và **chưa có tag**, nên chỉ lấy được ở dạng không pin:

```
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git"
```

Then, run the following command:

```bash
$ pod install
```

## Usage

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

### 3. Banner

```swift
class HomeViewController: UIViewController {
    @IBOutlet weak var bannerContainer: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        AdMobHelper.shared.loadBannerAd(
            into: bannerContainer,
            adUnitID: AppAdUnitID.bannerHome,
            rootViewController: self,
            statusCallback: { status in
                switch status {
                case .didLoad:
                    print("Banner loaded")
                case .didFailToLoad:
                    print("Banner failed")
                default:
                    break
                }
            }
        )
    }
}
```

**Note:** Method `loadBannerAd(into:...)` automatically adds the banner to the container and sets constraints. If you need more control, you can use the original `loadBannerAd(...)` method which returns a `BannerView` that you can manually add to your view hierarchy.

### 3b. BannerAdView — Banner tự quản lý (khuyến nghị khi tránh singleton conflict)

`BannerAdView` là một `UIView` subclass độc lập — không dùng `AdMobHelper.shared`. Phù hợp khi:
- Nhiều banner cùng tồn tại (vd: inline trong UICollectionView).
- Muốn tách biệt lifecycle của từng banner.

**Tích hợp sẵn:**
- Shimmer loading (`BannerAdLoadingView`) hiện trong lúc chờ ad load.
- Skip-if-loaded: gọi `loadAd` nhiều lần không bị double load.
- `clearAd()`: dọn sạch banner + ẩn view (dùng khi user mua premium hoặc cell reuse).

**Dùng trong ViewController:**

```swift
import MobileAds

class HomeViewController: UIViewController {

    private let bannerAdView = BannerAdView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(bannerAdView)
        bannerAdView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(view.safeAreaLayoutGuide).inset(16)
            make.height.equalTo(70)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !isPremiumUser {
            bannerAdView.loadAd(adUnitID: AppAdUnitID.bannerHome, rootViewController: self)
        } else {
            bannerAdView.clearAd()
        }
    }
}
```

**Collapsible banner:**

```swift
// Collapsible banner — nút thu gọn ở cuối màn hình
bannerAdView.loadAd(
    adUnitID: AppAdUnitID.bannerHome,
    rootViewController: self,
    isCollapsible: true,
    collapsiblePlacement: .bottom  // hoặc .top
)
```

**Dùng trong UICollectionViewCell (IGListKit / UICollectionView):**

```swift
import MobileAds

class BannerCell: UICollectionViewCell {

    private let bannerAdView = BannerAdView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(bannerAdView)
        bannerAdView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func loadBanner(rootViewController: UIViewController) {
        bannerAdView.loadAd(adUnitID: AppAdUnitID.bannerHome, rootViewController: rootViewController)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        bannerAdView.clearAd()  // dọn sạch trước khi cell bị reuse
    }
}
```

### Quy tắc chung cho full-screen ads

Áp dụng cho Interstitial, Rewarded, Rewarded Interstitial và App Open — không cần
app tự làm lại:

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
  app ngay sau đó không bị chồng thêm một ad nữa. Xem [App Open & App Resume](#8-app-open--app-resume).
- **Click vào ad được đánh dấu tự động** qua delegate (`markAdClick()`), phục vụ
  cùng cơ chế resume ở trên.

### 4. Interstitial

```swift
func showExitInterstitial(from vc: UIViewController) async {
    do {
        try await AdMobHelper.shared.loadInterstitialAd(adUnitID: AppAdUnitID.interstitialExit)
        try AdMobHelper.shared.showInterstitialAd(from: vc) { status in
            print("Interstitial status: \(status)")
        }
    } catch {
        print("Interstitial error: \(error)")
    }
}
```

### 5. Rewarded

```swift
func showReward(from vc: UIViewController) async {
    do {
        try await AdMobHelper.shared.showRewardedAd(
            from: vc,
            adUnitID: AppAdUnitID.rewardedCoin,
            statusCallback: { status in
                print("Rewarded status: \(status)")
            },
            completion: { reward in
                print(\"User earned reward: \\(reward.amount)\")
            }
        )
    } catch {
        print(\"Rewarded error: \\(error)\")
    }
}
```

### 6. Native Ads

**Đường khuyến nghị — `AdMobHelper.shared.loadNativeAd`, có cache sẵn:**

```swift
AdMobHelper.shared.loadNativeAd(
    containerView: nativeContainerView,
    adUnitID: AppAdUnitID.nativeFeed,
    rootViewController: self,
    viewType: .small,
    configuration: nil,     // nil -> dùng NativeAdConfiguration.shared
    enableCache: true       // default; cache key = chuỗi ad unit ID
) { success in
    print(\"Native loaded: \\(success)\")
}
```

Cần tự đặt cache key (nhiều chỗ đặt dùng chung một ad unit) thì dùng
`loadNativeAdWithCache(..., cacheKey:)`. Preload trước bằng
`preloadMultipleNativeAds(requests:completion:)`. Chi tiết: [NATIVE_AD_CACHE.md](NATIVE_AD_CACHE.md).

Ba điều quyết định cách tích hợp:

- **Cache là single-use, và bị xoá khi ad ghi nhận *impression*** — không phải lúc
  gắn vào view. Ad hiện ra rồi thì key đó rỗng; muốn màn sau vẫn có ad tức thì thì
  phải preload lại.
- **Entry hết hạn sau 1 giờ.** Quá hạn coi như cache miss.
- **Miss thì tự fallback về network**, không cần app xử lý.

**Đường không cache — `NativeAdService`:** luôn load từ network, dùng khi cố ý
không muốn dính cache (ví dụ ad unit chỉ hiện đúng một lần trong phiên):

```swift
let nativeService = NativeAdService()

nativeService.loadNativeAd(
    containerView: nativeContainerView,
    adUnitID: AppAdUnitID.nativeFeed,
    rootViewController: self,
    viewType: .small,
    configuration: nil
) { success in
    print(\"Native loaded: \\(success)\")
}
```

#### Tuỳ biến giao diện Native

```swift
NativeAdConfiguration.shared.headlineFont = UIFont.systemFont(ofSize: 16, weight: .bold)
NativeAdConfiguration.shared.bodyFont = UIFont.systemFont(ofSize: 14)
NativeAdConfiguration.shared.useGradientForCallToAction = true
NativeAdConfiguration.shared.callToActionGradientStartColor = .systemPurple
NativeAdConfiguration.shared.callToActionGradientEndColor = .systemPink
```

### 7. Rewarded Interstitial

Cùng hợp đồng với Rewarded, nhưng không có `statusCallback` — chỉ có `completion`
trả reward. Hàm này tự load nếu chưa có ad sẵn:

```swift
func showRewardedInterstitial(from vc: UIViewController) async {
    do {
        try await AdMobHelper.shared.showRewardedInterstitialAd(
            from: vc,
            adUnitID: AppAdUnitID.rewardedInterstitial,
            completion: { reward in
                print("User earned reward: \(reward.amount)")
            }
        )
    } catch {
        print("Rewarded interstitial error: \(error)")
    }
}
```

Muốn load trước cho lượt sau: `try await AdMobHelper.shared.loadRewardedInterstitialAd(adUnitID:)`.

### 8. App Open & App Resume

**Pod không tự hiện App Open ad.** Nó cấp ad và các cờ; app quyết định thời điểm.
Đây là phần app phải tự nối dây:

```swift
// 1. Warm up sau khi configAds xong (load là async throws, show thì không).
Task {
    try? await AdMobHelper.shared.loadAppOpenAd(adUnitID: AppAdUnitID.appOpen)
}

// 2. Khi app quay lại foreground.
NotificationCenter.default.addObserver(
    forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
) { _ in
    let helper = AdMobHelper.shared

    // Vừa xem full-screen ad hoặc vừa click ad rồi rời app → bỏ lượt này.
    guard !helper.shouldSkipNextAppResume else {
        helper.resetAppResumeSkipFlag()
        return
    }

    helper.showAppOpenAd { status in
        if case .didDismiss = status {
            Task { try? await AdMobHelper.shared.loadAppOpenAd(adUnitID: AppAdUnitID.appOpen) }
        }
    }
}
```

Điểm cần biết:

- **Ad App Open hết hạn sau 4 giờ** (`appOpenTimeoutInterval`). Quá hạn thì
  `loadAppOpenAd` sẽ load lại; ad cũ không được dùng.
- `loadAppOpenAd` **no-op** khi đang có ad còn hạn hoặc đang load, và **throw**
  `AdMobHelperError.consentNotGranted` nếu UMP chưa cho phép request.
- `showAppOpenAd(from:)` nhận `viewController` optional — bỏ trống thì pod tự tìm
  presenter.
- Xử lý click ad rời app: delegate gọi `markAdClick()`. Handler
  `didEnterBackground` của app xác nhận bằng `isRecentAdClick(withinSeconds:)` rồi
  gọi `confirmSkipNextAppResume()`. Overlay in-app không rời app thì gọi
  `clearPendingAdClick()` để không chặn nhầm lượt resume kế tiếp.

### 9. Cờ bật/tắt ads & dọn state

```swift
AdMobHelper.shared.setEnableShowAds(false)      // ví dụ: user vừa mua premium
AdMobHelper.shared.checkEnableShowAds()         // -> false

AdMobHelper.shared.clearAllAds()                // xoá ad đã load + reset mọi cờ
```

> ⚠️ **`setEnableShowAds` không tự chặn ad.** Pod chỉ *lưu* cờ này; không đường
> `load*` hay `show*` nào đọc nó. App phải tự gate các call site của mình:
> `guard AdMobHelper.shared.checkEnableShowAds() else { return }` trước khi gọi
> show. Đặt cờ rồi tưởng ads đã tắt là cách chắc chắn để user premium vẫn thấy quảng cáo.

`clearAllAds()` mới là thứ có tác dụng ngay: bỏ toàn bộ ad đã cache (interstitial,
rewarded, rewarded interstitial, app open, banner), reset các cờ `is*Loading` /
`is*Showing`, xoá cờ resume và gỡ loading view. Dùng khi user lên premium hoặc khi
cần đưa helper về trạng thái sạch — không phải sau mỗi lần show.

---

## In-App Purchases

**⚠️ Requirements:** iOS 15.0+ (StoreKit 2)

`EntitlementService` là layer IAP **duy nhất** của pod. Layer `IAPService` cũ đã bị **gỡ ở 2.0.0** — xem [Nâng cấp từ 1.x lên 2.0](#nâng-cấp-từ-1x-lên-20).

Entitlement được suy ra từ `Transaction.currentEntitlements` ở **mỗi lần check**, nên cài lại app, đổi máy, refund, grace period và Family Sharing đều do StoreKit lo, không phải do local storage. Layer này generic: nó không giữ product ID nào của riêng nó và không bao giờ hiện UI — app tự cấu hình và tự dựng paywall.

> **Trạng thái: chưa verify trên máy thật.** Layer này viết theo tài liệu StoreKit 2, chưa app nào chạy. Nó đã qua một lượt red-team và một lượt code review, cả hai đều tìm ra lỗi thật chỉ bằng đọc code — nên cứ giả định các lỗi chỉ lộ ra lúc runtime vẫn còn nguyên. Repo không có StoreKit test configuration, nên checklist bên dưới là biện pháp kiểm soát duy nhất đang có. **Nếu bạn là người tích hợp đầu tiên, hãy chạy nó và báo lại kết quả.**

### 1. Configure — một lần, trước `bootstrap()`

```swift
EntitlementService.shared.configure(
    EntitlementConfig(productIDs: ["your.weekly", "your.yearly"],
                      subscriptionGroupID: "your_group")
)
```

`productIDs` là bắt buộc, không có default. Không có chế độ "để rỗng nghĩa là chấp nhận tất cả": `currentEntitlements` còn phát ra cả consumable chưa finish và non-renewing đã hết hạn, nên một tập rộng rãi sẽ khiến gói xu cấp quyền vĩnh viễn.

Nếu product ID lấy từ Remote Config, **fetch trước rồi mới configure** — service không quyết định gì cho tới khi được configure, và nó từ chối bị configure lần thứ hai.

### 2. Bootstrap lúc launch

```swift
EntitlementService.shared.bootstrap()   // KHÔNG async — cố ý
```

Hàm này trả về ngay để frame đầu tiên không bao giờ phải chờ StoreKit. Hãy quan sát `verification` thay vì `await` bất cứ thứ gì.

### 3. Refresh khi vào foreground

```swift
await EntitlementService.shared.refresh()             // có sẵn debounce 30s
await EntitlementService.shared.refresh(force: true)  // bỏ qua debounce
```

Chỉ dùng `force: true` khi có sự kiện thật sự đổi entitlement mà không đi qua
`purchase()` / `restore()` — ví dụ user vừa quay về từ màn quản lý subscription
của App Store. Gọi `force` theo nhịp polling là tự bỏ đi lớp chống spam StoreKit.

### 4. Đọc state

`EntitlementService` là `@MainActor ObservableObject`. Pod này thuần UIKit, nên đường chuẩn là sink `@Published` bằng Combine:

```swift
import Combine

final class PremiumGate {
    static let shared = PremiumGate()
    private var bag = Set<AnyCancellable>()

    /// Gate phải phân biệt được "chưa premium" và "chưa biết".
    var state: (isPremium: Bool, isKnown: Bool) {
        let s = EntitlementService.shared
        return (s.isEntitled, s.verification == .verified)
    }

    func start() {
        EntitlementService.shared.$isEntitled
            .removeDuplicates()
            .sink { isEntitled in
                // Cờ này pod không tự enforce — vẫn phải gate call site. Xem mục 9.
                AdMobHelper.shared.setEnableShowAds(!isEntitled)
                if isEntitled { AdMobHelper.shared.clearAllAds() }
                NotificationCenter.default.post(name: .premiumStatusDidChange, object: nil)
            }
            .store(in: &bag)
    }
}
```

Nếu app host là SwiftUI, quan sát trực tiếp:

```swift
@ObservedObject private var entitlements = EntitlementService.shared

if entitlements.verification == .verified && entitlements.isEntitled {
    PremiumContent()
} else {
    FreeContent()
}
```

| Property | Ý nghĩa |
|---|---|
| `verification` | `.pending` / `.verified` / `.timedOut` — StoreKit đã trả lời chưa? |
| `isEntitled` | Đang giữ một product đã configure. Chỉ có nghĩa khi đã `.verified` |
| `activeProductID` | Product nào đang cấp quyền |
| `expiryDate` | `nil` với lifetime/non-consumable — **`nil` không phải là "đã hết hạn"** |
| `isIntroOfferEligible` | `false` cho tới khi catalog load xong và eligibility có kết quả. Vẫn phải check `introductoryOffer` của đúng product trước khi in chữ về trial |
| `products` | `Product` đã load, key theo ID; `displayPrice(for:)` để lấy giá đã localize |
| `shouldProactivelyPromptRestore` | Có nên *chủ động gợi ý* restore — **không phải** có nên hiện nút |

### 5. Purchase & Restore

```swift
switch await EntitlementService.shared.purchase("your.yearly") {
case .purchased(let receipt):
    // KHÔNG credit consumable ở đây — `onUnfinished` đã được mời transaction này
    // và là nơi duy nhất để credit. Xem mục "Consumables".
    dismissPaywall()
case .cancelled:        break
case .pending:          showAwaitingApprovalMessage()   // Ask to Buy — không phải lỗi
case .failed(let why):  log(why)
}

switch await EntitlementService.shared.restore() {
case .restored:          dismissPaywall()
case .nothingToRestore:  showNothingToRestore()
case .cancelled:         break                          // user tắt sheet đăng nhập — không phải lỗi
case .failed(let why):   showError(why)
}
```

### Năm cái bẫy

1. **Chỉ mở khoá khi `verification == .verified`.** `.pending` nghĩa là *chưa biết*; `.timedOut` nghĩa là StoreKit không trả lời trong 5s. **Mặc định khuyến nghị khi `.timedOut`: coi user là free và hiện quảng cáo.** Cách này ưu tiên doanh thu; cái giá là người đã mua đang ở mạng kém sẽ thấy quảng cáo vài giây cho tới khi `verify()` trả lời, rồi quảng cáo biến mất. Chỉ chọn khác nếu có lý do.
2. **Không cache ở bất cứ đâu.** Không có entitlement nào được lưu, không có state "lần cuối biết". `isEntitled` là `false` cho tới khi verify xong, kể cả với người đã mua từ lâu. **Đừng thêm cache ở phía app để làm mượt chỗ này** — đó chính xác là khuyết tật của layer 1.x đã bị gỡ, và là lý do nó bị gỡ.
3. **Với `@Observable` (iOS 17+), phải mirror — đừng forward.** `var isPremium: Bool { base.isEntitled }` compile được nhưng UI **không bao giờ update**, vì `@Observable` không theo dõi `objectWillChange` của một `ObservableObject`. Hãy sink các `@Published` vào stored property.
4. **Mỗi app chỉ một `Transaction.updates` listener.** Layer này đang chạy một cái. Nếu app còn giữ listener riêng — subscription tracker, analytics observer — hai bên sẽ finish transaction của nhau và trôi lệch nhau. Hãy bỏ listener của app, hoặc đưa nó qua `onUnfinished`.
5. **Nút Restore phải luôn hiện.** `shouldProactivelyPromptRestore` chỉ trả lời "có nên chủ động gợi ý không". Lấy cờ đó để ẩn chính cái nút là đường thẳng tới việc bị reject theo Guideline 3.1.1. Gọi `markRestorePrompted()` sau khi bạn đã hiện UI gợi ý của mình.

### Consumables — bắt buộc phải cấp `onUnfinished`

App chỉ bán subscription hoặc non-consumable có thể dừng đọc ở đây. App bán gói xu, credit, hay lượt chơi **bắt buộc** phải cấp `onUnfinished`, nếu không sẽ thu tiền khách mà không giao hàng.

**Vì sao credit ở chỗ `purchase()` trả về là không đủ.** Rất dễ nghĩ rằng cứ credit xu ngay chỗ `purchase()` trả về là xong. Nhưng StoreKit giao consumable qua `Transaction.updates` — nơi không có lời gọi `purchase()` nào đang chờ — trong ít nhất bốn tình huống bình thường:

- app bị kill hoặc crash giữa lúc trả tiền và lúc giao hàng;
- Ask to Buy được phụ huynh duyệt vài phút hoặc vài ngày sau;
- giao dịch bắt đầu từ máy khác cùng Apple ID;
- lần giao hàng trước bị gián đoạn.

Ở cả bốn trường hợp, library thấy một transaction mà app không thấy. Không có hook thì nó finish rồi vứt đi. **Consumable không bao giờ vào `currentEntitlements`**, nên khác với subscription, không còn gì để suy ra lại: tiền đã mất và số xu chưa từng tồn tại.

`onUnfinished` phủ **cả hai** đường: `purchase()` cũng mời transaction của nó qua đúng hook đó trước khi finish. Nhờ vậy chỉ có đúng một nơi để credit, và nó bắt được mọi trường hợp.

```swift
EntitlementService.shared.configure(
    EntitlementConfig(
        // SKU xu cũng phải liệt kê ở đây — purchase() từ chối mọi ID không có trong này.
        // Liệt kê KHÔNG khiến chúng cấp premium; verify() lọc consumable
        // theo Transaction.productType.
        productIDs: ["your.weekly", "your.yearly", "your.coins.100"],
        subscriptionGroupID: "your_group",
        onUnfinished: { receipt in
            // Ghi credit TRƯỚC khi return true, và khử trùng lặp theo transactionID.
            await CoinLedger.creditOnce(receipt.transactionID, productID: receipt.productID)
        }
    )
)
```

Hợp đồng, và từng dòng đều gánh việc:

| Quy tắc | Không làm thì hỏng thế nào |
|---|---|
| Ghi credit **trước** khi return `true` | Crash giữa hai bước là bạn vừa tái tạo lại đúng cái mất mát mà hook này sinh ra để chặn |
| Khử trùng lặp theo `receipt.transactionID` | StoreKit giao lại; credit theo từng lần giao sẽ credit gấp đôi |
| **Chỉ** credit ở đây | Mọi consumable được mời qua hook này đúng một lần, kể cả cái mua ở foreground qua `purchase()`. Credit thêm ở chỗ `purchase()` trả về là credit hai lần |
| Ghi credit phải atomic | Read-then-write qua một actor hop, hoặc vào `UserDefaults` App Group dùng chung với widget, sẽ mất credit khi ghi đồng thời |
| Chỉ return `false` khi ghi **thật sự** thất bại | Đây không phải kênh báo lỗi. `false` vĩnh viễn nghĩa là giao lại vĩnh viễn |

Hook cố ý **không** được gọi cho:

| Không gọi cho | Vì sao |
|---|---|
| Subscription và non-consumable | Entitlement suy lại được từ `currentEntitlements`, finish chúng không mất gì. Nếu hook thấy cả renewal, một app return `false` cho product nó không nhận ra sẽ kẹt renewal đó trong vòng giao lại vĩnh viễn |
| Transaction đã revoke / refund | Giao hàng cho một đơn đã hoàn tiền là cho không. `refresh()` vẫn chạy nên entitlement vẫn rớt đúng |
| Transaction verify thất bại | Chấp nhận chúng là giao hàng dựa trên bằng chứng không kiểm chứng được |

**Lỗ hổng đã biết:** vì dòng cuối bảng trên, một consumable đã bị tính tiền nhưng không verify được thì vẫn mất. Bịt đúng chỗ này cần server-side receipt validation, thứ library không làm.

Hai hành vi nên biết:

- **Transaction đến trước `configure()` được để nguyên chưa finish**, không bị vứt, và sẽ được thử lại sau khi app configure. Finish chúng là không thể cứu vãn.
- **`bootstrap()` mời lại mọi thứ còn chưa finish** từ các phiên trước, nên return `false` là thử lại chứ không phải đi một chiều.

### Checklist sandbox cho người tích hợp đầu tiên

| # | Trường hợp | Kỳ vọng |
|---|---|---|
| 1 | Mua | Có quyền ngay, UI update không cần restart |
| 2 | Kill rồi mở lại | Vẫn có quyền |
| 3 | Xoá app, cài lại, không bấm gì | Có quyền trong ~1s |
| 4 | Refund qua StoreKit Transaction Manager | Mất quyền sau khi refresh |
| 5 | Ask to Buy | Outcome `.pending`, không phải lỗi |
| 6 | Đăng nhập Apple ID khác | Mất quyền |
| 7 | Restore ở trường hợp 6 | Hiện prompt đăng nhập |
| 8 | Airplane mode, máy **đã** verify trước đó | Vẫn có quyền — `currentEntitlements` đọc từ transaction cache trên máy của StoreKit |
| 9 | Airplane mode + **cài mới** | `verification` thành `.timedOut` sau 5s; theo policy mặc định thì app hiện quảng cáo |
| 10 | Non-consumable / lifetime | Có quyền vĩnh viễn, `expiryDate` là `nil` |
| 11 | **Consumable** (nếu app có bán) | **Không** cấp entitlement, nhưng `purchase()` vẫn trả `.purchased(receipt)` |
| 12 | **Intro offer** — 2+ product, chỉ một cái có trial | `isIntroOfferEligible` trả lời đúng product, nhất quán qua các lần chạy |
| 13 | **Mua trong lúc một verify đang bay** | Không bị mất quyền sau khi mua xong |
| 14 | **Lần launch thứ hai với tư cách người đã mua** | UI free vài chục ms rồi mới premium. Báo lại nếu cái nháy đó khó chịu |
| 15 | **Subscription group mà không product nào có intro offer** | `isIntroOfferEligible` giữ nguyên `false` — không bao giờ gắn badge trial lên gói tính tiền ngay |
| 16 | **Launch offline, nối mạng lại, mở paywall ngay** (trong debounce 30s) | **Tất cả** giá đều hiện và `purchase()` chạy được. Mua một gói không được làm các gói còn lại mất giá suốt phiên |
| 17 | **Consumable mua ở foreground** (chỉ app bán consumable) | `onUnfinished` chạy một lần; xu được credit một lần; `purchase()` trả `.purchased(receipt)` |
| 18 | **Consumable, app bị kill giữa lúc mua** | Xu được credit ở lần launch kế qua `onUnfinished`, đúng một lần |
| 19 | **Consumable qua Ask to Buy, duyệt sau khi mở lại app** | Xu được credit khi duyệt về, đúng một lần |
| 20 | **`onUnfinished` return `false`** | Transaction KHÔNG finish; được mời lại ở `bootstrap()` kế |
| 21 | **Refund một consumable qua StoreKit Transaction Manager** | `onUnfinished` **không** chạy lại; không credit thêm xu |
| 22 | **Subscription renew trong khi có `onUnfinished`** | Hook **không** chạy; renewal finish; `expiryDate` update |
| 23 | **Transaction đến trước `configure()`** | Để nguyên chưa finish, rồi được credit sau `configure()` + `bootstrap()` |

Trường hợp 3 chính là lý do layer này tồn tại. Trường hợp 11–13 là lỗi do lượt red-team tìm ra, 15–16 từ lượt code review đầu, và 17–23 từ lượt review của delivery hook 2.0 — mỗi cái là một cách cụ thể làm mất tiền trên giấy; bỏ bớt cái nào là vứt đi giá trị của các lượt review đó. Trường hợp 14 đo cái giá của việc không có cache.

Hai trường hợp nữa cần app hỗ trợ huỷ tác vụ: gọi `refresh()` từ một `Task` bị cancel giữa chừng không được làm người đã mua rớt về free, và gọi `bootstrap()` trước `configure()` phải để `bootstrap()` vẫn dùng được sau đó chứ không kẹt `verification` ở `.pending`.

### Nâng cấp từ 1.x lên 2.0

**2.0.0 đã gỡ layer IAP cũ.** `IAPService`, `IAPProductIdentifiable`, `IAPError`, `ProductType`, cùng phần lưu trữ Keychain/UserDefaults phía sau chúng không còn tồn tại. App đang ở 1.x sẽ không compile với 2.0 cho tới khi migrate. Ở lại 1.x là lựa chọn hợp lệ — pin `:tag => '1.4.0'`.

Vì sao nó bị gỡ: entitlement được đọc từ local storage, nên **premium mất khi cài lại hoặc đổi máy** cho tới khi user tự tìm ra "Restore Purchases", và Ask to Buy bị báo cho user như một lỗi.

Ánh xạ API:

| 1.x | 2.0 |
|---|---|
| `IAPService.shared.hasActiveSubscription()` | `EntitlementService.shared.isEntitled` |
| `IAPService.shared.isSubscriptionActive(for:)` | `EntitlementService.shared.activeProductID == id` |
| `IAPService.shared.getSubscriptionInfo(for:)` | `expiryDate` + `products[id]` |
| `IAPService.shared.fetchProducts(_:)` | `configure()` + `bootstrap()`, rồi đọc `products` |
| `IAPService.shared.purchase(_:)` | `EntitlementService.shared.purchase(id)` → outcome |
| `IAPService.shared.restorePurchases()` | `EntitlementService.shared.restore()` |
| `IAPService.shared.sharedSecret = …` | Đã gỡ. Xoay shared secret là việc riêng — xoá dòng này không làm secret hết hiệu lực |
| `IAPService.shared.validateReceiptWithApple()` | Đã gỡ. Cần validate phía server thì làm ở backend |
| `catch IAPServiceError.purchaseCancelled` | `case .cancelled` |
| `catch IAPServiceError.purchasePending` | `case .pending` |
| `catch let e as IAPServiceError` | `case .failed(let failure)` |
| `IAPProductIdentifiable` / `ProductType` | Tự khai báo phía app; pod không còn vend nữa |

**Cái bẫy sẽ ngốn của bạn một ngày: `isEntitled` không đồng bộ.**
`hasActiveSubscription()` đọc `UserDefaults` nên luôn có câu trả lời ngay lập tức. `isEntitled` là `false` cho tới khi verify xong. **Mọi ad gate và paywall check chạy lúc launch sẽ thấy `false` và hiện quảng cáo cho người đã trả tiền.**

Một shim `-> Bool` không cứu được chuyện này. Gate phải phân biệt được "không premium" và "chưa biết", và phải có thứ gì đó báo cho UI khi câu trả lời về — xem `PremiumGate` ở mục [Đọc state](#4-đọc-state).

Bridge sang RxSwift: sink `$isEntitled`. **Đừng** dùng `objectWillChange` — nó bắn ở `willSet` và không mang giá trị, nên relay luôn chậm một nhịp. Nó compile sạch nên không build check nào bắt được.

Bán consumable? Đọc [Consumables](#consumables--bắt-buộc-phải-cấp-onunfinished) trước khi bắt đầu; ở đó `onUnfinished` là bắt buộc.

---

## License

MobileAds is released under the MIT license. See LICENSE for details.
