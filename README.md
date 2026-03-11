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

- **In-App Purchase Service với StoreKit 2**
  - Singleton `IAPService.shared` để quản lý IAP tập trung.
  - Fetch products, purchase, restore purchases với async/await.
  - Validate receipt trực tiếp với Apple server.
  - Quản lý subscription status và lưu trữ an toàn trong Keychain.
  - Protocol `IAPProductIdentifiable` cho product IDs linh hoạt.

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

```
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git", :tag => '1.0.19'
```
New version:

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

Gọi `configAds` sớm, ví dụ trong `AppDelegate`:

```swift
import MobileAds

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AdMobHelper.shared.configAds(from: nil)
        return true
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

### 6. Native Ads với `NativeAdService`

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

---

## In-App Purchase (IAP) Service

**⚠️ Requirements:** iOS 15.0+ (StoreKit 2)

MobileAds cung cấp `IAPService` để quản lý In-App Purchases với StoreKit 2, bao gồm:
- Fetch products từ App Store
- Purchase và restore purchases
- Validate receipt với Apple server
- Quản lý subscription status trong Keychain

### 1. Định nghĩa Product IDs

Tạo enum conform protocol `IAPProductIdentifiable`:

```swift
import MobileAds

enum AppProductID: String, IAPProductIdentifiable {
    case premiumMonthly = "com.yourapp.premium.monthly"
    case premiumYearly = "com.yourapp.premium.yearly"
    case coinsPack100 = "com.yourapp.coins.pack100"
    
