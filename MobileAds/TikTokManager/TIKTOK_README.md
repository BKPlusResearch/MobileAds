# TikTok Business SDK Integration

## Overview

TikTokManager provides a singleton-based wrapper for TikTok Business SDK, enabling event tracking for marketing analytics.

---

## Installation

### 1. CocoaPods

TikTokBusinessSDK is already included in the MobileAds framework. If using MobileAds as a pod:

```ruby
pod 'MobileAds'
```

### 2. Info.plist Configuration (Host App)

Add the following to your app's `Info.plist`:

```xml
<!-- App Tracking Transparency -->
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads to you.</string>

<!-- SKAdNetwork IDs for TikTok -->
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>238da6jt44.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>22mmun2rn5.skadnetwork</string>
    </dict>
</array>
```

---

## Configuration

### AppDelegate Setup

```swift
import MobileAds

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Configure TikTok Business SDK
        let tiktokConfig = TikTokAppConfig(
            appId: "YOUR_APP_ID",              // From TikTok Ads Manager
            tiktokAppId: "YOUR_TIKTOK_APP_ID", // From TikTok Ads Manager
            debugMode: false,                   // Set true for testing
            enableATT: true                     // Enable App Tracking Transparency
        )
        TikTokManager.shared.configure(with: tiktokConfig)

        // Track app launch
        TikTokManager.shared.trackAppLaunch()

        return true
    }
}
```

### TikTokAppConfig Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `appId` | String | Yes | TikTok App ID from TikTok Ads Manager |
| `tiktokAppId` | String? | No | TikTok App ID (different from business app id) |
| `debugMode` | Bool | No | Enable verbose logging (default: false) |
| `enableATT` | Bool | No | Enable ATT request (default: true) |

---

## Event Tracking

### Standard Events

#### App Lifecycle

```swift
// App Launch
TikTokManager.shared.trackAppLaunch()

// Login
TikTokManager.shared.trackLogin()

// Registration
TikTokManager.shared.trackRegistration(method: "email")  // or "facebook", "google", "apple"
```

#### Content Events

```swift
// View Content
TikTokManager.shared.trackViewContent(
    contentId: "article_123",
    contentType: "article",
    contentName: "Article Title"
)

// Search
TikTokManager.shared.trackSearch(query: "search keywords")
```

#### E-Commerce Events

```swift
// Add to Cart
TikTokManager.shared.trackAddToCart(
    productId: "product_123",
    price: 29.99,
    quantity: 2,
    currency: "USD"
)

// Purchase
TikTokManager.shared.trackPurchase(
    productId: "product_123",
    price: 59.98,
    currency: "USD",
    transactionId: "order_abc123"
)

// Subscription
TikTokManager.shared.trackSubscription(
    productId: "premium_monthly",
    price: 9.99,
    currency: "USD"
)

// Start Trial
TikTokManager.shared.trackStartTrial(
    productId: "premium_trial",
    price: 0,
    currency: "USD"
)
```

#### Achievement Events

```swift
// Achieve Level
TikTokManager.shared.trackAchieveLevel(5)
```

### Custom Events

```swift
// Track custom event with parameters
TikTokManager.shared.trackCustomEvent("custom_event_name", params: [
    .custom("key1", "value1"),
    .custom("key2", 123),
    .value(99.99),
    .currency("USD")
])

// Track custom event without parameters
TikTokManager.shared.trackCustomEvent("simple_event")
```

### Using TikTokEventType Directly

```swift
// Track using enum
TikTokManager.shared.trackEvent(.purchase, params: [
    .productId("sku_123"),
    .value(49.99),
    .currency("USD"),
    .transactionId("txn_456")
])
```

---

## Available Event Types

| Event Type | Raw Value | Description |
|------------|-----------|-------------|
| `launchApp` | LaunchAPP | App launched |
| `installApp` | InstallApp | App installed |
| `completeRegistration` | CompleteRegistration | User registered |
| `login` | Login | User logged in |
| `logout` | Logout | User logged out |
| `viewContent` | ViewContent | Content viewed |
| `search` | Search | Search performed |
| `addToWishlist` | AddToWishlist | Item added to wishlist |
| `addToCart` | AddToCart | Item added to cart |
| `initiateCheckout` | InitiateCheckout | Checkout initiated |
| `addPaymentInfo` | AddPaymentInfo | Payment info added |
| `completePayment` | CompletePayment | Payment completed |
| `placeAnOrder` | PlaceAnOrder | Order placed |
| `purchase` | Purchase | Purchase completed |
| `subscribe` | Subscribe | Subscription started |
| `startTrial` | StartTrial | Trial started |
| `inAppAdImpression` | InAppADImpr | In-app ad impression |
| `inAppAdClick` | InAppADClick | In-app ad clicked |
| `achieveLevel` | AchieveLevel | Level achieved |
| `unlockAchievement` | UnlockAchievement | Achievement unlocked |
| `spendCredits` | SpendCredits | Credits spent |
| `share` | Share | Content shared |
| `rate` | Rate | App rated |

