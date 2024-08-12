//
//  MobocoNativeAds.swift
//  MobileAds
//
//  Created by diep on 12/8/24.
//

import Foundation
import GoogleMobileAds

public struct MobocoNativeAds {
    public var isHighfloor: Bool = false
    public var adsNative: GADNativeAd
    public var isShowed: Bool = false
    
    public init(isHighfloor: Bool, adsNative: GADNativeAd, isShowed: Bool) {
        self.isHighfloor = isHighfloor
        self.adsNative = adsNative
        self.isShowed = isShowed
    }
}
