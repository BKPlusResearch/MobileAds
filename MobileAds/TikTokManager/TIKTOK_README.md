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
        let tiktokConfig = TikTokConfig(
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

### TikTokConfig Parameters

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

Ad revenue is automatically tracked when using `ADJustManager.logRevenue()`:

```swift
// This automatically sends to TikTok, Adjust, and Firebase
ADJustManager.shared.logRevenue(adType: .interstitial, adValue: adValue)
```

To track ad revenue manually:

```swift
TikTokManager.shared.trackAdRevenue(
    adType: .interstitial,  // .banner, .native, .reward, .appOpen
    revenueUSD: 0.005,
    adNetwork: "AdMob"
)
```

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
let config = TikTokConfig(
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
