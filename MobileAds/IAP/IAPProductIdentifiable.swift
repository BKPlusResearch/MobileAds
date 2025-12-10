//
//  IAPProductIdentifiable.swift
//  MobileAds
//
//  Created by MobileAds Framework
//

import Foundation

/// Protocol để định nghĩa Product ID cho In-App Purchases
/// App sẽ implement protocol này để define các Product IDs của mình
/// Pattern tương tự như AdUnitIdentifiable
public protocol IAPProductIdentifiable {
    /// Chuỗi Product ID dùng để request products từ App Store
    var productIDString: String { get }
}

