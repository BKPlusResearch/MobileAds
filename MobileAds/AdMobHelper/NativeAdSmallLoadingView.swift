//
//  NativeAdLoadingView.swift
//  AppTheme
//
//  Created by Auto on 2025.
//

import UIKit
import SnapKit

/// Loading view for native ads with shimmer animation
class NativeAdSmallLoadingView: UIView {
    
    private lazy var containerView: UIView = {
        let view = UIView()
//        view.backgroundColor = AppColor.getColor(.NeutralBGAds)
        view.cornerRadius = 12
        view.borderWidth = 1
//        view.borderColor = AppColor.getColor(.Neutral20)
        return view
    }()
    
    private lazy var callToActionSkeleton: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.cornerRadius = 12
        return view
    }()
    
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
    
    private lazy var bodySkeleton: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.cornerRadius = 4
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        startShimmerAnimation()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        startShimmerAnimation()
    }
    
    private func setupUI() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Call to action button skeleton (top)
        containerView.addSubview(callToActionSkeleton)
        callToActionSkeleton.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.leading.trailing.equalToSuperview().inset(12)
            make.height.equalTo(44)
        }
        
        // Icon skeleton (left side, below button)
        containerView.addSubview(iconSkeleton)
        iconSkeleton.snp.makeConstraints { make in
            make.top.equalTo(callToActionSkeleton.snp.bottom).offset(16)
            make.leading.equalToSuperview().inset(12)
            make.width.height.equalTo(48)
        }
        
        // Headline skeleton (right side of icon, same top as icon)
        containerView.addSubview(headlineSkeleton)
        headlineSkeleton.snp.makeConstraints { make in
            make.leading.equalTo(iconSkeleton.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(12)
            make.top.equalTo(iconSkeleton)
            make.height.equalTo(14)
        }
        
        // Body skeleton (below headline)
        containerView.addSubview(bodySkeleton)
        bodySkeleton.snp.makeConstraints { make in
            make.top.equalTo(headlineSkeleton.snp.bottom).offset(4)
            make.leading.equalTo(headlineSkeleton)
            make.trailing.equalToSuperview().inset(12)
            make.height.equalTo(28)
            make.bottom.lessThanOrEqualToSuperview().inset(12)
        }
    }
    
    private func startShimmerAnimation() {
        let shimmerViews = [callToActionSkeleton, iconSkeleton, headlineSkeleton, bodySkeleton]
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
        let shimmerViews = [callToActionSkeleton, iconSkeleton, headlineSkeleton, bodySkeleton]
        shimmerViews.forEach { view in
            view.layer.removeAnimation(forKey: "shimmer")
        }
    }
}