    var productIDString: String {
        return self.rawValue
    }
}
```

### 2. Fetch Products

Lấy thông tin sản phẩm từ App Store:

```swift
@available(iOS 15.0, *)
func fetchProducts() async {
    do {
        let products = try await IAPService.shared.fetchProducts([
            AppProductID.premiumMonthly,
            AppProductID.premiumYearly
        ])
        
        for product in products {
            print("Product: \(product.displayName), Price: \(product.displayPrice)")
        }
    } catch {
        print("Failed to fetch products: \(error)")
    }
}
```

### 3. Purchase

Mua sản phẩm:

```swift
@available(iOS 15.0, *)
func purchasePremium() async {
    do {
        let result = try await IAPService.shared.purchase(AppProductID.premiumMonthly)
        print("Purchase successful! Transaction ID: \(result.transactionID ?? "N/A")")
        
        // IAP service tự động validate receipt với Apple và lưu vào Keychain
        
    } catch IAPServiceError.purchaseCancelled {
        print("User cancelled purchase")
    } catch {
        print("Purchase failed: \(error)")
    }
}
```

### 4. Restore Purchases

Khôi phục các giao dịch trước đó:

```swift
@available(iOS 15.0, *)
func restorePurchases() async {
    do {
        let restored = try await IAPService.shared.restorePurchases()
        print("Restored \(restored.count) purchases")
    } catch {
        print("Restore failed: \(error)")
    }
}
```

### 5. Check Subscription Status

#### Cách 1: Check bất kỳ subscription nào đang active (Recommended)

```swift
@available(iOS 15.0, *)
func checkPremiumStatus() {
    // Check xem có bất kỳ subscription nào đang active không (từ Keychain)
    let hasSubscription = IAPService.shared.hasActiveSubscription()
    
    if hasSubscription {
        print("User has active subscription")
        // Show premium features
    } else {
        print("User doesn't have active subscription")
        // Show paywall
    }
}
```

**Ưu điểm**: Không cần list tất cả ProductIDs, tự động check tất cả subscriptions đã lưu trong Keychain.

#### Cách 2: Check subscription cụ thể

```swift
@available(iOS 15.0, *)
func checkSpecificProduct() {
    // Check subscription cụ thể từ Keychain
    let isActive = IAPService.shared.isSubscriptionActive(for: AppProductID.premiumMonthly)
    
    if isActive {
        print("User has active premium monthly subscription")
    }
}
```

**⚠️ Lưu ý:** 
- Cả 2 cách đều check từ **Keychain** (không fetch từ Apple server)
- Trên máy mới (không restore backup) → Keychain trống → return `false`
- User phải tap **"Restore"** để khôi phục subscription từ Apple server vào Keychain

### 6. Get Subscription Info

Lấy chi tiết subscription từ Keychain:

```swift
@available(iOS 15.0, *)
func getSubscriptionDetails() {
    if let info = IAPService.shared.getSubscriptionInfo(for: AppProductID.premiumMonthly.productIDString) {
        print("Status: \(info.status)")
        print("Purchase Date: \(info.purchaseDate)")
        print("Expiration Date: \(info.expirationDate ?? Date())")
        print("Product Type: \(info.productType)")
    }
}
```

### 7. Receipt Validation (Optional)

Framework tự động validate receipt sau khi purchase/restore, nhưng bạn có thể validate thủ công:

```swift
@available(iOS 15.0, *)
func validateReceipt() async {
    // Set shared secret nếu dùng verifyReceipt endpoint
    IAPService.shared.sharedSecret = "YOUR_SHARED_SECRET"
    
    do {
        let response = try await IAPService.shared.validateReceiptWithApple()
        if response.status == 0 {
            print("Receipt valid")
        } else {
            print("Receipt validation failed: \(response.status)")
        }
    } catch {
        print("Validation error: \(error)")
    }
}
```

### Transaction Listener

`IAPService` tự động lắng nghe `Transaction.updates` để:
- Xử lý pending transactions
- Update subscription status khi có thay đổi
- Lưu thông tin vào Keychain

**Cơ chế hoạt động:**

- **Khi có transaction mới** (purchase/restore): Auto listener sẽ update Keychain tự động
- **Background updates**: Nếu subscription renew hoặc expire, listener sẽ update status trong Keychain

Bạn không cần code thêm gì, transaction updates được xử lý tự động!

### Best Practices

1. **Fetch products sớm**: Gọi `fetchProducts` trong `AppDelegate` hoặc khi app launch để cache product info.
2. **Check status thường xuyên**: Kiểm tra subscription status khi user vào premium features.
3. **Handle errors**: Luôn wrap IAP calls trong `do-catch` và handle các error cases.
4. **Test với Sandbox**: Sử dụng sandbox environment để test trước khi production.
5. **Receipt Validation**: Framework tự động validate, nhưng nên có backend validation cho security.
6. **Provide Restore button**: Luôn có nút "Restore" để user khôi phục purchases trên máy mới.

### Lưu ý về đổi máy

Khi user đổi sang máy mới (không restore backup):

**Trạng thái:**
- Keychain trống (không có subscription info)
- `hasActiveSubscription()` và `isSubscriptionActive(for:)` đều return `false`

**Giải pháp:**
- User phải tap nút **"Restore Purchases"**
- `IAPService.shared.restorePurchases()` sẽ fetch subscriptions từ Apple server
- Subscription info được lưu vào Keychain
- Sau đó các check methods sẽ return `true`

**⚠️ Quan trọng:**
- Luôn cung cấp nút "Restore Purchases" trong UI
- Không có cách nào tự động detect subscription trên máy mới mà không cần user action
- Đây là hành vi chuẩn của StoreKit để bảo vệ privacy

### Error Handling

```swift
@available(iOS 15.0, *)
func handlePurchase() async {
    do {
        let result = try await IAPService.shared.purchase(AppProductID.premiumMonthly)
        // Success
    } catch IAPServiceError.productNotFound {
        print("Product not found in cache, fetch products first")
    } catch IAPServiceError.purchaseCancelled {
        print("User cancelled")
    } catch IAPServiceError.purchasePending {
        print("Purchase is pending approval")
    } catch IAPServiceError.purchaseFailed(let error) {
        print("Purchase failed: \(error)")
    } catch {
        print("Unknown error: \(error)")
    }
}
```

---

## License

MobileAds is released under the MIT license. See LICENSE for details.
