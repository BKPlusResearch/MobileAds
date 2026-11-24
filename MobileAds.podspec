#
#  Be sure to run `pod spec lint MobileAds.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  #

  spec.name         = "MobileAds"
  spec.version      = "2.2.2"
  spec.summary      = "Google Mobile Ads + entitlements-first StoreKit 2 IAP for iOS; native small/medium templates with shared NativeAdConfiguration theming"

  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  spec.description  = <<-DESC
  MobileAds is a Swift framework that supports all base display ad types from Google Mobile Ads SDK and In-App Purchase management, making it convenient to configure and use.

  **2.0.4 drops the IronSource and Unity mediation adapters.** The bundled set is now AppLovin, Mintegral, Pangle, Vungle/Liftoff and Facebook/Meta. Apps that still monetize through IronSource or Unity must add `GoogleMobileAdsMediationIronSource` / `GoogleMobileAdsMediationUnity` to their own Podfile.

  **2.0.1 removes the Adjust SDK integration.** `ADJustManager` is now `AdRevenueManager`, `ADJAdType` is now `AdType`, and `AppADJustConfig` is gone — source-breaking for apps that called them. Ad revenue still fans out to Firebase Analytics, TikTok Business SDK and Facebook SDK.

  **2.0.0 was a breaking release.** The legacy `IAPService` layer was removed. `EntitlementService` is now the only IAP layer. Apps on 1.x must migrate; see "Upgrading from 1.x to 2.0" in the README.

  Features include:
  - Native **small** compact row (icon/media, headline, body, CTA) with `mainStackView`; styling via same `NativeAdConfiguration` as medium
  - Singleton-based configuration for global native ad styling
  - Gradient support for call-to-action buttons
  - Automatic consent management integration
  - Simplified API for banner, interstitial, rewarded, and native ads
  - Entitlements-first IAP: entitlement is derived from `Transaction.currentEntitlements` on every check, never cached, so reinstalls, device changes, refunds and Family Sharing are handled by StoreKit
  - `onUnfinished` delivery hook so consumable purchases are credited before a transaction is finished
  - Support for async/await patterns
                   DESC

  spec.homepage     = "https://github.com/BKPlusResearch/MobileAds"
  # spec.screenshots  = "www.example.com/screenshots_1.gif", "www.example.com/screenshots_2.gif"


  # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Licensing your code is important. See https://choosealicense.com for more info.
  #  CocoaPods will detect a license file if there is a named LICENSE*
  #  Popular ones are 'MIT', 'BSD' and 'Apache License, Version 2.0'.
  #

  # spec.license      = "MIT"
  spec.license      = { :type => "MIT", :file => "FILE_LICENSE" }


  # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the authors of the library, with email addresses. Email addresses
  #  of the authors are extracted from the SCM log. E.g. $ git log. CocoaPods also
  #  accepts just a name if you'd rather not provide an email address.
  #
  #  Specify a social_media_url where others can refer to, for example a twitter
  #  profile URL.
  #

  spec.author             = { "vunk" => "frankie@bkplussoft.com" }
  # Or just: spec.author    = "vunk"
  # spec.authors            = { "vunk" => "vunk@apero.vn" }
  # spec.social_media_url   = "https://twitter.com/vunk"

  # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If this Pod runs only on iOS or OS X, then specify the platform and
  #  the deployment target. You can optionally include the target after the platform.
  #

  # spec.platform     = :ios
  spec.platform     = :ios, "15.0"

  #  When using multiple platforms
  # spec.ios.deployment_target = "5.0"
  # spec.osx.deployment_target = "10.7"
  # spec.watchos.deployment_target = "2.0"
  # spec.tvos.deployment_target = "9.0"


  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the location from where the source should be retrieved.
  #  Supports git, hg, bzr, svn and HTTP.
  #

  spec.source       = { :git => "https://github.com/BKPlusResearch/MobileAds.git", :tag => "#{spec.version}" }
  spec.frameworks   = "Foundation", "UIKit", "SwiftUI", "Photos", "AVFoundation"
  spec.swift_version = '5.5'
