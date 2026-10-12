//
//  NativeAdWeakMap.swift
//  MobileAds
//

import Foundation
import GoogleMobileAds

/// A string tag attached to a `NativeAd` for as long as the ad lives, without keeping it alive.
///
/// The helpers tag each ad with its unit ID (metrics) and cache key (cleared on impression), and
/// used to hold those tags in `[NativeAd: String]`. A dictionary key is a strong reference, and
/// the entry was only removed on impression — so every ad that left the screen before its
/// impression stayed resident for the life of the process, with its web view and media. A grid
/// that reloads a native each time a slot scrolls back in leaked one ad per reload: measured,
/// 181 live ads and 702 MB after three passes over one screen.
///
/// Weak keys tie each entry's life to the ad's: once the ad view that owns it goes, so does the
/// tag. Accessed on the main thread only, like the dictionaries it replaces.
final class NativeAdWeakMap: @unchecked Sendable {
    private let table = NSMapTable<NativeAd, NSString>.weakToStrongObjects()

    subscript(nativeAd: NativeAd) -> String? {
        get { table.object(forKey: nativeAd) as String? }
        set {
            if let newValue {
                table.setObject(newValue as NSString, forKey: nativeAd)
            } else {
                table.removeObject(forKey: nativeAd)
            }
        }
    }

    func removeValue(forKey nativeAd: NativeAd) {
        table.removeObject(forKey: nativeAd)
    }

    func removeAll() {
        table.removeAllObjects()
    }
}
