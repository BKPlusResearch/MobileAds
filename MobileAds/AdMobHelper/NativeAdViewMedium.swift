//
//  NativeAdViewMedium.swift
//  AppTheme
//
//  Created by Auto on 2024.
//

import UIKit
@preconcurrency import GoogleMobileAds

/// Custom view class for managing NativeAdViewMedium.xib
/// Layout: MediaView on the left, content on the right
public class NativeAdViewMedium: NativeAdView {

    // MARK: - IBOutlets
    // These outlets are already connected in the XIB file
    // They are inherited from GADNativeAdView:
    // @IBOutlet weak var headlineView: UIView!
    // @IBOutlet weak var bodyView: UIView!
    // @IBOutlet weak var callToActionView: UIView!
    // @IBOutlet weak var iconView: UIView!
    // @IBOutlet weak var mediaView: GADMediaView!
    @IBOutlet weak var boundView: UIView!
    @IBOutlet weak var adsLabelView: UIView!
    @IBOutlet weak var mainStackView: UIStackView!

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

    /// Load NativeAdViewMedium from XIB
    /// This is the recommended way to create an instance
    static func loadFromXib() -> NativeAdViewMedium? {
        let bundle = Bundle(for: NativeAdViewMedium.self)
        return UINib(nibName: "NativeAdViewMedium", bundle: bundle)
            .instantiate(withOwner: nil, options: nil)
            .first as? NativeAdViewMedium
    }

    // MARK: - Configuration

    private func setupUI() {
        // Use system colors as defaults - can be customized via configuration if needed
        boundView.cornerRadius = 8
        boundView.clipsToBounds = true

        // Setup ads label view with bottom-right corner radius only
        adsLabelView.cornerRadius = 8
        adsLabelView.layer.maskedCorners = [.layerMaxXMaxYCorner] // Bottom-right corner only
        adsLabelView.layer.masksToBounds = true

        // Setup mediaView corner radius
        if let mediaView = mediaView {
            mediaView.layer.cornerRadius = 8
            mediaView.layer.masksToBounds = true
        }

        // Setup headline and body view styling
        setupTextViews()

        // Setup call to action button
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
                headlineView.font = config.headlineFont ?? UIFont.systemFont(ofSize: 16, weight: .semibold)
                headlineView.textColor = config.headlineTextColor ?? .label
            }

            // Setup body view with config or default values
            if let bodyView = self.bodyView as? UILabel {
                bodyView.font = config.bodyFont ?? UIFont.systemFont(ofSize: 14, weight: .regular)
                bodyView.textColor = config.bodyTextColor ?? .label
            }

            // Setup call to action button with config or default values
            if let callToActionView = self.callToActionView as? UIButton {
                callToActionView.titleLabel?.font = config.callToActionFont ?? UIFont.systemFont(ofSize: 16, weight: .bold)
                callToActionView.setTitleColor(config.callToActionTextColor ?? .white, for: .normal)
                callToActionView.cornerRadius = 20
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

            // Set corner radius
            callToActionView.cornerRadius = 20

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
            gradientLayer.cornerRadius = 12

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
            // Ensure corner radius is set
            callToActionView.cornerRadius = 20

            // Update gradient layer frame if exists
            callToActionView.layer.sublayers?.forEach { layer in
                if let gradientLayer = layer as? CAGradientLayer {
                    gradientLayer.frame = callToActionView.bounds
                    gradientLayer.cornerRadius = 20
                }
            }
        }

        // Update mediaView corner radius
        if let mediaView = mediaView {
            mediaView.layer.cornerRadius = 8
        }
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
                gradientLayer.cornerRadius = 20

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

    /// Hide media view when ad doesn't have media
    /// This will collapse the mediaView in the stack view
    func hideMediaView() {
        guard let mediaView = mediaView else { return }
        mediaView.isHidden = true
    }

    /// Show media view when ad has media
    func showMediaView() {
        guard let mediaView = mediaView else { return }
        mediaView.isHidden = false
    }

    /// Update media view visibility based on whether the ad has media content
    /// Call this after setting the native ad
    /// - Parameter hasMedia: Whether the native ad has media content
    func updateMediaVisibility(hasMedia: Bool) {
        if hasMedia {
            showMediaView()
        } else {
            hideMediaView()
        }
    }
}
