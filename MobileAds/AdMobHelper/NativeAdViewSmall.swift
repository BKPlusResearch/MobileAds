//
//  NativeAdViewSmall.swift
//  AppTheme
//
//  Created by Auto on 2024.
//

import UIKit
@preconcurrency import GoogleMobileAds

/// Custom view class for `NativeAdViewSmall.xib`
/// Compact row: icon/media, headline + body, trailing CTA. Styling is driven by `NativeAdConfiguration` the same way as `NativeAdViewMedium`.
public class NativeAdViewSmall: NativeAdView {

    // MARK: - IBOutlets

    @IBOutlet weak var boundView: UIView!
    @IBOutlet weak var adsLabelView: UIView!
    /// Horizontal stack (icon | text | CTA); exposed like `NativeAdViewMedium.mainStackView` for host tweaks.
    @IBOutlet weak var mainStackView: UIStackView!
    /// Wraps `MediaView` + icon fallback; hidden when neither media nor icon applies.
    @IBOutlet weak var mediaContainerView: UIView!

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    // MARK: - Factory Method

    static func loadFromXib() -> NativeAdViewSmall? {
        let bundle = Bundle(for: NativeAdViewSmall.self)
        return UINib(nibName: "NativeAdViewSmall", bundle: bundle)
            .instantiate(withOwner: nil, options: nil)
            .first as? NativeAdViewSmall
    }

    // MARK: - Configuration

    private func setupUI() {
        boundView.cornerRadius = 8
        boundView.clipsToBounds = true

        // Small template: "Ad" sits top-leading — round all corners (medium uses bottom-trailing mask only).
        adsLabelView.cornerRadius = 8
        adsLabelView.layer.maskedCorners = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
        ]
        adsLabelView.layer.masksToBounds = true

        if let mediaContainerView = mediaContainerView {
            mediaContainerView.cornerRadius = 8
            mediaContainerView.clipsToBounds = true
        }

        if let mediaView = mediaView {
            mediaView.layer.cornerRadius = 8
            mediaView.clipsToBounds = true
        }

        if let iconView = iconView as? UIImageView {
            iconView.layer.cornerRadius = 8
            iconView.clipsToBounds = true
        }

        if let ads = adsLabelView {
            boundView.bringSubviewToFront(ads)
        }

