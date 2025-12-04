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

/// A type that can provide a concrete AdMob ad unit ID string.
/// 
/// The framework only needs the final string to pass to Google Mobile Ads SDK.
/// Projects integrating this framework are expected to define their own enums
/// or structs (for example, `enum AppAdUnitID`) that conform to this protocol
/// and decide how to manage test vs production IDs.
public protocol AdUnitIdentifiable {
    /// The resolved ad unit ID string used when requesting ads.
    var adUnitIDString: String { get }
}

