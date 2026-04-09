//
//  NativeAdViewSmall.swift
//  AppTheme
//
//  Created by Auto on 2024.
//

import UIKit
@preconcurrency import GoogleMobileAds

/// Custom view class for `NativeAdViewSmall.xib`
/// Layout follows Google’s native **small** template: square media (≤25% width) + headline + Ad badge + secondary line + CTA.
/// See <https://developers.google.com/admob/ios/native/templates>
public class NativeAdViewSmall: NativeAdView {

    // MARK: - IBOutlets
    // headlineView, bodyView, callToActionView, iconView, mediaView: `NativeAdView`
    @IBOutlet weak var boundView: UIView!
    @IBOutlet weak var adsLabelView: UIView!
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

    /// Load NativeAdViewSmall from XIB
    /// This is the recommended way to create an instance
    static func loadFromXib() -> NativeAdViewSmall? {
        let bundle = Bundle(for: NativeAdViewSmall.self)
        return UINib(nibName: "NativeAdViewSmall", bundle: bundle)
            .instantiate(withOwner: nil, options: nil)
            .first as? NativeAdViewSmall
    }

    // MARK: - Configuration

    private func setupUI() {
        boundView.backgroundColor = .systemBackground
        boundView.cornerRadius = 8
        boundView.borderWidth = 1
        boundView.borderColor = .separator

        adsLabelView.layer.cornerRadius = 4
        adsLabelView.layer.masksToBounds = true

        if let mediaView = mediaView {
            mediaView.layer.cornerRadius = 8
            mediaView.clipsToBounds = true
        }

        setupTextViews()
        setupCallToActionGradient()
    }

    /// Setup font and text color for headline and body views
    /// Default values are set here, respecting configuration if available
    private func setupTextViews() {
        // Delay to ensure outlets are connected when loading from XIB
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let config = NativeAdConfiguration.shared

            // Setup headline view with config or default values
            if let headlineView = self.headlineView as? UILabel {
                headlineView.font = config.headlineFont ?? UIFont.systemFont(ofSize: 14, weight: .medium)
                headlineView.textColor = config.headlineTextColor ?? .label
            }

            // Setup body view with config or default values
            if let bodyView = self.bodyView as? UILabel {
                bodyView.font = config.bodyFont ?? UIFont.systemFont(ofSize: 12, weight: .regular)
                bodyView.textColor = config.bodyTextColor ?? .label
            }

            // Setup call to action button with config or default values
            if let callToActionView = self.callToActionView as? UIButton {
                callToActionView.titleLabel?.font = config.callToActionFont ?? UIFont.systemFont(ofSize: 15, weight: .bold)
                callToActionView.setTitleColor(config.callToActionTextColor ?? .white, for: .normal)
                callToActionView.layer.cornerRadius = 8
            }
        }
    }

    /// Setup gradient background for call to action button
    /// Applies configuration from NativeAdConfiguration.shared singleton
    private func setupCallToActionGradient() {
        // Delay to ensure outlets are connected when loading from XIB
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let callToActionView = self.callToActionView as? UIButton else { return }

            let config = NativeAdConfiguration.shared
            
            callToActionView.layer.cornerRadius = 8
            
            // Remove any existing gradient layers first
            callToActionView.layer.sublayers?.forEach { layer in
                if layer is CAGradientLayer {
                    layer.removeFromSuperlayer()
                }
            }

            // Apply gradient or solid background color from shared configuration
            if config.useGradientForCallToAction,
               let startColor = config.callToActionGradientStartColor,
               let endColor = config.callToActionGradientEndColor {
                // Apply gradient
            let gradientLayer = CAGradientLayer()
                gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
                gradientLayer.startPoint = config.callToActionGradientStartPoint
                gradientLayer.endPoint = config.callToActionGradientEndPoint
            gradientLayer.frame = callToActionView.bounds
            gradientLayer.cornerRadius = 8

            // Insert gradient layer at the bottom
            callToActionView.layer.insertSublayer(gradientLayer, at: 0)
            callToActionView.backgroundColor = .clear
            } else if let backgroundColor = config.callToActionBackgroundColor {
                // Apply solid background color
                callToActionView.backgroundColor = backgroundColor
            } else {
                // Default fallback color if no configuration is set
                callToActionView.backgroundColor = .systemBlue
            }
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        // Update gradient layer frame when view layout changes
        if let callToActionView = callToActionView as? UIButton {
            callToActionView.layer.cornerRadius = 8
            callToActionView.layer.sublayers?.forEach { layer in
                if let gradientLayer = layer as? CAGradientLayer {
                    gradientLayer.frame = callToActionView.bounds
                    gradientLayer.cornerRadius = 8
                }
            }
        }
        if let mediaView = mediaView {
            mediaView.layer.cornerRadius = 8
        }
    }

    /// Collapse media column when there is no media and no icon (Google-style thin row).
    /// Call after `nativeAd` and asset views are populated.
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

    /// Apply configuration to customize appearance
    /// - Parameter configuration: Configuration for customizing ad appearance. If nil, uses `NativeAdConfiguration.shared` singleton
    func applyConfiguration(_ configuration: NativeAdConfiguration?) {
        // Use provided configuration or fall back to shared singleton
        let config = configuration ?? NativeAdConfiguration.shared

        // Apply headline font and color
        if let headlineView = headlineView as? UILabel {
            if let font = config.headlineFont {
                headlineView.font = font
            }
            if let color = config.headlineTextColor {
                headlineView.textColor = color
            }
        }

        // Apply body font and color
        if let bodyView = bodyView as? UILabel {
            if let font = config.bodyFont {
                bodyView.font = font
            }
            if let color = config.bodyTextColor {
                bodyView.textColor = color
            }
        }

        // Apply call to action button styling
        if let callToActionView = callToActionView as? UIButton {
            if let font = config.callToActionFont {
                callToActionView.titleLabel?.font = font
            }
            
            // Remove any existing gradient layers first
            callToActionView.layer.sublayers?.forEach { layer in
                if layer is CAGradientLayer {
                    layer.removeFromSuperlayer()
                }
            }
            
            // Apply gradient or solid background color
            if config.useGradientForCallToAction,
               let startColor = config.callToActionGradientStartColor,
               let endColor = config.callToActionGradientEndColor {
                // Apply gradient
                let gradientLayer = CAGradientLayer()
                gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
                gradientLayer.startPoint = config.callToActionGradientStartPoint
                gradientLayer.endPoint = config.callToActionGradientEndPoint
                gradientLayer.frame = callToActionView.bounds
                gradientLayer.cornerRadius = 8
                
                // Insert gradient layer at the bottom
                callToActionView.layer.insertSublayer(gradientLayer, at: 0)
                callToActionView.backgroundColor = .clear
            } else if let backgroundColor = config.callToActionBackgroundColor {
                // Apply solid background color
                callToActionView.backgroundColor = backgroundColor
            }
            
            if let textColor = config.callToActionTextColor {
                callToActionView.setTitleColor(textColor, for: .normal)
            }
        }

        // Apply border customization
        if let borderColor = config.borderColor {
            boundView.borderColor = borderColor
        }
        if let borderWidth = config.borderWidth {
            boundView.borderWidth = borderWidth
        }

        // Apply background customization
        if let backgroundColor = config.backgroundColor {
            boundView.backgroundColor = backgroundColor
        }

        // Apply ads label background color
        if let adsLabelBgColor = config.adsLabelBackgroundColor {
            adsLabelView.backgroundColor = adsLabelBgColor
        }
    }
}

