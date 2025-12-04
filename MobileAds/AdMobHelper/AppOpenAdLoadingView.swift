//
//  AppOpenAdLoadingView.swift
//  AppTheme
//
//  Created by Auto on 2025.
//

import UIKit
import SnapKit

class AppOpenAdLoadingView: UIView {
	
	private lazy var activityIndicator: UIActivityIndicatorView = {
		let indicator = UIActivityIndicatorView(style: .large)
		indicator.color = .white
		indicator.startAnimating()
		return indicator
	}()
	
	private lazy var loadingLabel: UILabel = {
		let label = UILabel()
		label.text = "Loading ads..."
		label.textColor = .white
		label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
		label.textAlignment = .center
		return label
	}()
	
	private lazy var contentStackView: UIStackView = {
		let stack = UIStackView(arrangedSubviews: [activityIndicator, loadingLabel])
		stack.axis = .vertical
		stack.spacing = 16
		stack.alignment = .center
		return stack
	}()
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupUI()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupUI()
	}
	
	private func setupUI() {
		backgroundColor = UIColor.black.withAlphaComponent(0.8)
		
		addSubview(contentStackView)
		contentStackView.snp.makeConstraints { make in
			make.center.equalToSuperview()
		}
	}
	
	/// Show loading view on the key window
	func show() {
		guard let window = getKeyWindow() else {
			print("AppOpenAdLoadingView: No key window found")
			return
		}
		
		// Remove if already added
		if superview != nil {
			removeFromSuperview()
		}
		
		window.addSubview(self)
		snp.makeConstraints { make in
			make.edges.equalToSuperview()
		}
		
		alpha = 0
		UIView.animate(withDuration: 0.2) {
			self.alpha = 1.0
		}
	}
	
	/// Hide and remove loading view
	func hide() {
		UIView.animate(withDuration: 0.2, animations: {
			self.alpha = 0
		}) { _ in
			self.removeFromSuperview()
		}
	}
	
	/// Get the key window
	private func getKeyWindow() -> UIWindow? {
		if #available(iOS 13.0, *) {
			return UIApplication.shared.connectedScenes
				.compactMap { $0 as? UIWindowScene }
				.flatMap { $0.windows }
				.first { $0.isKeyWindow }
		} else {
			return UIApplication.shared.windows.first { $0.isKeyWindow }
		}
	}
}

