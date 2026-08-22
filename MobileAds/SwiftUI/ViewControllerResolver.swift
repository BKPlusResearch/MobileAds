import SwiftUI

// MARK: - ViewControllerResolver

/// Bridge để resolve `UIViewController` từ SwiftUI view hierarchy.
/// Được sử dụng nội bộ bởi BannerAdSwiftUI, NativeAdSwiftUI và Fullscreen ad modifiers.
///
/// GMA SDK yêu cầu `UIViewController` để present ads. SwiftUI không expose VC trực tiếp,
/// nên component này embed một invisible VC vào hierarchy và callback khi VC sẵn sàng.
///
/// Usage (nội bộ):
/// ```swift
/// .background(
///     ViewControllerResolver { vc in
///         // vc is now available for GMA SDK
///     }
///     .frame(width: 0, height: 0)
/// )
/// ```
@available(iOS 15.0, *)
struct ViewControllerResolver: UIViewControllerRepresentable {
    let onResolve: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = ResolverViewController()
        vc.onResolve = onResolve
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let resolver = uiViewController as? ResolverViewController else { return }
        print("[vunt ads] ViewControllerResolver.updateUIViewController fired, hasParent=\(resolver.parent != nil)")
        resolver.onResolve = onResolve
        if let parent = resolver.parent {
            resolver.onResolve?(parent)
        }
    }
}

// MARK: - ResolverViewController

/// Internal VC that notifies when it's been added to the view hierarchy.
@available(iOS 15.0, *)
private class ResolverViewController: UIViewController {
    var onResolve: ((UIViewController) -> Void)?

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        print("[vunt ads] ResolverVC.didMove parent=\(parent != nil)")
        // Initial setup only — updateUIViewController handles subsequent re-fires
        if let parent = parent {
            onResolve?(parent)
        }
    }
}

// MARK: - UIView Extension

extension UIView {
    /// Traverse responder chain để tìm UIViewController gần nhất.
    /// Dùng bởi BannerAdSwiftUI và NativeAdSwiftUI khi cần rootViewController.
    var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController {
                return vc
            }
            responder = next
        }
        return nil
    }
}