---

## Available Parameters

| Parameter | Key | Type | Description |
|-----------|-----|------|-------------|
| `.contentId()` | content_id | String | Content identifier |
| `.contentType()` | content_type | String | Content type |
| `.contentName()` | content_name | String | Content name |
| `.contentCategory()` | content_category | String | Content category |
| `.value()` | value | Double | Monetary value |
| `.currency()` | currency | String | Currency code (USD, EUR, etc.) |
| `.quantity()` | quantity | Int | Item quantity |
| `.transactionId()` | order_id | String | Transaction/order ID |
| `.productId()` | product_id | String | Product identifier |
| `.price()` | price | Double | Item price |
| `.registrationMethod()` | registration_method | String | Registration method |
| `.adType()` | ad_type | String | Ad type |
| `.adNetwork()` | network_name | String | Ad network name |
| `.level()` | level | Int | Level number |
| `.achievementId()` | achievement_id | String | Achievement identifier |
| `.query()` | query | String | Search query |
| `.custom()` | custom | Any | Custom key-value pair |

---

## Ad Revenue Tracking

### Method 1: Simple Version (Auto via AdRevenueManager)

```swift
// Simple - sends basic info to TikTok, Facebook, and Firebase
AdRevenueManager.shared.logRevenue(adType: .interstitial, adValue: adValue)
```

### Method 2: Detailed Version (Recommended for TikTok Attribution)

This method captures full AdMob response info for better TikTok attribution, matching the official TikTok documentation.

```swift
// In your ad callback (e.g., Interstitial)
interstitialAd.paidEventHandler = { [weak self] adValue in
    guard let self = self else { return }

    // Use detailed version with full response info
    AdRevenueManager.shared.logRevenue(
        adType: .interstitial,
        adValue: adValue,
        adUnitId: self.interstitialAd.adUnitID,
        responseInfo: self.interstitialAd.responseInfo
    )
}

// Rewarded Ad
rewardedAd.paidEventHandler = { [weak self] adValue in
    guard let self = self else { return }

    AdRevenueManager.shared.logRevenue(
        adType: .reward,
        adValue: adValue,
        adUnitId: self.rewardedAd.adUnitID,
        responseInfo: self.rewardedAd.responseInfo
    )
}

// Banner Ad
bannerView.paidEventHandler = { [weak self] adValue in
    guard let self = self else { return }

    AdRevenueManager.shared.logRevenue(
        adType: .banner,
        adValue: adValue,
        adUnitId: self.bannerView.adUnitID,
        responseInfo: self.bannerView.responseInfo
    )
}

// Native Ad
nativeAd.paidEventHandler = { [weak self] adValue in
    guard let self = self, let nativeAd = self.nativeAd else { return }

    AdRevenueManager.shared.logRevenue(
        adType: .native,
        adValue: adValue,
        adUnitId: "your_native_ad_unit_id",
        responseInfo: nativeAd.responseInfo
    )
}

// App Open Ad
appOpenAd.paidEventHandler = { [weak self] adValue in
    guard let self = self else { return }

    AdRevenueManager.shared.logRevenue(
        adType: .appOpen,
        adValue: adValue,
        adUnitId: self.appOpenAd.adUnitID,
        responseInfo: self.appOpenAd.responseInfo
    )
}
```

### Method 3: Manual TikTok Tracking

#### Simple Manual Tracking

```swift
TikTokManager.shared.trackAdRevenue(
    adType: .interstitial,  // .banner, .native, .reward, .appOpen
    revenueUSD: 0.005,
    adNetwork: "AdMob"
)
```

#### Detailed Manual Tracking (Full Control)

