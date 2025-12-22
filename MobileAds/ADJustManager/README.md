# ADJustManager

## Overview
`ADJustManager` is a singleton manager in the MobileAds framework that handles ad revenue tracking with Adjust SDK and Firebase Analytics.

## Features
- Track ad impressions to Adjust SDK
- Track ad revenue events to Adjust
- Log ad impressions to Firebase Analytics
- Support multiple ad types: interstitial, app open, native, banner, reward
- Reusable across multiple projects via MobileAds framework

## Installation

ADJustManager is included in the MobileAds framework. Adjust SDK is already a dependency in MobileAds.podspec.

```ruby
pod 'MobileAds', :git => "https://github.com/BKPlusResearch/MobileAds.git", :branch => 'new-MobileAds'
```

## Setup

### 1. Configure Adjust in AppDelegate

```swift
import UIKit
import MobileAds
import Adjust

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Configure Adjust SDK
        configureAdjust()

        // Configure ADJustManager with impression token
        let adjustConfig = AppADJustConfig(impressionToken: "YOUR_IMPRESSION_TOKEN_HERE")
        ADJustManager.shared.configure(with: adjustConfig)

        return true
    }

    private func configureAdjust() {
        #if DEBUG
        let environment = ADJEnvironmentSandbox
        #else
        let environment = ADJEnvironmentProduction
        #endif

        let adjustConfig = ADJConfig(
            appToken: "YOUR_APP_TOKEN_HERE",
            environment: environment
        )

        adjustConfig?.logLevel = ADJLogLevelVerbose
        Adjust.appDidLaunch(adjustConfig)
    }
}
```

### 2. Get Adjust Tokens

1. **App Token**:
   - Go to Adjust Dashboard → Your App → Settings
   - Copy the App Token

2. **Impression Token**:
   - Go to Adjust Dashboard → Events → Create Event
   - Name: "ad_impression" or similar
   - Copy the Event Token

## Usage

### Automatic Tracking (Recommended)

**ADJustManager is already integrated into AdMobHelper!** All ad types automatically track revenue when ads are loaded. You don't need to add any code manually.

The framework automatically adds `paidEventHandler` to all ad types:
- ✅ Interstitial ads
- ✅ App Open ads
- ✅ Rewarded ads
- ✅ Rewarded Interstitial ads
- ✅ Banner ads
- ✅ Native ads

### Manual Usage (Optional)

If you need to track ad revenue manually outside of AdMobHelper:

```swift
import MobileAds
import GoogleMobileAds

// In your custom ad callback
interstitialAd?.paidEventHandler = { adValue in
    ADJustManager.shared.logRevenue(adType: .interstitial, adValue: adValue)
}
```

### Integration in AdMobHelper

Here's how ADJustManager is integrated in the MobileAds framework:

#### Interstitial Ad (AdMobHelper+Interstitial.swift)

```swift
do {
    interstitialAd = try await InterstitialAd.load(
        with: adUnitID.adUnitIDString, request: Request())
    interstitialAd?.fullScreenContentDelegate = self

    // Track ad revenue
    interstitialAd?.paidEventHandler = { adValue in
        ADJustManager.shared.logRevenue(adType: .interstitial, adValue: adValue)
    }

    print("Interstitial ad loaded successfully")
} catch {
    // Error handling...
}
```

#### App Open Ad (AdMobHelper+AppOpen.swift)

```swift
do {
    appOpenAd = try await AppOpenAd.load(
        with: adUnitID.adUnitIDString, request: Request())
    appOpenAd?.fullScreenContentDelegate = self
    appOpenLoadTime = Date()

    // Track ad revenue
    appOpenAd?.paidEventHandler = { adValue in
        ADJustManager.shared.logRevenue(adType: .appOpen, adValue: adValue)
    }

    print("App open ad loaded successfully")
} catch {
    // Error handling...
}
```

#### Rewarded Ad (AdMobHelper+Rewarded.swift)

```swift
do {
    rewardedAd = try await RewardedAd.load(
        with: adUnitID.adUnitIDString, request: Request())
    rewardedAd?.fullScreenContentDelegate = self

    // Track ad revenue
    rewardedAd?.paidEventHandler = { adValue in
        ADJustManager.shared.logRevenue(adType: .reward, adValue: adValue)
    }

    print("Rewarded ad loaded successfully")
} catch {
    // Error handling...
}
```

#### Rewarded Interstitial Ad (AdMobHelper+RewardedInterstitial.swift)

