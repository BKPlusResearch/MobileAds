# Audit: PrivacyInfo.xcprivacy coverage — MobileAds 2.0.4

Date: 2026-09-19 · Branch: `new-MobileAds` · Commit: `5674eae`
Scope: pod `MobileAds` + toàn bộ 38 pod trong `Pods/`

## Kết luận

**Không cần tạo `PrivacyInfo.xcprivacy` — cả ở pod `MobileAds` lẫn ở host app.**

Hai Required Reason API mà `MobileAds` gọi đều đã được khai bởi dependency bắt buộc
(`Google-Mobile-Ads-SDK`), nên privacy report tổng hợp của app đã phủ đủ. Việc host app
submit trót lọt hiện nay là hệ quả của coverage này, không phải may mắn.

Rủi ro thực tế nằm ở hướng ngược lại: tạo manifest **sai** (bật `NSPrivacyTracking=true`
kèm domain quảng cáo) sẽ khiến iOS chặn ad traffic trên user từ chối ATT.

## 1. MobileAds gọi Required Reason API nào

| API | Category | Reason phù hợp | Call site |
|---|---|---|---|
| `UserDefaults.standard` | `UserDefaults` | `CA92.1` | `MobileAds/IAP/EntitlementService.swift:88`, `:496` |
| `ProcessInfo.processInfo.systemUptime` | `SystemBootTime` | `35F9.1` | `MobileAds/IAP/EntitlementService.swift:189`, `:259` |

Không dùng: `FileTimestamp`, `DiskSpace`, `ActiveKeyboards`.

IDFA / ATT: `MobileAds/AdMobHelper/AdMobHelper.swift:241,251,259`,
`MobileAds/TikTokManager/TikTokManager.swift:134-135`.
Ad revenue fan-out (Firebase + TikTok + Facebook): `MobileAds/AdRevenue/AdRevenueManager.swift:36-51`.

Pod không tự mở network connection nào — mọi request là do vendor SDK thực hiện.

## 2. Ai đã khai 2 category MobileAds cần

**`SystemBootTime`** (3 pod):

- `Google-Mobile-Ads-SDK` → `35F9.1` ← dependency bắt buộc, luôn có mặt
- `VungleAds` → `35F9.1`
- `FBAudienceNetwork` → `35F9.1`

**`UserDefaults`** (13 pod): `Google-Mobile-Ads-SDK` `CA92.1`, `GoogleUserMessagingPlatform`
`CA92.1`, `AppLovinSDK` `CA92.1`, `MintegralAdSDK` `CA92.1`, `Ads-Global`(Pangle) `CA92.1`,
`VungleAds` `CA92.1`, `TikTokBusinessSDK` `CA92.1`, `FBSDKCoreKit` `CA92.1`,
`FBSDKCoreKit_Basics` `CA92.1`, `FBAEMKit` `CA92.1`, `FBAudienceNetwork` `CA92.1`,
`FirebaseCore` `CA92.1`, `FirebaseCrashlytics` `CA92.1`, `FirebaseCoreInternal` `1C8F.1`,
`FirebaseRemoteConfig` `1C8F.1`, `GoogleUtilities` `C56D.1`.

Coverage đến từ `Google-Mobile-Ads-SDK` là quan trọng nhất: nó là hard dependency của pod
(`MobileAds.podspec:170`), không thể vắng mặt, và khai cả hai category.

## 3. NSPrivacyTracking / TrackingDomains — phần ảnh hưởng runtime

Đây là trường duy nhất trong manifest có tác dụng thật lúc chạy: khi `NSPrivacyTracking=true`
và có domain liệt kê, iOS **chặn kết nối tới domain đó** nếu user deny ATT.

| Pod | NSPrivacyTracking | NSPrivacyTrackingDomains |
|---|---|---|
| `FBAudienceNetwork` | `true` | `ep1.facebook.com`, `ep6.facebook.com` |
| `FBSDKCoreKit` | `true` | `ep1.facebook.com` |
| Tất cả pod còn lại | `false` hoặc không khai | *(rỗng)* |