        setupTextViews()
        setupCallToActionGradient()
    }

    /// Same pattern as `NativeAdViewMedium.setupTextViews` (defaults → `NativeAdConfiguration.shared`).
    private func setupTextViews() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let config = NativeAdConfiguration.shared

            if let headlineView = self.headlineView as? UILabel {
                headlineView.font = config.headlineFont ?? UIFont.systemFont(ofSize: 15, weight: .semibold)
                headlineView.textColor = config.headlineTextColor ?? .label
            }

            if let bodyView = self.bodyView as? UILabel {
                bodyView.font = config.bodyFont ?? UIFont.systemFont(ofSize: 14, weight: .regular)
                bodyView.textColor = config.bodyTextColor ?? .secondaryLabel
            }

            if let callToActionView = self.callToActionView as? UIButton {
                callToActionView.titleLabel?.font = config.callToActionFont ?? UIFont.systemFont(ofSize: 12, weight: .bold)
                callToActionView.titleLabel?.adjustsFontSizeToFitWidth = true
                callToActionView.titleLabel?.minimumScaleFactor = 0.85
                callToActionView.cornerRadius = 16
                callToActionView.setTitleColor(config.callToActionTextColor ?? .white, for: .normal)
            }
        }
    }

    /// Same pattern as `NativeAdViewMedium.setupCallToActionGradient`.
    private func setupCallToActionGradient() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let callToActionView = self.callToActionView as? UIButton else { return }

            let config = NativeAdConfiguration.shared

            callToActionView.cornerRadius = 16

            callToActionView.layer.sublayers?.forEach { layer in
                if layer is CAGradientLayer {
                    layer.removeFromSuperlayer()
                }
            }

            if config.useGradientForCallToAction,
               let startColor = config.callToActionGradientStartColor,
               let endColor = config.callToActionGradientEndColor {
                let gradientLayer = CAGradientLayer()
                gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
                gradientLayer.startPoint = config.callToActionGradientStartPoint
                gradientLayer.endPoint = config.callToActionGradientEndPoint
                gradientLayer.frame = callToActionView.bounds
                gradientLayer.cornerRadius = 12
                callToActionView.layer.insertSublayer(gradientLayer, at: 0)
                callToActionView.backgroundColor = .clear
            } else if let backgroundColor = config.callToActionBackgroundColor {
                callToActionView.backgroundColor = backgroundColor
            } else {
                callToActionView.backgroundColor = .systemBlue
            }
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        if let callToActionView = callToActionView as? UIButton {
            callToActionView.cornerRadius = 16
            callToActionView.layer.sublayers?.forEach { layer in
                if let gradientLayer = layer as? CAGradientLayer {
                    gradientLayer.frame = callToActionView.bounds
                    gradientLayer.cornerRadius = 16
                }
            }
        }
        if let mediaView = mediaView {
            mediaView.layer.cornerRadius = 8
        }
        if let ads = adsLabelView {
            boundView.bringSubviewToFront(ads)
        }
    }

    func updateMediaVisibility(hasMedia: Bool) {
        guard mediaContainerView != nil else { return }
        let iconSet = (iconView as? UIImageView)?.image != nil
        mediaView?.isHidden = !hasMedia
        if let iv = iconView as? UIImageView {
            iv.isHidden = hasMedia || !iconSet
        }
        let showColumn = hasMedia || iconSet
        mediaContainerView.isHidden = !showColumn
    }

    /// Mirrors `NativeAdViewMedium.applyConfiguration(_:)` — same `NativeAdConfiguration` keys.
    func applyConfiguration(_ configuration: NativeAdConfiguration?) {
        let config = configuration ?? NativeAdConfiguration.shared

        if let headlineView = headlineView as? UILabel {
            if let font = config.headlineFont {
                headlineView.font = font
            }
            if let color = config.headlineTextColor {
                headlineView.textColor = color
            }
        }

        if let bodyView = bodyView as? UILabel {
            if let font = config.bodyFont {
                bodyView.font = font
            }
            if let color = config.bodyTextColor {
                bodyView.textColor = color
            }
        }

        if let callToActionView = callToActionView as? UIButton {
            if let font = config.callToActionFont {
                callToActionView.titleLabel?.font = font
            }

            callToActionView.layer.sublayers?.forEach { layer in
                if layer is CAGradientLayer {
                    layer.removeFromSuperlayer()
                }
            }

            if config.useGradientForCallToAction,
               let startColor = config.callToActionGradientStartColor,
               let endColor = config.callToActionGradientEndColor {
                let gradientLayer = CAGradientLayer()
                gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
                gradientLayer.startPoint = config.callToActionGradientStartPoint
                gradientLayer.endPoint = config.callToActionGradientEndPoint
                gradientLayer.frame = callToActionView.bounds
                gradientLayer.cornerRadius = 16
                callToActionView.layer.insertSublayer(gradientLayer, at: 0)
                callToActionView.backgroundColor = .clear
            } else if let backgroundColor = config.callToActionBackgroundColor {
                callToActionView.backgroundColor = backgroundColor
            }

            if let textColor = config.callToActionTextColor {
                callToActionView.setTitleColor(textColor, for: .normal)
            }
        }

        if let borderColor = config.borderColor {
            boundView.borderColor = borderColor
        }
        if let borderWidth = config.borderWidth {
            boundView.borderWidth = borderWidth
        }

        if let backgroundColor = config.backgroundColor {
            boundView.backgroundColor = backgroundColor
        }

        if let adsLabelBgColor = config.adsLabelBackgroundColor {
            adsLabelView.backgroundColor = adsLabelBgColor
        }
    }
}
