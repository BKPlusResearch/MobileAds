# NativeAdViewMedium - Hướng dẫn sử dụng

## Giới thiệu
`NativeAdViewMedium` là một custom native ad view với layout hiện đại:
- **MediaView bên trái** (200pt width) - có thể tự động ẩn khi không có media
- **Content bên phải** với icon, headline, body, và CTA button
- Sử dụng **StackView** để tự động collapse mediaView
- Hỗ trợ **customization** đầy đủ qua configuration

## Layout Structure

```
┌─────────────────────────────────────────┐
│  Ad Label (top-left corner)             │
│  ┌──────────┬──────────────────────┐    │
│  │          │  Icon  [Ad]          │    │
│  │  Media   │  Headline            │    │
│  │  View    │                      │    │
│  │ (200pt)  │  Body text...        │    │
│  │          │                      │    │
│  │          │  [CTA Button]        │    │
│  └──────────┴──────────────────────┘    │
└─────────────────────────────────────────┘
```

## Cách sử dụng cơ bản

### 1. Load ad với NativeAdService (Khuyến nghị)

```swift
import MobileAds

class MyViewController: UIViewController {
    @IBOutlet weak var adContainerView: UIView!
    private let nativeAdService = NativeAdService()

    func loadNativeAd() {
        nativeAdService.loadNativeAd(
            containerView: adContainerView,
            adUnitID: .nativeAd, // hoặc adUnitID của bạn
            rootViewController: self,
            viewType: .medium,  // Sử dụng layout medium
            configuration: nil, // Sử dụng config mặc định
            statusCallback: { success in
                if success {
                    print("Native ad loaded successfully")
                } else {
                    print("Failed to load native ad")
                }
            }
        )
    }
}
```

### 2. Load ad thủ công (Advanced)

```swift
import MobileAds

class MyViewController: UIViewController {
    @IBOutlet weak var adContainerView: UIView!

    func loadNativeAdManually() {
        // Load view từ XIB
        guard let nativeAdView = NativeAdViewMedium.loadFromXib() else {
            print("Failed to load NativeAdViewMedium")
            return
        }

        // Apply configuration (optional)
        nativeAdView.applyConfiguration(NativeAdConfiguration.shared)

        // Load native ad data (sử dụng AdMobHelper hoặc GADAdLoader)
        // ... your ad loading logic ...

        // Sau khi có native ad:
        nativeAdView.nativeAd = nativeAd

        // Update media visibility
        let hasMedia = nativeAd.mediaContent != nil &&
                      (nativeAd.mediaContent.hasVideoContent ||
                       nativeAd.mediaContent.mainImage != nil)
        nativeAdView.updateMediaVisibility(hasMedia: hasMedia)

        // Add to container
        adContainerView.addSubview(nativeAdView)
        nativeAdView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
```

## Customization

### 1. Sử dụng Global Configuration (NativeAdConfiguration.shared)

```swift
// Trong AppDelegate hoặc nơi setup app
func setupNativeAdConfiguration() {
    let config = NativeAdConfiguration.shared

    // Fonts
    config.headlineFont = UIFont.systemFont(ofSize: 16, weight: .bold)
    config.bodyFont = UIFont.systemFont(ofSize: 14, weight: .regular)
    config.callToActionFont = UIFont.systemFont(ofSize: 16, weight: .semibold)

    // Text Colors
    config.headlineTextColor = .black
    config.bodyTextColor = .darkGray
    config.callToActionTextColor = .white

    // Border & Background
    config.borderColor = .lightGray
    config.borderWidth = 1.0
    config.backgroundColor = .white

    // Button Gradient (Optional)
    config.useGradientForCallToAction = true
    config.callToActionGradientStartColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
    config.callToActionGradientEndColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
    config.callToActionGradientStartPoint = CGPoint(x: 0.0, y: 0.5)
    config.callToActionGradientEndPoint = CGPoint(x: 1.0, y: 0.5)
}
```

### 2. Sử dụng Custom Configuration cho từng ad