Google, AppLovin, Mintegral, Pangle, Vungle, TikTok đều **không** khai domain — tức không
tự chặn traffic của mình. Chỉ Meta dùng cơ chế này.

**Hệ quả:** nếu host app tạo manifest và liệt kê domain ad network vào
`NSPrivacyTrackingDomains`, app sẽ tự chặn ad request của chính mình trên toàn bộ user
deny ATT. Không tạo file thì an toàn; tạo sai mới nguy hiểm.

## 4. Dump đầy đủ — 25 pod có manifest (42 file)

Ký hiệu: `L`=Linked, `T`=Tracking. Tên category/datatype đã bỏ prefix `NSPrivacy*`.

### Ads-Global — PAGAdSDK (Pangle) · 3 file
- tracking: *(không khai)* · domains: —
- API: `FileTimestamp`→`C617.1` · `DiskSpace`→`7D9E.1`,`E174.1` · `UserDefaults`→`CA92.1`
- Collected: `UserID` L=1 T=1 (AppFunctionality, ThirdPartyAdvertising) · `DeviceID` L=1 T=1 (ThirdPartyAdvertising) · `AdvertisingData` L=1 T=1 (Analytics, ThirdPartyAdvertising) · `CrashData` L=1 T=0 · `PerformanceData` L=1 T=0 · `CoarseLocation` L=1 T=0 · `OtherDataTypes` L=1 T=0

### Ads-Global — TikTokBusinessSDK (bundled) · 2 file
- tracking: *(không khai)* · domains: —
- API: `UserDefaults`→`CA92.1`
- Collected: 1 entry **rỗng** (datatype = `""`) — manifest lỗi, xem §6

### AppLovinSDK · 2 file
- tracking: *(không khai)* · domains: —
- API: `UserDefaults`→`CA92.1`
- Collected: *(none)*

### FBAEMKit · 3 file
- tracking: `false` · domains: —
- API: `UserDefaults`→`CA92.1`
- Collected: *(none)*

### FBAudienceNetwork · 2 file
- tracking: **`true`** · domains: **`ep1.facebook.com`, `ep6.facebook.com`**
- API: `UserDefaults`→`CA92.1` · `SystemBootTime`→`35F9.1` · `FileTimestamp`→`C617.1`
- Collected: `CrashData` L=0 T=0 · `OtherDiagnosticData` L=0 T=0 · `AdvertisingData` L=1 T=1 (ThirdPartyAdvertising, Analytics) · `DeviceID` L=1 T=1 (ThirdPartyAdvertising)

### FBSDKCoreKit · 3 file
- tracking: **`true`** · domains: **`ep1.facebook.com`**
- API: `UserDefaults`→`CA92.1`
- Collected: `OtherDataTypes` L=0 T=0 · `CrashData` L=0 T=0 · `DeviceID` L=1 T=1 (ThirdPartyAdvertising, AppFunctionality, Analytics)

### FBSDKCoreKit_Basics · 3 file
- tracking: `false` · domains: —
- API: `UserDefaults`→`CA92.1`
- Collected: `OtherDataTypes` L=0 T=0 (Analytics)

### FirebaseABTesting · 1 file
- tracking: `false` · API: *(none)* · Collected: *(none)*

### FirebaseCore · 1 file
- tracking: `false` · API: `UserDefaults`→`CA92.1` · Collected: *(none)*

### FirebaseCoreExtension · 1 file
- tracking: `false` · API: *(none)* · Collected: *(none)*

### FirebaseCoreInternal · 1 file
- tracking: `false` · API: `UserDefaults`→`1C8F.1` · Collected: *(none)*

### FirebaseCrashlytics · 1 file
- tracking: `false` · API: `UserDefaults`→`CA92.1`
- Collected: `CrashData` L=0 T=0 · `OtherDiagnosticData` L=0 T=0 (AppFunctionality)

