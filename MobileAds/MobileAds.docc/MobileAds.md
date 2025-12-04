# ``MobileAds``

Framework MobileAds giúp bạn tích hợp Google Mobile Ads SDK nhanh chóng và an toàn,
với API tập trung qua `AdMobHelper`, service native ads và cấu hình giao diện linh hoạt.

## Overview

- Quản lý khởi tạo SDK & consent: `AdMobHelper.shared.configAds(from:)`.
- Hỗ trợ đầy đủ các format:
  - Banner
  - Interstitial
  - Rewarded
  - Rewarded Interstitial
  - App Open
  - Native
- Tách logic theo extension: `AdMobHelper+Banner`, `+Interstitial`, `+Rewarded`, `+AppOpen`, ...
- Mỗi app tự định nghĩa enum ad unit riêng, thông qua protocol `AdUnitIdentifiable`.
- `NativeAdService` và `NativeAdConfiguration` cho phép tuỳ biến native ad toàn app.

## Quick Start

### 1. Định nghĩa AdUnitID trong app

Trong app (target của bạn), định nghĩa enum:

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

### 2. Khởi tạo SDK & Consent

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

### 3. Ví dụ sử dụng

#### Banner

```swift
class HomeViewController: UIViewController {
    @IBOutlet weak var bannerContainer: UIView!
    private var bannerView: BannerView?

    override func viewDidLoad() {
        super.viewDidLoad()

        bannerView = AdMobHelper.shared.loadBannerAd(
            adUnitID: AppAdUnitID.bannerHome,
            rootViewController: self
        ) { status in
            switch status {
            case .didLoad:
                print("Banner loaded")
            case .didFailToLoad:
                print("Banner failed")
            default:
                break
            }
        }

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

#### Interstitial

```swift
func showInterstitial(from viewController: UIViewController) async {
    do {
        try await AdMobHelper.shared.loadInterstitialAd(adUnitID: AppAdUnitID.interstitialExit)
        try AdMobHelper.shared.showInterstitialAd(from: viewController) { status in
            print("Interstitial status: \(status)")
        }
    } catch {
        print("Interstitial error: \(error)")
    }
}
```

#### Rewarded

```swift
func showReward(from viewController: UIViewController) async {
    do {
        try await AdMobHelper.shared.showRewardedAd(
            from: viewController,
            adUnitID: AppAdUnitID.rewardedCoin,
            statusCallback: { status in
                print("Rewarded status: \(status)")
            },
            completion: { reward in
                print("User earned reward: \(reward.amount)")
            }
        )
    } catch {
        print("Rewarded error: \(error)")
    }
}
```

#### App Open

```swift
func preloadAppOpenAd() async {
    do {
        try await AdMobHelper.shared.loadAppOpenAd(adUnitID: AppAdUnitID.appOpen)
    } catch {
        print("AppOpen load error: \(error)")
    }
}

func showAppOpenIfAvailable() {
    AdMobHelper.shared.showAppOpenAd(from: nil) { status in
        print("AppOpen status: \(status)")
    }
}
```

#### Native Ads với NativeAdService

```swift
let nativeService = NativeAdService()

nativeService.loadNativeAd(
    containerView: nativeContainerView,
    adUnitID: AppAdUnitID.nativeFeed,
    rootViewController: self,
    viewType: .small,
    configuration: nil
) { success in
    print("Native loaded: \(success)")
}
```

##### Tuỳ biến giao diện NativeAd

```swift
let config = NativeAdConfiguration.shared
config.headlineFont = .systemFont(ofSize: 16, weight: .bold)
config.bodyFont = .systemFont(ofSize: 14)
config.callToActionFont = .systemFont(ofSize: 15, weight: .semibold)

config.useGradientForCallToAction = true
config.callToActionGradientStartColor = .systemPurple
config.callToActionGradientEndColor = .systemPink
config.callToActionTextColor = .white
```

## Topics

### Core

- ``AdMobHelper``
- ``AdUnitIdentifiable``

### Native Ads

- ``NativeAdService``
- ``NativeAdConfiguration``
