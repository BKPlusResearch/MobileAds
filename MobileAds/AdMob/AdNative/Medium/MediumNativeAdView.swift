//
//  MediumNativeAdView.swift
//  MobileAds
//
//  Created by Quang Ly Hoang on 25/02/2022.
//

import UIKit
import GoogleMobileAds

class MediumNativeAdView: GADNativeAdView, NativeAdProtocol {

    @IBOutlet weak var lblAds: UILabel!
    @IBOutlet weak var adsView: UIView!
    @IBOutlet weak var actionButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var lblRateCount: UILabel!
    @IBOutlet weak var starRatingImageView: UIImageView!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var loadingLabel: UILabel!
    let (viewBackgroundColor, titleColor, vertiserColor, contenColor, actionColor, backgroundAction) = AdMobManager.shared.adsNativeColor.colors
    var adUnitID: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = viewBackgroundColor
        loadingLabel.text = AdMobManager.shared.loadingAdsString
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        actionButtonHeightConstraint.constant = AdMobManager.shared.adsNativeMediumHeightButton
    }

    func bindingData(nativeAd: GADNativeAd) {
        hideSkeleton()
        stopSkeletonAnimation()
        (headlineView as? UILabel)?.text = nativeAd.headline
        (callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        callToActionView?.isHidden = nativeAd.callToAction == nil

        (iconView as? UIImageView)?.image = nativeAd.icon?.image
        iconView?.isHidden = nativeAd.icon == nil

        mediaView?.isHidden = true

        if let star = nativeAd.starRating, let image = imageOfStars(from: star) {
            starRatingImageView.image = image
            lblRateCount.text = "\(star)"
            starRatingImageView.isHidden = false
            lblRateCount.isHidden = false
        } else {
            starRatingImageView.isHidden = true
            lblRateCount.isHidden = true
        }

        (bodyView as? UILabel)?.text = nativeAd.body
        bodyView?.isHidden = nativeAd.body == nil

        priceLabel.text = nativeAd.price
        priceLabel.isHidden = nativeAd.price == nil

        (advertiserView as? UILabel)?.text = nativeAd.advertiser
        advertiserView?.isHidden = nativeAd.advertiser == nil

        (self.callToActionView as? UIButton)?.setTitleColor(actionColor, for: .normal)
        if backgroundAction.count > 1 {
            self.callToActionView?.gradient(startColor: backgroundAction.first!, endColor: backgroundAction.last!, cornerRadius: AdMobManager.shared.adsNativeCornerRadiusButton)
            adsView.gradient(startColor: backgroundAction.first!, endColor: backgroundAction.last!, cornerRadius: 2)
        } else {
            self.callToActionView?.layer.backgroundColor = backgroundAction.first?.cgColor
            self.callToActionView?.layer.cornerRadius = AdMobManager.shared.adsNativeCornerRadiusButton
        }
        (self.bodyView as? UILabel)?.textColor = contenColor
        (self.advertiserView as? UILabel)?.textColor = vertiserColor
        lblRateCount.textColor = contenColor
        (self.headlineView as? UILabel)?.textColor = titleColor
        (priceView as? UILabel)?.textColor = contenColor
        lblAds.textColor = AdMobManager.shared.adNativeAdsLabelColor
        self.backgroundColor = viewBackgroundColor
        layer.borderWidth = AdMobManager.shared.adsNativeBorderWidth
        layer.borderColor = AdMobManager.shared.adsNativeBorderColor.cgColor
        layer.cornerRadius = AdMobManager.shared.adsNativeCornerRadius
        clipsToBounds = true

        self.nativeAd = nativeAd
    }

    func hideLoadingView() {
        loadingView.isHidden = true
    }
}
