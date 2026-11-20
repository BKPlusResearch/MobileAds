// swift-tools-version: 5.9
import PackageDescription

// Source-compatible SPM distribution. Mediation adapters are host-app dependencies;
// the CocoaPods distribution continues to supply its existing adapter bundle.
// AppsFlyer/ and Qonversion/ are CocoaPods-only subspecs; their SDKs are not
// dependencies of this package, so their sources are excluded.
let package = Package(
    name: "MobileAds",
    platforms: [.iOS(.v15)],
    products: [.library(name: "MobileAds", targets: ["MobileAds"])],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.19.2"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", exact: "13.8.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git", exact: "3.1.0"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", exact: "5.7.1"),
        .package(url: "https://github.com/facebook/facebook-ios-sdk.git", exact: "18.1.0"),
        .package(url: "https://github.com/tiktok/tiktok-business-ios-sdk.git", exact: "1.7.1"),
    ],
    targets: [
        .target(
            name: "MobileAds",
            dependencies: [
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
                .product(name: "GoogleUserMessagingPlatform", package: "swift-package-manager-google-user-messaging-platform"),
                .product(name: "SnapKit", package: "SnapKit"),
                .product(name: "FacebookCore", package: "facebook-ios-sdk"),
                .product(name: "TikTokBusinessSDK", package: "tiktok-business-ios-sdk"),
            ],
            path: "MobileAds",
            exclude: ["MobileAds.h", "AppsFlyer", "Qonversion", "FirebaseLogger/README.md", "AdRevenue/README.md",
                      "TikTokManager/TIKTOK_README.md", "AdMobHelper/NativeAdViewMedium-Usage.md", "AdMob/Media.xcassets.zip"],
            resources: [.process("AdMobHelper/NativeAdViewSmall.xib"), .process("AdMobHelper/NativeAdViewMedium.xib"),
                        .process("Assets")]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
