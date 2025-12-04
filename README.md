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

- **Tuỳ biến giao diện Native Ad toàn app**
  - Singleton `NativeAdConfiguration.shared` để cấu hình font, màu chữ, màu nền, gradient nút CTA.

- **Trạng thái & loading view rõ ràng**
  - Các flag `isInterstitialLoading`, `isRewardedLoading`, `isAppOpenLoading`, `isBannerLoading`, ...
  - Loading overlay cho Interstitial, Rewarded, App Open.

## Requirements

- iOS 12.0+
- Xcode 12.0+
- Swift 4.0+

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
    private var bannerView: BannerView?

    @IBOutlet weak var bannerContainer: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        bannerView = AdMobHelper.shared.loadBannerAd(
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

        if let bannerView {
            bannerContainer.addSubview(bannerView)
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                bannerView.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor),
                bannerView.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor),
                bannerView.topAnchor.constraint(equalTo: bannerContainer.topAnchor),
                bannerView.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor)
            ])
        }
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
## License

MobileAds is released under the MIT license. See LICENSE for details.
