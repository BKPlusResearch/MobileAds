# MobileAds — Ads trên SwiftUI

Cùng một pod, cùng `AdMobHelper` bên dưới. Không cần podspec riêng, không cần
subspec: sàn deployment là iOS 15 và mọi type SwiftUI đều `@available(iOS 15.0, *)`,
nên app UIKit chỉ đơn giản là không `import` tới chúng.

Phần dùng chung cho cả hai surface — cài đặt, khai báo `AdUnitIdentifiable`,
`configAds`, quy tắc full-screen, cache native, `NativeAdConfiguration`, cờ bật/tắt
ads — nằm ở [README](../README.md).

Đường UIKit: [ads-uikit.md](ads-uikit.md). In-App Purchase: [in-app-purchases.md](in-app-purchases.md).

## Mục lục

- [1. Cầu nối cho `configAds`](#1-cầu-nối-cho-configads) · [2. Banner](#2-banner) ·
  [3. Native](#3-native) · [4. Full-screen](#4-full-screen--điều-khiển-bằng-bindingbool) ·
  [5. App Open](#5-app-open--khác-đường-uikit)

## 1. Cầu nối cho `configAds`

`AdUnitIdentifiable` và consent dùng chung, không đổi. Riêng
[`configAds(from:)`](../README.md#2-khởi-tạo-sdk--consent) cần một `UIViewController`
mà SwiftUI không sẵn có. Pod **không** export cầu nối này — `ViewControllerResolver`
là `internal`, chỉ phục vụ các view/modifier bên trong pod. App SwiftUI tự dựng một
cái, dùng đúng một lần lúc launch:

```swift
struct AdsBootstrap: UIViewControllerRepresentable {
    let onReady: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> BootstrapViewController {
        let vc = BootstrapViewController()
        vc.onReady = onReady
        return vc
    }

    func updateUIViewController(_ vc: BootstrapViewController, context: Context) {}

    /// `didMove(toParent:)` là thời điểm chắc chắn VC đã vào hierarchy và có
    /// presenter sống — UMP form lẫn ATT prompt đều cần điều đó.
    final class BootstrapViewController: UIViewController {
        var onReady: ((UIViewController) -> Void)?

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            guard let parent else { return }
            onReady?(parent)
        }
    }
}
```

```swift
struct RootView: View {
    @State private var adsReady = false

    var body: some View {
        ContentView()
            .background(
                AdsBootstrap { presenter in
                    guard !adsReady else { return }   // chỉ chạy một lần
                    adsReady = true
                    AdMobHelper.shared.configAds(from: presenter) { }
                }
                .frame(width: 0, height: 0)
            )
    }
}
```

Cách khác, đơn giản hơn nếu app đã có `UIApplicationDelegateAdaptor`: giữ một splash
UIKit rồi gọi `configAds` từ đó như ở [đường UIKit](../README.md#2-khởi-tạo-sdk--consent).

## 2. Banner

```swift
BannerAdSwiftUI(
    adUnitID: AppAdUnitID.banner,
    isCollapsible: false,                 // true -> banner thu gọn
    collapsiblePlacement: .bottom,
    onEvent: { event in                   // tuỳ chọn, chỉ sự kiện của banner này
        switch event {
        case .didRecordImpression: log("banner_impression")
        case .didRecordClick: log("banner_click")
        case .didShowCollapsibleExpanded: log("banner_expand")
        case .didFailToLoad(let error): log("banner_load_fail", error.code)
        default: break
        }
    },
    adSize: .small                        // tuỳ chọn: .small 320×50 (mặc định), .large 320×100
)
.frame(height: BannerAdSize.small.height)
```

`adSize` là size chuẩn của AdMob (`BannerAdSize.small` = `AdSizeBanner` 320×50,
`.large` = `AdSizeLargeBanner` 320×100). Creative được làm đúng size đó nên không bị kéo giãn
hay crop; trên máy rộng hơn 320pt ad nằm giữa, hai bên là nền của view. `.frame(height:)` phải
bằng `adSize.height`.

`onEvent` (`BannerAdEvent`, main thread) cũng có trên UIKit: `BannerAdView.onEvent`, gán
trước `loadAd`. Mỗi case lấy từ một callback thật của Google Mobile Ads:

| `BannerAdEvent` | Nguồn SDK |
|---|---|
| `.didLoad` | `bannerViewDidReceiveAd`, hoặc banner lấy từ cache 1 giờ |
| `.didFailToLoad(NSError)` | `bannerView(_:didFailToReceiveAdWithError:)` |
| `.didRecordImpression` / `.didRecordClick` | `bannerViewDidRecordImpression` / `bannerViewDidRecordClick` |
| `.didShowCollapsibleExpanded` | request có `collapsible` và ad trả về `isCollapsible == true` |
| `.willPresentScreen` / `.willDismissScreen` / `.didDismissScreen` | callback cùng tên |

Collapsible: SDK **không** có callback mở rộng hay thu gọn. Nó chỉ có `isCollapsible` và
tài liệu Google ghi rằng ad collapsible hiện overlay mở rộng ngay khi nằm trong view
hierarchy — `.didShowCollapsibleExpanded` dựa đúng vào đó. Không có tín hiệu nào cho "user
bấm thu gọn"; ba callback `*Screen` là cho nội dung full-screen do ad mở, không phải nút
thu gọn.

## 3. Native

```swift
NativeAdSwiftUI(
    adUnitID: AppAdUnitID.nativeFeed,
    viewType: .medium,                    // .small | .medium
    configuration: nil,                   // nil -> NativeAdConfiguration.shared
    enableCache: true,
    onLoaded: { ok in },                  // tuỳ chọn: load xong (true) / lỗi (false)
    onImpression: { log("native_impression", placement) }   // tuỳ chọn
)
.frame(height: 300)
```

`onImpression` chỉ chạy khi ad do **chính view này** hiển thị ghi nhận impression
(`nativeAdDidRecordImpression`), nên host gắn được impression vào placement — kể cả khi
nhiều placement dùng chung một ad unit. `AdMobHelper.shared.nativeAdStatusCallback` vẫn
chạy cho mọi native ad như trước.

Cache dùng chung cơ chế với đường UIKit: single-use, xoá khi ad ghi nhận
impression, hết hạn sau 1 giờ. Xem
[Native ads: cache & giao diện](../README.md#4-native-ads--cache--giao-diện) và
[NATIVE_AD_CACHE.md](../NATIVE_AD_CACHE.md).

## 4. Full-screen — điều khiển bằng `Binding<Bool>`

Đọc [quy tắc chung cho full-screen ads](../README.md#3-quy-tắc-chung-cho-full-screen-ads) trước.

Cả ba modifier tự set `isPresented = false` khi ad đóng, fail, hoặc user nhận
reward xong rồi đóng — không cần app tự reset cờ.

```swift
struct ContentView: View {
    @State private var showInterstitial = false
    @State private var showRewarded = false
    @State private var showRewardedInterstitial = false
    @State private var coins = 0

    var body: some View {
        VStack { /* ... */ }
            .interstitialAd(
                isPresented: $showInterstitial,
                adUnitID: AppAdUnitID.interstitial
            )
            .rewardedAd(
                isPresented: $showRewarded,
                adUnitID: AppAdUnitID.rewarded,
                onReward: { reward in coins += reward.amount.intValue }
            )
            .rewardedInterstitialAd(
                isPresented: $showRewardedInterstitial,
                adUnitID: AppAdUnitID.rewardedInterstitial,
                onReward: { reward in coins += reward.amount.intValue }
            )
    }
}
```

Cả ba đều nhận thêm `onStatusChange:` tuỳ chọn nếu cần theo dõi vòng đời ad.

## 5. App Open — khác đường UIKit

```swift
ContentView()
    .appOpenAd(
        adUnitID: AppAdUnitID.appOpen,
        isEnabled: !entitlementIsActive     // tắt cho user premium
    )
```

> ⚠️ Ở đường UIKit, pod **không** tự hiện App Open — app phải tự nối
> `willEnterForeground` (xem [App Open & App Resume](ads-uikit.md#6-app-open--app-resume)).
> Modifier SwiftUI thì **tự làm việc đó**: theo dõi `scenePhase`, preload ở lần
> `.active` đầu, rồi show ở mỗi lần `.active` sau đó. Đừng nối thêm observer thủ
> công bên cạnh modifier — sẽ thành hai lần show.

Modifier tự lo trọn vòng đời, app không cần gọi gì thêm:

- **Chỉ show sau một chuyến background thật.** `.active` còn được chạm tới từ
  `.inactive` — kéo control center, mở app switcher, có cuộc gọi đến — và những
  lần đó không phải resume. Đường UIKit không dính vì `willEnterForeground`
  không fire; modifier chặn bằng cách yêu cầu đã đi qua `.background` trước.
- **Tôn trọng `shouldSkipNextAppResume` rồi tự reset.** Vừa xem
  interstitial/rewarded xong, hoặc user bấm ad rồi rời app, thì lượt resume kế
  tiếp bị bỏ qua — không chồng hai ad full-screen. Modifier tự gọi
  `resetAppResumeSkipFlag()` sau khi tiêu thụ cờ, nên lần background sau lại
  preload bình thường. App **không** cần tự reset.
- **Tắt ads bằng `isEnabled:`, không phải bằng cờ trong pod.** `isEnabled == false`
  thì modifier không preload và không show. Pod không có cờ bật/tắt toàn cục — ba
  modifier full-screen còn lại cũng phải do app tự gate (xem
  [Tắt ads cho user premium](../README.md#5-tắt-ads-cho-user-premium)).
