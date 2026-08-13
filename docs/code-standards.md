# MobileAds — Code Standards & Structure

## 1. Project Structure

```
MobileAds/                          # Repository root
├── MobileAds/                      # Framework source
│   ├── MobileAds.h                 # Umbrella header
│   ├── AdMobHelper/                # Core ad management module
│   ├── AdMob/                      # Supporting ad infrastructure
│   │   ├── Service/                # AdMetrics tracking services
│   │   ├── Model/                  # Data models
│   │   └── AdNative/               # Native ad view variants
│   ├── IAP/                        # In-App Purchase module
│   ├── ADJustManager/              # Adjust attribution module
│   ├── TikTokManager/              # TikTok attribution module
│   ├── FacebookManager/            # Facebook attribution module
│   ├── FirebaseLogger/             # Firebase Analytics module
│   ├── RemoteConfig/               # Remote Config module
│   ├── SwiftUI/                    # SwiftUI wrappers over the UIKit ad views
│   ├── Extension/                  # Shared utilities
│   ├── Assets/                     # Image assets
│   └── MobileAds.docc/            # Documentation catalog
├── MobileAds.podspec               # CocoaPods specification
├── MobileAds.xcodeproj/            # Xcode project
├── MobileAds.xcworkspace/          # Workspace (with Pods)
├── Podfile                         # Development dependencies
├── Podfile.lock                    # Locked dependency versions
├── Pods/                           # CocoaPods dependencies (gitignored)
├── docs/                           # Project documentation
└── README.md                       # Usage guide
```

---

## 2. Naming Conventions

### Files

| Pattern | Example | When |
|---|---|---|
| `{ClassName}.swift` | `AdMobHelper.swift` | Main class file |
| `{ClassName}+{Extension}.swift` | `AdMobHelper+Banner.swift` | Extension files |
| `{Feature}Manager.swift` | `TikTokManager.swift` | Manager singletons |
| `{Feature}Service.swift` | `NativeAdService.swift`, `IAPService.swift` | Service classes |
| `{Feature}Config.swift` | `TikTokConfig.swift` | Configuration models |
| `{Name}View.swift` | `BannerAdView.swift` | UIView subclasses |
| `{Name}LoadingView.swift` | `BannerAdLoadingView.swift` | Shimmer/skeleton views |

### Types

| Convention | Example |
|---|---|
| Classes: PascalCase | `AdMobHelper`, `NativeAdService` |
| Protocols: PascalCase + `able`/`ble` suffix | `AdUnitIdentifiable`, `RemoteKeyIdentifiable` |
| Enums: PascalCase | `AppOpenAdStatus`, `ADJAdType` |
| Enum cases: camelCase | `.didPresent`, `.didFailToLoad` |
| Type aliases: PascalCase | `BoolBlockAds` |

### Properties & Methods

| Convention | Example |
|---|---|
| Properties: camelCase | `isInterstitialLoading`, `bannerAd` |
| Methods: camelCase verb-first | `loadBannerAd(...)`, `showInterstitialAd(...)` |
| Callbacks: camelCase + `Callback` | `bannerAdStatusCallback`, `appOpenAdStatusCallback` |
| Booleans: `is`/`has`/`should` prefix | `isSDKInitialized`, `shouldSkipNextAppResume` |

---

## 3. Architecture Patterns

### Singleton Pattern

All managers use the singleton pattern with `static let shared`:

```swift
public class SomeManager {
    public static let shared = SomeManager()
    private init() {}
}
```

### Protocol-Based Configuration

Consumer apps define their own types conforming to framework protocols:

```swift
// Framework defines:
public protocol AdUnitIdentifiable {
    var adUnitIDString: String { get }
}

// App implements:
enum AppAdUnitID: AdUnitIdentifiable {
    case bannerHome
    var adUnitIDString: String { ... }
}
```

### Extension-Based Organization

Large classes are split into extensions by feature area:

