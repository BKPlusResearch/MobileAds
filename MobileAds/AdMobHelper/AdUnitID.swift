//
//  Copyright 2024 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

/// Enum defining AdMob Ad Unit IDs for different ad types.
/// Automatically uses test IDs in DEBUG mode and production IDs in RELEASE mode.
/// Each case returns a string directly based on the build configuration.
public enum AdUnitID: String {
    case appOpen
    case appResume
    case banner
    case interstitial
    case rewardedVideo
    case nativeAdvanced

    /// Returns the Ad Unit ID string directly.
    /// Returns test IDs in DEBUG mode, production IDs in RELEASE mode.
    public var rawValue: String {
#if DEBUG
        return testID
#else
        return productionID
#endif
    }

    /// Test Ad Unit ID for the ad type.
    private var testID: String {
        switch self {
        case .appOpen:
            return "ca-app-pub-3940256099942544/5575463023"
        case .appResume:
            return "ca-app-pub-3940256099942544/5575463023"
        case .banner:
            return "ca-app-pub-3940256099942544/2435281174"
        case .interstitial:
            return "ca-app-pub-3940256099942544/4411468910"
        case .rewardedVideo:
            return "ca-app-pub-3940256099942544/1712485313"
        case .nativeAdvanced:
            return "ca-app-pub-3940256099942544/3986624511"
        }
    }

    /// Production Ad Unit ID for the ad type.
    /// TODO: Replace these with your actual production Ad Unit IDs from AdMob.
    private var productionID: String {
        switch self {
        case .appOpen:
            return "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
        case .appResume:
            return "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
        case .banner:
            return "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
        case .interstitial:
            return "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
        case .rewardedVideo:
            return "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
        case .nativeAdvanced:
            return "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
        }
    }
}

