//
//  NativeAdViewSmall.swift
//  AppTheme
//
//  Created by Auto on 2024.
//

import UIKit
@preconcurrency import GoogleMobileAds

/// Custom view class for managing NativeAdViewSmall.xib
class NativeAdViewSmall: NativeAdView {

    // MARK: - IBOutlets
    // These outlets are already connected in the XIB file
    // They are inherited from GADNativeAdView:
    // @IBOutlet weak var headlineView: UIView!
    // @IBOutlet weak var bodyView: UIView!
    // @IBOutlet weak var callToActionView: UIView!
    // @IBOutlet weak var iconView: UIView!
    @IBOutlet weak var boundView: UIView!
    @IBOutlet weak var adsLabelView: UIView!

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
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
        // Use system colors as defaults - can be customized via configuration if needed
        boundView.backgroundColor = .systemBackground
        boundView.cornerRadius = 12
        boundView.borderWidth = 1
        boundView.borderColor = .separator // Use system separator color
        adsLabelView.cornerRadius = 2
        
        // Setup headline and body view styling
        setupTextViews()

        // Setup call to action button
        setupCallToActionGradient()
    }

    /// Setup font and text color for headline and body views
    /// Default values are set here, but will be overridden by applyConfiguration if provided
    private func setupTextViews() {
        // Delay to ensure outlets are connected when loading from XIB
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Setup headline view with default values
            if let headlineView = self.headlineView as? UILabel {
                headlineView.font = UIFont.systemFont(ofSize: 14, weight: .medium)
                headlineView.textColor = .label // Use system label color instead of AppColor
            }

            // Setup body view with default values
            if let bodyView = self.bodyView as? UILabel {
                bodyView.font = UIFont.systemFont(ofSize: 12, weight: .regular)
                bodyView.textColor = .label // Use system label color instead of AppColor
            }
            
            // Setup call to action button with default values
            if let callToActionView = self.callToActionView as? UIButton {
                callToActionView.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
                callToActionView.setTitleColor(.white, for: .normal)
                callToActionView.layer.cornerRadius = 12
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
            callToActionView.layer.cornerRadius = 12
            
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

    override func layoutSubviews() {
        super.layoutSubviews()

        // Update gradient layer frame when view layout changes
        if let callToActionView = callToActionView as? UIButton {
            // Ensure corner radius is set
            callToActionView.layer.cornerRadius = 12
            
            // Update gradient layer frame if exists
            callToActionView.layer.sublayers?.forEach { layer in
                if let gradientLayer = layer as? CAGradientLayer {
                    gradientLayer.frame = callToActionView.bounds
                    gradientLayer.cornerRadius = 12
                }
            }
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
                gradientLayer.cornerRadius = 12
                
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
    }
}

