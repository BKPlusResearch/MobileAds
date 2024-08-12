//
//  ConstantsAds.swift
//  MobileAds
//
//  Created by ANH VU on 08/03/2022.
//

import Foundation
import UIKit
import GoogleMobileAds

public typealias VoidBlockAds = () -> Void
public typealias BoolBlockAds = (Bool) -> Void
public typealias StringBlockAds = (String) -> Void
public typealias IntBlockAds = (Int) -> Void
public typealias LogNativeLoadSuccess = (_ adUnitId: String, _ precision_type: Int, _ revenue_micros: Int, _ ad_source_id: String, _ ad_source_name: String) -> Void
public typealias LogBannerLoadSuccess = (_ adUnitId: String, _ precision_type: Int, _ revenue_micros: Int, _ ad_source_id: String, _ ad_source_name: String) -> Void
public typealias LogInterstitialAdLoadSuccess = (_ adUnitId: String, _ precision_type: Int, _ revenue_micros: Int, _ ad_source_id: String, _ ad_source_name: String) -> Void
public typealias LogRewardedAdLoadSuccess = (_ adUnitId: String, _ precision_type: Int, _ revenue_micros: Int, _ ad_source_id: String, _ ad_source_name: String) -> Void
public typealias LogAdsOpenLoadSuccess = (_ adUnitId: String, _ precision_type: Int, _ revenue_micros: Int, _ ad_source_id: String, _ ad_source_name: String) -> Void

public typealias AdsNativeLoadSuccess = (_ adUnitId: String, _ nativeAd: GADNativeAd) -> Void
public typealias AdsNativeLoadFailure = (_ adUnitId: String, _ error: Error) -> Void

let screenWidthAds = UIScreen.main.bounds.width
let screenHeightAds = UIScreen.main.bounds.height
