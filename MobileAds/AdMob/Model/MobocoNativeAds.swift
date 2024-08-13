//
//  MobocoNativeAds.swift
//  MobileAds
//
//  Created by diep on 12/8/24.
//

import Foundation
import GoogleMobileAds

public struct MobocoNativeAds: Hashable {
    public var isHighfloor: Bool = false
    public var adsNative: GADNativeAd
    public var isShowed: Bool = false
    public var adsUnitId: String
    
    public init(isHighfloor: Bool, adsNative: GADNativeAd, isShowed: Bool, adsUnitId: String) {
        self.isHighfloor = isHighfloor
        self.adsNative = adsNative
        self.isShowed = isShowed
        self.adsUnitId = adsUnitId
    }
}