```swift
do {
    rewardedInterstitialAd = try await RewardedInterstitialAd.load(
        with: adUnitID.adUnitIDString, request: Request())
    rewardedInterstitialAd?.fullScreenContentDelegate = self

    // Track ad revenue
    rewardedInterstitialAd?.paidEventHandler = { adValue in
        ADJustManager.shared.logRevenue(adType: .reward, adValue: adValue)
    }

    print("Rewarded interstitial ad loaded successfully")
} catch {
    // Error handling...
}
```

#### Banner Ad (AdMobHelper+Banner.swift)

```swift
let bannerView = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: 375))
bannerView.adUnitID = adUnitID.adUnitIDString
bannerView.rootViewController = rootViewController

// Store banner view and callbacks
self.bannerAd = bannerView
self.bannerAdStatusCallback = statusCallback

// Set self as delegate to track events
bannerView.delegate = self

// Track ad revenue
bannerView.paidEventHandler = { adValue in
    ADJustManager.shared.logRevenue(adType: .banner, adValue: adValue)
}

bannerView.load(Request())
```

#### Native Ad (NativeAdLoaderDelegateHelper.swift)

```swift
func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
    debugPrint("Native ad loaded successfully")

    // Track ad revenue
    nativeAd.paidEventHandler = { adValue in
        ADJustManager.shared.logRevenue(adType: .native, adValue: adValue)
    }

    onAdLoaded?(nativeAd)
}
```

## What Gets Tracked

When you call `ADJustManager.shared.logRevenue(adType:adValue:)`, it automatically tracks to three destinations:

### 1. Adjust Ad Revenue
```swift
Source: "admob_sdk"
Network: "AdMob"
Unit: ad type (interstitial, appOpen, native, banner, reward)
Placement: "default"
Impressions: 1
Revenue: value from GADAdValue
Currency: from GADAdValue
```

### 2. Adjust Event (if impression token configured)
```swift
Event Token: from AppADJustConfig
Revenue: value from GADAdValue
Currency: from GADAdValue
```

### 3. Firebase Analytics
```swift
Event Name: "ad_impression_ios"
Parameters:
  - AnalyticsParameterAdPlatform: "AdMob"
  - AnalyticsParameterCurrency: "USD"
  - AnalyticsParameterValue: revenue value (formatted to 6 decimals)
```

## Configuration Object

### AppADJustConfig

```swift
public struct AppADJustConfig {
    public let impressionToken: String?

    public init(impressionToken: String?)
}
```

**Properties:**
- `impressionToken`: Optional event token from Adjust dashboard. If nil, only ad revenue will be tracked (not event).

## Ad Types

### ADJAdType

```swift
public enum ADJAdType: String {
    case interstitial
    case appOpen
    case native
    case banner
    case reward
}
```

## Debug Logs

When tracking ads in DEBUG mode, you'll see logs like:

```
✅ [ADJustManager] Configured with impression token: abc123xyz
💰 [AdRevenue] trackAdRevenue(adType:revenueUSD:currency:) interstitial - 0.012345 USD
💰 [AdRevenue] trackAdjustEvent(revenueUSD:currency:) - 0.012345 USD
💰 [AdRevenue] logRevenue(value:) - 0.012345
```

## Best Practices

1. **Configure Early**: Call `ADJustManager.shared.configure()` in `application(_:didFinishLaunchingWithOptions:)` before showing any ads

2. **Use Impression Token**: Always provide an impression token for detailed event tracking in Adjust

3. **Consistent Tracking**: Add paid event handlers to ALL ad types in your app for comprehensive revenue tracking

4. **Test First**: Use Adjust sandbox environment during development to verify tracking works correctly

5. **Monitor Dashboard**: Check Adjust and Firebase Analytics dashboards to confirm data is being received

## Troubleshooting

### No data in Adjust Dashboard
- Verify app token and impression token are correct
- Check you're using the right environment (sandbox vs production)
- Ensure ads are actually showing and generating revenue
- Check debug logs for tracking confirmation

### No data in Firebase Analytics
- Verify Firebase is configured in AppDelegate
- Check Firebase Analytics is enabled for your app
- Debug mode: `Analytics.setAnalyticsCollectionEnabled(true)`

### Build Errors
- Ensure Adjust SDK is installed: `pod install`
- Check import statements: `import Adjust` and `import MobileAds`
- Verify iOS deployment target is 15.0+

## Version Requirements

- iOS 15.0+
- Swift 5.5+
- Adjust SDK ~> 5.0.0
- Firebase Analytics ~> 11.15.0
- Google Mobile Ads SDK ~> 12.0.0

## License

Part of MobileAds framework - MIT License