### FirebaseInstallations · 1 file
- tracking: `false` · API: *(none)* · Collected: `OtherDiagnosticData` L=0 T=0 (Analytics)

### FirebaseRemoteConfig · 1 file
- tracking: `false` · API: `UserDefaults`→`1C8F.1` · Collected: `OtherDiagnosticData` L=0 T=0

### Google-Mobile-Ads-SDK · 2 file  ← nguồn coverage chính
- tracking: *(không khai)* · domains: —
- API: **`SystemBootTime`→`35F9.1`** · **`UserDefaults`→`CA92.1`** · `DiskSpace`→`E174.1`
- Collected: `OtherDiagnosticData` L=0 T=0 · `CoarseLocation` L=1 T=0 · `PerformanceData` L=0 T=0 · `CrashData` L=0 T=0 · `AdvertisingData` L=1 T=0 · `ProductInteraction` L=1 T=0 · `DeviceID` L=1 **T=1** (ThirdPartyAdvertising, Analytics, DeveloperAdvertising)

### GoogleDataTransport · 1 file
- tracking: `false` · API: *(none)* · Collected: `OtherDiagnosticData` L=0 T=0

### GoogleUserMessagingPlatform · 2 file
- tracking: *(không khai)* · API: `UserDefaults`→`CA92.1`
- Collected: `CoarseLocation` L=0 T=0 · `PerformanceData` L=0 T=0 · `ProductInteraction` L=0 T=0 (đều AppFunctionality)

### GoogleUtilities · 1 file
- tracking: `false` · API: `FileTimestamp`→`C617.1` · `UserDefaults`→`C56D.1`
- Collected: *(none)*

### MintegralAdSDK · 3 file
- tracking: *(không khai)* · API: `DiskSpace`→`E174.1` · `FileTimestamp`→`C617.1` · `UserDefaults`→`CA92.1`
- Collected: *(none)*

### PromisesObjC / PromisesSwift / SnapKit / Toast-Swift / nanopb · 1 file mỗi pod
- tracking: `false` · API: *(none)* · Collected: *(none)*

### TikTokBusinessSDK · 1 file
- tracking: *(không khai)* · API: `UserDefaults`→`CA92.1`
- Collected: 1 entry **rỗng** — manifest lỗi, xem §6

### VungleAds · 2 file
- tracking: *(không khai)* · domains: —
- API: `SystemBootTime`→`35F9.1` · `FileTimestamp`→`C617.1` · `DiskSpace`→`E174.1` · `UserDefaults`→`CA92.1`
- Collected: *(none)*

## 5. 13 pod KHÔNG có manifest

| Pod | Dạng | Đánh giá |
|---|---|---|
| `Firebase` | umbrella, không có source | không cần |
| `FirebaseSessions` | source pod | upstream thiếu |
| `FirebaseSharedSwift` | source pod | upstream thiếu |
| `FirebaseRemoteConfigInterop` | interop shim | không cần |
| `FirebaseAnalytics` | static xcframework | **đáng lưu ý** — Firebase nằm trong danh sách commonly-used SDK của Apple |
| `GoogleAppMeasurement` | static xcframework | **đáng lưu ý** — cùng lý do |
| `GoogleAdsOnDeviceConversion` | static xcframework | upstream thiếu |
| `GoogleMobileAdsMediationAppLovin` | adapter shim | SDK gốc `AppLovinSDK` đã có |
| `GoogleMobileAdsMediationFacebook` | adapter shim | SDK gốc `FBAudienceNetwork` đã có |
| `GoogleMobileAdsMediationMintegral` | adapter shim | SDK gốc `MintegralAdSDK` đã có |
| `GoogleMobileAdsMediationPangle` | adapter shim | SDK gốc `Ads-Global` đã có |
| `GoogleMobileAdsMediationVungle` | adapter shim | SDK gốc `VungleAds` đã có |
| `SkeletonView` | source pod, UI thuần | không đụng required-reason API |

