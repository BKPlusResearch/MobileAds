# MobileAds — Ads trên UIKit

Các call site cụ thể của đường UIKit. Phần dùng chung cho cả hai surface — cài đặt,
khai báo `AdUnitIdentifiable`, `configAds`, quy tắc full-screen, cache native,
`NativeAdConfiguration`, cờ bật/tắt ads — nằm ở [README](../README.md).

Đường SwiftUI: [ads-swiftui.md](ads-swiftui.md). In-App Purchase: [in-app-purchases.md](in-app-purchases.md).

## Mục lục

- [1. Banner](#1-banner) · [2. BannerAdView](#2-banneradview--banner-tự-quản-lý) ·
  [3. Interstitial](#3-interstitial) · [4. Rewarded](#4-rewarded) ·
  [5. Rewarded Interstitial](#5-rewarded-interstitial) · [6. Native](#6-native) ·
  [7. App Open & App Resume](#7-app-open--app-resume)

## 1. Banner

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

## 2. BannerAdView — Banner tự quản lý

Khuyến nghị khi cần tránh singleton conflict.

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

## 3. Interstitial

Đọc [quy tắc chung cho full-screen ads](../README.md#3-quy-tắc-chung-cho-full-screen-ads) trước.

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

## 4. Rewarded

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
                print("User earned reward: \(reward.amount)")
            }
        )
    } catch {
        print("Rewarded error: \(error)")
    }
}
```

## 5. Rewarded Interstitial

Cùng hợp đồng với Rewarded: `statusCallback` tuỳ chọn cho vòng đời ad, `completion`
trả reward. Hàm này tự load nếu chưa có ad sẵn:

```swift
func showRewardedInterstitial(from vc: UIViewController) async {
    do {
        try await AdMobHelper.shared.showRewardedInterstitialAd(
            from: vc,
            adUnitID: AppAdUnitID.rewardedInterstitial,
            statusCallback: { status in
                print("Status: \(status)")
            },
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

## 6. Native

Ngữ nghĩa cache và tuỳ biến giao diện dùng chung với SwiftUI —
xem [Native ads: cache & giao diện](../README.md#4-native-ads--cache--giao-diện).

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
    print("Native loaded: \(success)")
}
```

Cần tự đặt cache key (nhiều chỗ đặt dùng chung một ad unit) thì dùng
`loadNativeAdWithCache(..., cacheKey:)`. Preload trước bằng
`preloadMultipleNativeAds(requests:completion:)`. Chi tiết: [NATIVE_AD_CACHE.md](../NATIVE_AD_CACHE.md).

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
    print("Native loaded: \(success)")
}
```

## 7. App Open & App Resume

**Pod không tự hiện App Open ad trên UIKit.** Nó cấp ad và các cờ; app quyết định thời
điểm. Đây là phần app phải tự nối dây — khác hẳn SwiftUI, nơi
[`.appOpenAd`](ads-swiftui.md#5-app-open--khác-đường-uikit) tự lo trọn vòng đời.

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