# spec.source       = { :git => "https://github.com/AperoVN-iOS/MobileAds.git", :tag => "#{spec.version}" }

  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  CocoaPods is smart about how it includes source code. For source files
  #  giving a folder will include any swift, h, m, mm, c & cpp files.
  #  For header files it will include any header in the folder.
  #  Not including the public_header_files will make all headers public.
  #
  # spec.source_files  = "MobileAds", "MobileAds/**/*.{h,swift,xib,modulemap}"
  # spec.resources     = "MobileAds/**/*.xcassets"

  # spec.subspec  'AllResources' do |subspec|
  #   subspec.resource_bundles = {
  #     "MobileAds" => [
  #       "MobileAds/**/*{xib,xcassets,png}"
  #     ]
  #   }
  # end
  # s.resources  = "ImageDemoLib/**/*.xcassets"
# spec.resources     = "MobileAds/**/*.{png,jpeg,jpg,storyboard,xib,xcassets,plist}"
  # spec.public_header_files = "Classes/**/*.h"


  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  A list of resources included with the Pod. These are copied into the
  #  target bundle with a build phase script. Anything else will be cleaned.
  #  You can preserve files from being cleaned, please don't preserve
  #  non-essential files like tests, examples and documentation.
  #

  # spec.resource  = "MobileAds/**/*.xcassets"
  # spec.resources = "Resources/*.png"

  # spec.preserve_paths = "FilesToSave", "MoreFilesToSave"


  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Link your library with frameworks, or libraries. Libraries do not include
  #  the lib prefix of their name.
  #

  # spec.framework  = "SomeFramework"
  # spec.frameworks = "SomeFramework", "AnotherFramework"

  # spec.library   = "iconv"
  # spec.libraries = "iconv", "xml2"


  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If your library depends on compiler flags you can set them in the xcconfig hash
  #  where they will only apply to your library. If you depend on other Podspecs
  #  you can include multiple dependencies to ensure it works.

  spec.static_framework = true
  spec.requires_arc = true

  # spec.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }


  # Subspecs. `pod 'MobileAds'` installs Core only, exactly what it installed before
  # subspecs existed. Add an attribution SDK by naming its subspec:
  #   pod 'MobileAds', :git => ..., :tag => ..., :subspecs => ['Core', 'AppsFlyer', 'Qonversion']
  # Every subspec compiles into the single `MobileAds` module.
  spec.default_subspecs = 'Core'

  spec.subspec 'Core' do |core|
    core.source_files  = "MobileAds", "MobileAds/**/*.{h,swift,modulemap}"
    core.exclude_files = "MobileAds/Exclude", "MobileAds/AppsFlyer/**/*", "MobileAds/Qonversion/**/*"
    core.resources     = 'MobileAds/**/*.{xcassets,pdf,png,jpeg,jpg,storyboard,xib}'
    core.dependency 'Firebase', '~> 12.18.0'
    core.dependency 'FirebaseCrashlytics', '~> 12.18.0'
    core.dependency 'FirebaseAnalytics', '~> 12.18.0'
    core.dependency 'Firebase/RemoteConfig', '~> 12.18.0'
    core.dependency "Google-Mobile-Ads-SDK", '~> 13.8.0'
    core.dependency "GoogleUserMessagingPlatform", '~> 3.1.0'
    core.dependency "SnapKit", '~> 5.7.1'
    core.dependency "SkeletonView", '~> 1.30.4'
    core.dependency 'Toast-Swift', '~> 5.1.1'
    core.dependency 'TikTokBusinessSDK', '~> 1.7.1'
    core.dependency 'FBSDKCoreKit', '~> 18.1.0'
    core.dependency 'GoogleMobileAdsMediationAppLovin', '~> 13.6.3.0'
    core.dependency 'GoogleMobileAdsMediationVungle', '~> 7.7.6.0'
    core.dependency 'GoogleMobileAdsMediationFacebook', '~> 6.22.0.0'
    core.dependency 'GoogleMobileAdsMediationMintegral', '~> 8.1.6.0'
    core.dependency 'GoogleMobileAdsMediationPangle', '~> 8.2.1.0.0'
  end

  # Install attribution + `af_purchase` for purchases made through EntitlementService.
  spec.subspec 'AppsFlyer' do |af|
    af.source_files = "MobileAds/AppsFlyer/**/*.swift"
    af.dependency 'MobileAds/Core'
    af.dependency 'AppsFlyerFramework', '~> 7.0.4'
  end

  # Subscription analytics in `.analytics` mode; EntitlementService keeps owning transactions.
  spec.subspec 'Qonversion' do |qon|
    qon.source_files = "MobileAds/Qonversion/**/*.swift"
    qon.dependency 'MobileAds/Core'
    qon.dependency 'Qonversion', '~> 6.18.0'
  end
end
