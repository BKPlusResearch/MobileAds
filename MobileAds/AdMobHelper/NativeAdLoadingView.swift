//
//  NativeAdLoadingView.swift
//  AppTheme
//
//  Created by Auto on 2025.
//

import UIKit

/// Loading view for native ads with shimmer animation
class NativeAdLoadingView: UIView {
    
    private lazy var containerView: UIView = {
        let view = UIView()
        // view.backgroundColor = AppColor.getColor(.Neutral20)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        // view.layer.borderColor = AppColor.getColor(.Neutral20).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var callToActionSkeleton: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var iconSkeleton: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var headlineSkeleton: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var bodySkeleton: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
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
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Call to action button skeleton (top)
        containerView.addSubview(callToActionSkeleton)
        NSLayoutConstraint.activate([
            callToActionSkeleton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            callToActionSkeleton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            callToActionSkeleton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            callToActionSkeleton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Icon skeleton (left side, below button)
        containerView.addSubview(iconSkeleton)
        NSLayoutConstraint.activate([
            iconSkeleton.topAnchor.constraint(equalTo: callToActionSkeleton.bottomAnchor, constant: 16),
            iconSkeleton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            iconSkeleton.widthAnchor.constraint(equalToConstant: 48),
            iconSkeleton.heightAnchor.constraint(equalToConstant: 48)
        ])
        
        // Headline skeleton (right side of icon, same top as icon)
        containerView.addSubview(headlineSkeleton)
        NSLayoutConstraint.activate([
            headlineSkeleton.leadingAnchor.constraint(equalTo: iconSkeleton.trailingAnchor, constant: 8),
            headlineSkeleton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            headlineSkeleton.topAnchor.constraint(equalTo: iconSkeleton.topAnchor),
            headlineSkeleton.heightAnchor.constraint(equalToConstant: 14)
        ])
        
        // Body skeleton (below headline)
        containerView.addSubview(bodySkeleton)
        let bottomConstraint = bodySkeleton.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12)
        bottomConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            bodySkeleton.topAnchor.constraint(equalTo: headlineSkeleton.bottomAnchor, constant: 4),
            bodySkeleton.leadingAnchor.constraint(equalTo: headlineSkeleton.leadingAnchor),
            bodySkeleton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            bodySkeleton.heightAnchor.constraint(equalToConstant: 28),
            bottomConstraint
        ])
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
