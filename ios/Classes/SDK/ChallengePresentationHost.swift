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
  /// UIKit does not always call a presentation completion (for example when the presenter is
  /// mid-transition). Without this guard a dropped completion would leave the operation lock
  /// held and a touch-blocking overlay on screen for the rest of the process.
  private static let presentationTimeout: TimeInterval = 5

  private var navigationController: UINavigationController?

  /// Presents the host and returns it, or returns `nil` when no visible view controller can
  /// present (for example while the app is in the background, or while another presentation is
  /// still running).
  func present(completion: @escaping (UINavigationController?) -> Void) {
    guard navigationController == nil,
      let presenter = Self.topViewController(),
      !presenter.isBeingPresented,
      !presenter.isBeingDismissed,
      presenter.presentedViewController == nil
    else {
      completion(nil)
      return
    }

    let root = UIViewController()
    root.view.backgroundColor = .clear
    let navigation = UINavigationController(rootViewController: root)
    navigation.modalPresentationStyle = .overFullScreen
    navigation.view.backgroundColor = .clear
    // The bar stays visible: the SDK themes it and renders the challenge's cancel control in
    // it, so hiding it can leave the payer with no way out of the challenge.
    navigation.navigationBar.isTranslucent = true
    root.navigationItem.title = nil

    var hasAnswered = false
    let answer: (UINavigationController?) -> Void = { result in
      guard !hasAnswered else { return }
      hasAnswered = true
      completion(result)
    }

    presenter.present(navigation, animated: false) { [weak self] in
      self?.navigationController = navigation
      answer(navigation)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + Self.presentationTimeout) { [weak self] in
      guard !hasAnswered else { return }
      // The presentation never reported back: take the overlay down and fail the operation.
      navigation.presentingViewController?.dismiss(animated: false)
      self?.navigationController = nil
      answer(nil)
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
    // Not animated: a 3DS flow can finish while the app is in the background, where an
    // animated transition — and therefore the reply to Flutter — would be deferred until the
    // app is visible again.
    presenter.dismiss(animated: false, completion: completion)
  }

  /// Takes the overlay down without waiting for an authentication that can no longer finish.
  func dismissWithoutWaiting() {
    guard let navigation = navigationController else { return }
    navigationController = nil
    navigation.presentingViewController?.dismiss(animated: false)
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