```swift
func loadNativeAdWithCustomConfig() {
    // Tạo custom configuration
    let customConfig = NativeAdConfiguration()
    customConfig.headlineFont = UIFont.systemFont(ofSize: 18, weight: .bold)
    customConfig.bodyFont = UIFont.systemFont(ofSize: 15)
    customConfig.borderColor = .systemBlue
    customConfig.borderWidth = 2.0
    customConfig.backgroundColor = .systemBackground

    // Button với màu solid thay vì gradient
    customConfig.useGradientForCallToAction = false
    customConfig.callToActionBackgroundColor = .systemBlue
    customConfig.callToActionTextColor = .white

    // Load ad với custom config
    nativeAdService.loadNativeAd(
        containerView: adContainerView,
        adUnitID: .nativeAd,
        rootViewController: self,
        viewType: .medium,
        configuration: customConfig  // Truyền custom config
    )
}
```

## Các tùy chọn Customization

### Fonts
- `headlineFont: UIFont?` - Font cho headline
- `bodyFont: UIFont?` - Font cho body text
- `callToActionFont: UIFont?` - Font cho CTA button

### Text Colors
- `headlineTextColor: UIColor?` - Màu text của headline
- `bodyTextColor: UIColor?` - Màu text của body
- `callToActionTextColor: UIColor?` - Màu text của button

### Border & Background
- `borderColor: UIColor?` - Màu border
- `borderWidth: CGFloat?` - Độ dày border
- `backgroundColor: UIColor?` - Màu background

### Button Styling
**Option 1: Solid Color**
```swift
config.useGradientForCallToAction = false
config.callToActionBackgroundColor = .systemBlue
```

**Option 2: Gradient**
```swift
config.useGradientForCallToAction = true
config.callToActionGradientStartColor = .red
config.callToActionGradientEndColor = .orange
config.callToActionGradientStartPoint = CGPoint(x: 0.0, y: 0.5)  // Left
config.callToActionGradientEndPoint = CGPoint(x: 1.0, y: 0.5)    // Right
```

## Media View Management

MediaView sẽ tự động ẩn/hiện dựa trên nội dung của ad khi sử dụng `NativeAdService`.

Nếu load thủ công, bạn có thể control:

```swift
// Ẩn media view
nativeAdView.hideMediaView()

// Hiện media view
nativeAdView.showMediaView()

// Tự động update dựa trên ad content
let hasMedia = nativeAd.mediaContent != nil &&
              (nativeAd.mediaContent.hasVideoContent ||
               nativeAd.mediaContent.mainImage != nil)
nativeAdView.updateMediaVisibility(hasMedia: hasMedia)
```

## So sánh với NativeAdViewSmall

| Feature | NativeAdViewSmall | NativeAdViewMedium |
|---------|-------------------|-------------------|
| Layout | Vertical (top to bottom) | Horizontal (media left, content right) |
| Media View | Không có | Có, với khả năng ẩn/hiện |
| Best for | Banner ads, small spaces | Content ads, larger spaces |
| Height | ~152pt | ~144pt |
| Width | Any | Recommended 375pt+ |

## Tips

1. **Height constraint**: NativeAdViewMedium hoạt động tốt nhất với height ~144pt
2. **Width constraint**: Nên có width tối thiểu 375pt để hiển thị đẹp
3. **Auto-hide media**: Khi ad không có media, view sẽ tự động thu gọn nhờ StackView
4. **Gradient performance**: Gradient được update tự động khi view layout changes
5. **Configuration**: Có thể dùng global config hoặc custom config cho từng ad

## Troubleshooting

**Q: MediaView không ẩn khi ad không có media?**
A: Đảm bảo bạn gọi `updateMediaVisibility(hasMedia:)` sau khi set `nativeAd`

**Q: Gradient không hiển thị đúng?**
A: Đảm bảo `useGradientForCallToAction = true` và set đủ `startColor` và `endColor`

**Q: Custom font không apply?**
A: Đảm bảo gọi `applyConfiguration()` sau khi load view từ XIB

**Q: View bị stretch/compress?**
A: Đặt height constraint cho container view (~144pt) và đảm bảo width đủ lớn
