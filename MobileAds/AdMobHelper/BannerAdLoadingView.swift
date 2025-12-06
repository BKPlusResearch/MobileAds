//
//  BannerAdLoadingView.swift
//  MobileAds
//
//  Created by Auto on 2025.
//

import UIKit
import SnapKit

/// Loading view for banner ads with shimmer animation
class BannerAdLoadingView: UIView {
    
    private lazy var containerView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var skeletonView1: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        startAnimation()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        startAnimation()
    }
    
    private func setupUI() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // First skeleton view (left side, larger)
        containerView.addSubview(skeletonView1)
        skeletonView1.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
    }
    
    func startAnimation() {
        let shimmerViews = [skeletonView1]
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
        let shimmerViews = [skeletonView1]
        shimmerViews.forEach { view in
            view.layer.removeAnimation(forKey: "shimmer")
        }
    }
}

