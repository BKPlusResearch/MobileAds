//
//  Unifiedself.swift
//  EasyVPN
//
//  Created by ANH VU on 03/12/2021.
//


import UIKit
import GoogleMobileAds
import SkeletonView

protocol NativeAdProtocol {
    var adUnitID: String? {get set}

    func bindingData(nativeAd: GADNativeAd)
}

class UnifiedNativeAdView_2: GADNativeAdView, NativeAdProtocol {

    @IBOutlet weak var lblAds: UILabel!
    @IBOutlet weak var adsView: UIView!
    @IBOutlet weak var bannerImageView: UIImageView!
    @IBOutlet weak var lblRateCount: UILabel!
    @IBOutlet weak var starRatingImageView: UIImageView!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var infoImageView: UIImageView!
    @IBOutlet weak var adsContentStackView: UIStackView!

    let (viewBackgroundColor, titleColor, vertiserColor, contenColor, actionColor, backgroundAction) = AdMobManager.shared.adsNativeColor.colors
    var adUnitID: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = viewBackgroundColor
        if backgroundAction.count > 1 {
            self.callToActionView?.gradient(startColor: backgroundAction.first!, endColor: backgroundAction.last!, cornerRadius: 20)
            adsView.gradient(startColor: backgroundAction.first!, endColor: backgroundAction.last!, cornerRadius: 2)
        } else {
            (self.callToActionView as? UIButton)?.backgroundColor = backgroundAction.first
            self.callToActionView?.layer.cornerRadius = 20
        }
        (self.callToActionView as? UIButton)?.setTitleColor(actionColor, for: .normal)
        (self.bodyView as? UILabel)?.textColor = contenColor
        (advertiserView as? UILabel)?.textColor = vertiserColor
        lblRateCount.textColor = contenColor
        (priceView as? UILabel)?.textColor = contenColor
        (self.storeView as? UILabel)?.textColor = contenColor
        (self.headlineView as? UILabel)?.textColor = titleColor
        (self.headlineView as? UILabel)?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        lblAds.textColor = AdMobManager.shared.adNativeAdsLabelColor
        self.backgroundColor = viewBackgroundColor
        layer.borderWidth = AdMobManager.shared.adsNativeBorderWidth
        layer.borderColor = AdMobManager.shared.adsNativeBorderColor.cgColor
        layer.cornerRadius = AdMobManager.shared.adsNativeCornerRadius
        clipsToBounds = true

        infoImageView.isHidden = true
        adsContentStackView.showAnimatedSkeleton()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    func bindingData(nativeAd: GADNativeAd) {
        self.hideSkeleton()
        (self.headlineView as? UILabel)?.text = nativeAd.headline
        self.mediaView?.mediaContent = nativeAd.mediaContent
        self.iconView?.isHidden = nativeAd.icon == nil

        let mediaContent = nativeAd.mediaContent
        if mediaContent.hasVideoContent {
            //videoStatusLabel.text = "Ad contains a video asset."
        } else {
            //videoStatusLabel.text = "Ad does not contain a video."
        }

        (self.bodyView as? UILabel)?.text = nativeAd.body
        self.bodyView?.isHidden = nativeAd.body == nil
//        bannerImageView.image = nativeAd.images?.first?.image
        (self.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        self.callToActionView?.isHidden = nativeAd.callToAction == nil


        (self.iconView as? UIImageView)?.image = nativeAd.icon?.image
        self.iconView?.isHidden = nativeAd.icon == nil

        if let starRating = nativeAd.starRating, starRating != 0 {
            starRatingImageView.image = imageOfStars(from: starRating)
            lblRateCount.text = "\(starRating)"
            lblRateCount.isHidden = false
            starRatingImageView.isHidden = false
        } else {
            lblRateCount.isHidden = true
            starRatingImageView.isHidden = true
        }
        (self.storeView as? UILabel)?.text = nativeAd.store
        self.storeView?.isHidden = nativeAd.store == nil

        priceLabel.isHidden = nativeAd.price == nil
        priceLabel.text = nativeAd.price
        (self.advertiserView as? UILabel)?.text = nativeAd.advertiser
        self.advertiserView?.isHidden = nativeAd.advertiser == nil
        infoImageView.isHidden = false
        self.nativeAd = nativeAd
    }
}