```
AdMobHelper.swift                    # Core properties & init
AdMobHelper+Banner.swift             # Banner ad operations
AdMobHelper+Interstitial.swift       # Interstitial operations
AdMobHelper+Rewarded.swift           # Rewarded ad operations
AdMobHelper+FullScreenDelegate.swift # Delegate implementation
```

### Callback-Based Status Reporting

Ad lifecycle events reported through typed enum callbacks:

```swift
public enum InterstitialAdStatus {
    case didPresent
    case didFailToPresent
    case willDismiss
    case didDismiss
}
```

### Revenue Attribution Pipeline

Central `ADJustManager.logRevenue()` fans out to all platforms:

```
Ad Impression
    └─→ ADJustManager.logRevenue()
         ├─→ Adjust (ADJAdRevenue)
         ├─→ Adjust Event (impression token)
         ├─→ Firebase Analytics (ad_impression)
         ├─→ TikTok (InAppADImpr + ImpressionLevelAdRevenue)
         └─→ Facebook (AD_IMPRESSION)
```

---

## 4. Concurrency Model

- **`@MainActor` isolation** on all ad-related classes (`AdMobHelper`, `NativeAdService`, `IAPService`, `AdMetricsTracker`, `NativeAdConfiguration`).
- **`@preconcurrency import GoogleMobileAds`** to suppress concurrency warnings from the GMA SDK.
- **`async/await`** for IAP operations (fetch, purchase, restore).
- **`Task.detached`** for transaction update listener.

---

## 5. Access Control

| Modifier | Usage |
|---|---|
| `public` | All API surfaces consumed by integrating apps |
| `public internal(set)` | Properties readable externally, writable internally (e.g., `interstitialAd`) |
| `internal` | Cross-module helpers within the framework |
| `private` | Implementation details |
| `fileprivate` | Shared within a single file (e.g., `BannerAdView` cache) |

---

## 6. Error Handling

Ad and IAP operations throw typed enums rather than returning optionals or `NSError`. The cases are owned by the source, not by this document:

| Enum | Owner |
|---|---|
| `AdMobHelperError` | `MobileAds/AdMobHelper/AdMobHelper.swift` |
| `IAPError` | `MobileAds/IAP/IAPModels.swift` |

Rules when adding a case:

- A refused *presentation* is an error, not a silent no-op — the caller must be able to distinguish "no ad" from "ad exists but cannot show now" (`.adNotLoaded` vs `.appInBackground`).
- Whatever throws must first undo its own UI: hide the loading overlay and leave the loaded ad intact so the next attempt can reuse it.
- `IAPError` conforms to `LocalizedError`; ad errors do not, because ad failures are handled by the integrating app rather than shown to users.

---

## 7. Debug Logging

Consistent debug print patterns:

```
✅ Success:   "✅ [Module] Description"
❌ Error:     "❌ [Module] Description"
⚠️ Warning:   "⚠️ [Module] Description"
💰 Revenue:   "💰 [AdRevenue] function — value currency"
📊 Metrics:   "📊 [AdMetrics] EVENT type — adUnit"
📦 Cache:     "📦 [Component] Cache description"
🗑️ Cleanup:   "🗑️ [Component] Cache cleared"
📘 Facebook:  "📘 [FacebookManager] Description"
🔥 Firebase:  "🔥 [timestamp] event"
```

---

## 8. Testing

- No unit tests currently in the repository.
- Debug-time testing via `AdMetricsTracker` and `AdMetricsMonitorView`.
- Manual testing with Google test ad unit IDs in `DEBUG` builds.
- `#if DEBUG` guards for test vs. production ad unit switching.

---

## 9. Version Management

- Version tracked in `MobileAds.podspec` (`spec.version`); git tags for releases.
- Dependencies pinned with pessimistic version constraints (`~>`) in both `Podfile` and the podspec. The two must agree with `Podfile.lock` before a release — see `deployment-guide.md`.
