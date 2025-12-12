//
//  NativeAdMediumLoadingView.swift
//  AppTheme
//
//  Created by Auto on 2024.
//

import UIKit
import SnapKit

/// Loading view for medium native ads with shimmer animation
/// Layout: MediaView skeleton on the left, content skeleton on the right
class NativeAdMediumLoadingView: UIView {

    private lazy var containerView: UIView = {
        let view = UIView()
        view.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()

    // Left side - Media skeleton
    private lazy var mediaSkeleton: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.cornerRadius = 8
        return view
    }()

    // Right side - Content skeletons
    private lazy var iconSkeleton: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.cornerRadius = 4
        return view
    }()

    private lazy var headlineSkeleton: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.cornerRadius = 4
        return view
    }()

    private lazy var bodySkeleton1: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.cornerRadius = 4
        return view
    }()

    private lazy var bodySkeleton2: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.cornerRadius = 4
        return view
    }()

    private lazy var callToActionSkeleton: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.cornerRadius = 20
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        applyConfiguration(NativeAdConfiguration.shared)
        startShimmerAnimation()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        applyConfiguration(NativeAdConfiguration.shared)
        startShimmerAnimation()
    }

    private func setupUI() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }

        // Media skeleton (left side)
        containerView.addSubview(mediaSkeleton)
        mediaSkeleton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.top.equalToSuperview().inset(12)
            make.width.equalTo(160)
            make.height.greaterThanOrEqualTo(120)
            make.bottom.lessThanOrEqualToSuperview().inset(12)
        }

        // Icon skeleton (top-left of content area)
        containerView.addSubview(iconSkeleton)
        iconSkeleton.snp.makeConstraints { make in
            make.leading.equalTo(mediaSkeleton.snp.trailing).offset(8)
            make.top.equalToSuperview().inset(12)
            make.width.height.equalTo(34)
        }

        // Headline skeleton (right of icon)
        containerView.addSubview(headlineSkeleton)
        headlineSkeleton.snp.makeConstraints { make in
            make.leading.equalTo(iconSkeleton.snp.trailing).offset(4)
            make.trailing.equalToSuperview().inset(12)
            make.top.equalTo(iconSkeleton)
            make.height.equalTo(16)
        }

        // Body skeleton 1 (below icon)
        containerView.addSubview(bodySkeleton1)
        bodySkeleton1.snp.makeConstraints { make in
            make.leading.equalTo(iconSkeleton)
            make.trailing.equalToSuperview().inset(12)
            make.top.equalTo(iconSkeleton.snp.bottom).offset(4)
            make.height.equalTo(14)
        }

        // Body skeleton 2 (below body skeleton 1)
        containerView.addSubview(bodySkeleton2)
        bodySkeleton2.snp.makeConstraints { make in
            make.leading.equalTo(iconSkeleton)
            make.trailing.equalToSuperview().inset(12)
            make.top.equalTo(bodySkeleton1.snp.bottom).offset(4)
            make.height.equalTo(14)
        }

        // Call to action button skeleton (bottom of content area)
        containerView.addSubview(callToActionSkeleton)
        callToActionSkeleton.snp.makeConstraints { make in
            make.leading.equalTo(iconSkeleton)
            make.trailing.equalToSuperview().inset(12)
            make.top.equalTo(bodySkeleton2.snp.bottom).offset(12)
            make.height.equalTo(40)
            make.bottom.equalToSuperview().inset(12)
        }
    }

    /// Apply configuration to customize loading view appearance
    /// - Parameter configuration: Configuration for customizing appearance
    func applyConfiguration(_ configuration: NativeAdConfiguration) {
        // Apply border customization
        if let borderColor = configuration.borderColor {
            containerView.borderColor = borderColor
        }
        if let borderWidth = configuration.borderWidth {
            containerView.borderWidth = borderWidth
        }

        // Apply background customization
        if let backgroundColor = configuration.backgroundColor {
            containerView.backgroundColor = backgroundColor
        } else {
            containerView.backgroundColor = .systemBackground
        }
    }

    private func startShimmerAnimation() {
        let shimmerViews = [
            mediaSkeleton,
            iconSkeleton,
            headlineSkeleton,
            bodySkeleton1,
            bodySkeleton2,
            callToActionSkeleton
        ]

        shimmerViews.forEach { view in
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.5
            animation.toValue = 1.0
            animation.duration = 1.0
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            view.layer.add(animation, forKey: "shimmer")
        }
    }

    func stopAnimation() {
        let shimmerViews = [
            mediaSkeleton,
            iconSkeleton,
            headlineSkeleton,
            bodySkeleton1,
            bodySkeleton2,
            callToActionSkeleton
        ]

        shimmerViews.forEach { view in
            view.layer.removeAnimation(forKey: "shimmer")
        }
    }
}