```swift
// Build TikTokAdRevenueInfo manually
let adRevenueInfo = TikTokAdRevenueInfo(
    value: adValue.value,
    currencyCode: adValue.currencyCode,
    precision: adValue.precision,
    adUnitId: "ca-app-pub-xxx/yyy",
    adSourceName: responseInfo.loadedAdNetworkResponseInfo?.adSourceName,
    adSourceId: responseInfo.loadedAdNetworkResponseInfo?.adSourceID,
    adSourceInstanceName: responseInfo.loadedAdNetworkResponseInfo?.adSourceInstanceName,
    adSourceInstanceId: responseInfo.loadedAdNetworkResponseInfo?.adSourceInstanceID,
    mediationGroupName: responseInfo.extras["mediation_group_name"] as? String,
    mediationABTestName: responseInfo.extras["mediation_ab_test_name"] as? String,
    mediationABTestVariant: responseInfo.extras["mediation_ab_test_variant"] as? String
)

TikTokManager.shared.trackAdRevenueEvent(adRevenueInfo, eventId: "custom_event_id")
```

### Comparison: Simple vs Detailed

| Feature | Simple Version | Detailed Version |
|---------|----------------|------------------|
| **Method** | `logRevenue(adType:adValue:)` | `logRevenue(adType:adValue:adUnitId:responseInfo:)` |
| **Data Sent** | value, currency, adType | Full AdMob response info |
| **TikTok API** | `trackEvent()` | `trackTTEvent()` with `TikTokBaseEvent` |
| **Attribution** | Basic | Enhanced (recommended) |
| **Use Case** | Quick integration | Production apps |

### TikTokAdRevenueInfo Properties

| Property | Type | Description |
|----------|------|-------------|
| `value` | NSDecimalNumber | Ad revenue value |
| `currencyCode` | String | Currency code (e.g., "USD") |
| `precision` | AdValuePrecision | Revenue precision level |
| `adUnitId` | String | AdMob ad unit ID |
| `adSourceName` | String? | Ad network name (e.g., "AdMob") |
| `adSourceId` | String? | Ad network ID |
| `adSourceInstanceName` | String? | Ad source instance name |
| `adSourceInstanceId` | String? | Ad source instance ID |
| `mediationGroupName` | String? | Mediation group name |
| `mediationABTestName` | String? | A/B test name |
| `mediationABTestVariant` | String? | A/B test variant |

---

## App Tracking Transparency (ATT)

Request ATT permission (iOS 14+):

```swift
if #available(iOS 14, *) {
    TikTokManager.shared.requestTrackingAuthorization { status in
        switch status {
        case .authorized:
            print("User authorized tracking")
        case .denied:
            print("User denied tracking")
        case .notDetermined:
            print("User has not decided yet")
        case .restricted:
            print("Tracking is restricted")
        @unknown default:
            break
        }
    }
}
```

---

## Debug Mode

Enable debug mode to see verbose logs in console:

```swift
let config = TikTokAppConfig(
    appId: "YOUR_APP_ID",
    tiktokAppId: "YOUR_TIKTOK_APP_ID",
    debugMode: true  // Enable for testing
)
```

Debug output example:
```
✅ [TikTokManager] SDK initialized successfully
✅ [TikTokManager] Configured with App ID: 123456, TikTok App ID: 789012
📊 [TikTokManager] Event tracked: LaunchAPP
📊 [TikTokManager] Event tracked: Purchase
   Parameters: ["product_id": "premium", "value": 9.99, "currency": "USD"]
```

---

## Verification

### 1. Check Console Logs

With `debugMode: true`, you should see logs like:
```
✅ [TikTokManager] SDK initialized successfully
📊 [TikTokManager] Event tracked: LaunchAPP
```

### 2. TikTok Events Manager

1. Go to [TikTok Ads Manager](https://ads.tiktok.com/)
2. Navigate to **Assets** > **Events**
3. Select your app
4. Check the **Event History** tab to see tracked events

### 3. Test Event Code

In debug mode, you can get the test event code:

```swift
if TikTokBusiness.isDebugMode() {
    let testCode = TikTokBusiness.getTestEventCode()
    print("Test Event Code: \(testCode)")
}
```

---

## Troubleshooting

### SDK Not Initializing

1. Verify `appId` and `tiktokAppId` are correct
2. Check network connectivity
3. Enable `debugMode` to see error messages

### Events Not Appearing in Dashboard

1. Events may take up to 24 hours to appear
2. Ensure SDK is initialized before tracking events
3. Check that ATT permission is granted for accurate attribution

### Build Errors

If you encounter `No such module 'TikTokBusinessSDK'`:

```bash
cd /path/to/project
pod deintegrate
pod install
```

---

## References

- [TikTok Business SDK Documentation](https://business-api.tiktok.com/portal/docs?id=1739584855420929)
- [TikTok Events API](https://business-api.tiktok.com/portal/docs?id=1741601162187777)
- [SKAdNetwork Configuration](https://business-api.tiktok.com/portal/docs?id=1739584860883969)
