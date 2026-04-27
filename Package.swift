// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MobileAds",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "MobileAds",
            targets: ["MobileAds"]
        )
    ],
    dependencies: [
        // Firebase - Has SPM support
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            from: "11.15.0"
        ),

        // Google Mobile Ads SDK - Has SPM support
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            from: "13.0.0"
        ),

        // SnapKit - Auto Layout
        .package(
            url: "https://github.com/SnapKit/SnapKit.git",
            from: "5.7.1"
        ),

        // SkeletonView - Loading animations
        .package(
            url: "https://github.com/Juanpe/SkeletonView.git",
            from: "1.29.2"
        ),

        // Toast-Swift - User notifications
        .package(
            url: "https://github.com/scalessec/Toast-Swift.git",
            from: "5.0.1"
        ),

        // Facebook SDK - Has SPM support
        .package(
            url: "https://github.com/facebook/facebook-ios-sdk.git",
            from: "18.0.0"
        ),

        // NOTE: The following dependencies may NOT have full SPM support yet.
        // You may need to:
        // 1. Keep using CocoaPods for these specific dependencies
        // 2. Or implement alternatives locally
        //
        // - GoogleUserMessagingPlatform (⚠️ Limited SPM support)
        // - Adjust (⚠️ Limited SPM support)
        // - TikTokBusinessSDK (❌ CocoaPods only)
        // - PremiumAdmobAdapter (Custom adapter - need to include locally)
    ],
    targets: [
        .target(
            name: "MobileAds",
            dependencies: [
                // Firebase
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),

                // Google Mobile Ads
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),

                // UI Libraries
                .product(name: "SnapKit", package: "SnapKit"),
                .product(name: "SkeletonView", package: "SkeletonView"),
                .product(name: "Toast-Swift", package: "Toast-Swift"),

                // Facebook
                .product(name: "FacebookCore", package: "facebook-ios-sdk"),

                // NOTE: Missing SPM dependencies need to be handled:
                // - GoogleUserMessagingPlatform
                // - Adjust
                // - TikTokBusinessSDK
                // - PremiumAdmobAdapter
            ],
            path: "MobileAds",
            exclude: [
                // Exclude test files if needed
                "Exclude",
                "*.modulemap"
            ],
            sources: nil, // Automatically discover all Swift files
            resources: [
                // Process resources
                "MobileAds/**/*.xcassets",
                "MobileAds/**/*.xib",
                "MobileAds/**/*.storyboard",
                "MobileAds/**/*.{png,jpeg,jpg,pdf}"
            ]
        )
    ]
)