5 adapter shim là lớp cầu nối mỏng giữa GMA và network SDK; SDK gốc bên dưới đều có manifest
→ rủi ro thấp. `FirebaseAnalytics` / `GoogleAppMeasurement` thiếu là vấn đề upstream của
Google, không sửa được từ phía mình, chỉ theo dõi và bump version.

## 6. Bất thường phát hiện được

`TikTokBusinessSDK` (cả bản standalone lẫn bản bundled trong `Ads-Global`) khai một entry
`NSPrivacyCollectedDataTypes` với `NSPrivacyCollectedDataType` = chuỗi rỗng, purposes rỗng.
Manifest hợp lệ về mặt plist nhưng vô nghĩa về mặt nội dung. Không gây lỗi submit, nhưng
nghĩa là TikTok thực tế **không khai** data type nào — trong khi SDK này nhận ad revenue +
IDFA từ `AdRevenueManager`. Nếu App Store Connect hỏi về data collection của TikTok, không
thể dựa vào manifest này; phải tự khai thủ công trong nutrition labels.

## 7. Podspec — nếu sau này vẫn muốn thêm manifest

`MobileAds.podspec:162` đặt `static_framework = true`, và `:124` glob resources chỉ nhận
`{xcassets,pdf,png,jpeg,jpg,storyboard,xib}` — không có `xcprivacy`. Thêm file vào thư mục
source sẽ **không** được ship. Cách đúng (pattern mà Firebase/SnapKit/TikTok dùng, thấy trong
`Pods/Target Support Files/*/ResourceBundle-*_Privacy-*-Info.plist`):

```ruby
spec.resource_bundles = { 'MobileAds_Privacy' => ['MobileAds/PrivacyInfo.xcprivacy'] }
```

Nếu làm, **để `NSPrivacyTracking = false` và không khai `NSPrivacyTrackingDomains`** — xem §3.

## 8. Cái thật sự ảnh hưởng doanh thu ads (không phải file này)

1. **ATT prompt** — quyết định có IDFA, ảnh hưởng trực tiếp eCPM. Pod đã xử lý.
2. **UMP / GDPR consent** — quyết định personalized ad ở EU. Pod đã xử lý qua `configAds`.
3. **App Privacy nutrition labels trên App Store Connect** — bắt buộc, Apple thực sự chặn
   submit nếu thiếu. Khai thủ công trên web, **không** liên quan file `.xcprivacy`.

## 9. Cách tái lập

```bash
# pod nào có / không có manifest
for d in Pods/*/; do n=$(basename "$d"); c=$(find "$d" -name "*.xcprivacy" | wc -l); echo "$c $n"; done

# nội dung một manifest
plutil -convert xml1 -o - <path>/PrivacyInfo.xcprivacy

# ai khai SystemBootTime
for f in $(find Pods -name "*.xcprivacy"); do
  plutil -convert xml1 -o - "$f" | grep -q SystemBootTime && echo "$f"
done

# required-reason API trong source pod
grep -rn "UserDefaults\|systemUptime\|mach_absolute_time\|modificationDate\|creationDate\|\
volumeAvailableCapacity\|statfs\|activeInputModes" --include="*.swift" MobileAds/
```

## Câu hỏi chưa giải quyết

1. `docs/project-roadmap.md:26` ghi item P1 "verify PrivacyInfo.xcprivacy coverage" như thể
   đang thiếu. Có sửa thành ghi chú đã-verify kèm lý do không? Để nguyên thì lần sau dễ có
   người tạo file thừa, và nếu copy nhầm pattern `NSPrivacyTrackingDomains` của Meta thì
   thành tự chặn ads.
2. Cơ chế chính xác Apple gom manifest của static framework vào privacy report: mình verify
   được **nội dung** từng manifest, còn bước gom thì suy luận từ việc host app submit trót
   lọt. Đủ để ra quyết định, nhưng chưa phải bằng chứng trực tiếp.
3. Có muốn theo dõi `FirebaseAnalytics` / `GoogleAppMeasurement` để bump khi Google thêm
   manifest không?
