# FirebaseLogger

Simple and type-safe Firebase Analytics wrapper for iOS apps.

## Features

✅ Type-safe event names and parameters
✅ Extensible for app-specific events
✅ Debug mode with formatted console output
✅ User properties tracking
✅ Error logging helper
✅ Screen tracking helper

## Architecture

```
MobileAds (Framework)
├── FirebaseLogger.swift          - Main logger class
├── AnalyticsEvent.swift          - Common event names
└── LogParameter.swift            - Common parameter keys

YourApp
├── AnalyticsEvent+YourApp.swift  - App-specific events
└── LogParameter+YourApp.swift    - App-specific parameters
```

## Installation

1. Add `FirebaseAnalytics` to your Podfile
2. Import `MobileAds` in your app
3. Configure Firebase in AppDelegate

```swift
import FirebaseCore

FirebaseApp.configure()
```

## Usage

### Basic Event Logging

```swift
import MobileAds

// Simple event
FirebaseLogger.shared.logEvent(.appOpen)

// Event with parameters
FirebaseLogger.shared.logEvent(.purchaseSuccess, params: [
    .productId: "premium_yearly",
    .price: 49.99,
    .currency: "USD"
])
```

### Screen Tracking

```swift
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    FirebaseLogger.shared.logScreen("HomeViewController")
}
```

### Error Logging

```swift
do {
    try someOperation()
} catch {
    FirebaseLogger.shared.logError(error, context: "Failed to load products")
}
```

### User Properties

```swift
// Set premium status
FirebaseLogger.shared.setUserPremiumStatus(true)

// Custom property
FirebaseLogger.shared.setUserProperty(key: "user_level", value: "advanced")
```

## Extending for Your App

### 1. Create App-Specific Events

```swift
// AnalyticsEvent+XmasCall.swift
import MobileAds

extension AnalyticsEvent {
    static let callStart = AnalyticsEvent(rawValue: "call_start")
    static let callEnd = AnalyticsEvent(rawValue: "call_end")
    static let chatMessageSend = AnalyticsEvent(rawValue: "chat_message_send")
}
```

### 2. Create App-Specific Parameters

```swift
// LogParameter+XmasCall.swift
import MobileAds

extension LogParameter {
    static let callType = LogParameter(rawValue: "call_type")
    static let callMode = LogParameter(rawValue: "call_mode")
    static let characterId = LogParameter(rawValue: "character_id")
}
```

### 3. Use in Your App

```swift
FirebaseLogger.shared.logEvent(.callStart, params: [
    .callType: "video",
    .characterId: "santa_1"
])
```

## Debug Mode

Debug mode automatically prints formatted logs to console in DEBUG builds:

```
🔥 [10:30:45 AM] call_start
   📊 Parameters:
      • call_type: video
      • character_id: santa_1
```

Toggle debug mode:
```swift
FirebaseLogger.shared.isDebugMode = false // Disable in production
```

## Common Events (Included)

**App Lifecycle**: `appOpen`, `appBackground`, `appTerminate`
**Screen Tracking**: `screenView`
**Errors**: `error`
**Ads**: `adRequest`, `adLoaded`, `adShown`, `rewardedAdEarned`
**IAP**: `paywallView`, `purchaseSuccess`, `purchaseFailed`
**Onboarding**: `onboardingStart`, `onboardingComplete`
**Settings**: `languageSelect`, `notificationPermissionRequest`, `rateAppPrompt`

## Common Parameters (Included)

**Screen**: `screenName`, `screenClass`, `previousScreen`
**Errors**: `errorMessage`, `errorContext`, `errorCode`
**Ads**: `adType`, `adFormat`, `adPlacement`, `rewardType`
**IAP**: `productId`, `price`, `currency`, `transactionId`
**Actions**: `actionName`, `buttonName`, `itemId`
**Content**: `contentType`, `contentId`
**Generic**: `value`, `count`, `duration`, `source`

## Best Practices

1. **Use type-safe enums** - Never use raw strings
2. **Extend for app-specific events** - Keep common events in MobileAds
3. **Add context to errors** - Use the `context` parameter
4. **Log screen views** - Track user navigation flow
5. **Set user properties** - Track user segments
6. **Keep event names consistent** - Use snake_case
7. **Don't over-log** - Log meaningful events only

## Example Integration

```swift
// AppDelegate.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions...) -> Bool {
    FirebaseApp.configure()
    FirebaseLogger.shared.logEvent(.appOpen)
    return true
}

// ViewController.swift
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    FirebaseLogger.shared.logScreen("HomeViewController")
}

// PremiumVC.swift
func purchaseProduct() {
    Task {
        switch await EntitlementService.shared.purchase("premium_yearly") {
        case .purchased(let receipt):
            FirebaseLogger.shared.logEvent(.purchaseSuccess, params: [
                .productId: receipt.productID,
                .price: 49.99
            ])
        case .cancelled, .pending:
            break   // Neither is an error; do not log one.
        case .failed(let failure):
            FirebaseLogger.shared.logEvent(.purchaseFailed, params: [
                .productId: "premium_yearly",
                .errorMessage: String(describing: failure)
            ])
        }
    }
}
```
