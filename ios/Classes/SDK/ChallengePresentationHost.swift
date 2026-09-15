import UIKit

/// Provides the `UINavigationController` that the iOS Gateway SDK requires for the 3-D Secure
/// challenge, without assuming anything about the host app's view controller hierarchy.
///
/// Flutter apps are not embedded in a navigation controller, and the app's root view controller
/// may itself be presenting something (a modal, a sheet). The host therefore finds the top-most
/// visible view controller at the moment authentication starts and presents a transparent,
/// full-screen navigation controller over it. The SDK uses that navigation controller for the
/// challenge; the host dismisses it when authentication finishes.
///
/// The transparent overlay also blocks touches on the Flutter UI while authentication runs.
///
/// Verify on a device whenever the SDK is updated: the SDK's release notes mention changes to
/// "Navigation Control for Challenge Flow" (2.0.13).
final class ChallengePresentationHost {
  private var navigationController: UINavigationController?

  /// Presents the host and returns it, or returns `nil` when no visible view controller can
  /// present (for example while the app is in the background).
  func present(completion: @escaping (UINavigationController?) -> Void) {
    guard navigationController == nil, let presenter = Self.topViewController() else {
      completion(nil)
      return
    }

    let root = UIViewController()
    root.view.backgroundColor = .clear
    let navigation = UINavigationController(rootViewController: root)
    navigation.modalPresentationStyle = .overFullScreen
    navigation.view.backgroundColor = .clear
    navigation.setNavigationBarHidden(true, animated: false)
    navigationController = navigation

    presenter.present(navigation, animated: false) {
      completion(navigation)
    }
  }

  /// Dismisses the host, then calls `completion`, so the next presentation cannot collide with
  /// an unfinished dismissal.
  func dismiss(completion: @escaping () -> Void) {
    guard let navigation = navigationController else {
      completion()
      return
    }
    navigationController = nil
    guard let presenter = navigation.presentingViewController else {
      completion()
      return
    }
    presenter.dismiss(animated: true, completion: completion)
  }

  static func topViewController() -> UIViewController? {
    guard UIApplication.shared.applicationState != .background else { return nil }

    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    var top = window?.rootViewController

    while let presented = top?.presentedViewController, !presented.isBeingDismissed {
      top = presented
    }
    return top
  }
}
