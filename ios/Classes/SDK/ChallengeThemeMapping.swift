import Gateway
import UIKit

/// Builds the iOS SDK `ChallengeTheme` from the shared challenge customization.
///
/// The iOS SDK themes the challenge screen with global properties, so shared styles are mapped
/// onto them; per-button styles (`androidButtonStyles`) have no iOS equivalent and are ignored.
/// Toolbar font size is ignored as well: the theme has no toolbar font.
func toChallengeTheme(_ message: ChallengeUiMessage) -> ChallengeTheme {
  let theme = ChallengeTheme()

  if let toolbar = message.toolbar {
    if let color = uiColor(toolbar.backgroundColor) { theme.navigationBarBarTintColor = color }
    if let color = uiColor(toolbar.textColor) {
      theme.navigationBarTitleTextColor = color
      theme.titleColor = color
    }
    if let title = toolbar.title { theme.title = title }
    if let cancelText = toolbar.cancelText { theme.cancelText = cancelText }
  }

  if let button = message.button {
    if let color = uiColor(button.backgroundColor) { theme.buttonBackgroundColor = color }
    if let color = uiColor(button.textColor) { theme.buttonTextColor = color }
    if let radius = button.cornerRadius { theme.cornerRadius = CGFloat(radius) }
    theme.buttonTitleFont = font(
      name: message.regularFontName, size: button.fontSize, fallback: theme.buttonTitleFont)
  }

  if let label = message.label {
    if let color = uiColor(label.textColor) { theme.standardTextColor = color }
    if let color = uiColor(label.headingTextColor) { theme.headerTextColor = color }
    theme.standardFont = font(
      name: message.regularFontName, size: label.fontSize, fallback: theme.standardFont)
    theme.headerFont = font(
      name: message.headingFontName, size: label.headingFontSize, fallback: theme.headerFont)
  }

  if let textBox = message.textBox {
    if let color = uiColor(textBox.borderColor) { theme.borderColor = color }
    if let width = textBox.borderWidth { theme.borderWidth = CGFloat(width) }
    // The theme has a single corner radius; the button style takes precedence.
    if message.button?.cornerRadius == nil, let radius = textBox.cornerRadius {
      theme.cornerRadius = CGFloat(radius)
    }
    if message.label?.textColor == nil, let color = uiColor(textBox.textColor) {
      theme.standardTextColor = color
    }
  }

  if message.label == nil {
    theme.standardFont = font(name: message.regularFontName, size: nil, fallback: theme.standardFont)
    theme.headerFont = font(name: message.headingFontName, size: nil, fallback: theme.headerFont)
  }

  if let ios = message.ios {
    if let color = uiColor(ios.primaryBackgroundColor) { theme.primaryBackgroundColor = color }
    if let color = uiColor(ios.secondaryBackgroundColor) { theme.secondaryBackgroundColor = color }
    if let color = uiColor(ios.labelBackgroundColor) { theme.labelBackgroundColor = color }
    if let color = uiColor(ios.tintColor) { theme.tintColor = color }
    if let color = uiColor(ios.navigationBarTintColor) { theme.navigationBarTintColor = color }
    if let color = uiColor(ios.cancelTextColor) { theme.cancelTextColor = color }
    if let keyboard = ios.keyboardAppearance {
      switch keyboard {
      case .systemDefault: theme.keyboardApperance = .default
      case .light: theme.keyboardApperance = .light
      case .dark: theme.keyboardApperance = .dark
      }
    }
    if let appearance = ios.appearance {
      switch appearance {
      case .light: theme.appearanceType = .light
      case .dark: theme.appearanceType = .dark
      }
    }
  }

  return theme
}

/// Converts a 32-bit ARGB value to `UIColor`.
func uiColor(_ argb: Int64?) -> UIColor? {
  guard let argb = argb else { return nil }
  let value = UInt32(truncatingIfNeeded: argb)
  return UIColor(
    red: CGFloat((value >> 16) & 0xFF) / 255,
    green: CGFloat((value >> 8) & 0xFF) / 255,
    blue: CGFloat(value & 0xFF) / 255,
    alpha: CGFloat((value >> 24) & 0xFF) / 255)
}

/// Uses the named font when it is registered natively; keeps the SDK default otherwise, so a
/// font declared only in Flutter assets does not break the challenge screen.
private func font(name: String?, size: Double?, fallback: UIFont) -> UIFont {
  let pointSize = size.map { CGFloat($0) } ?? fallback.pointSize
  if let name = name, let named = UIFont(name: name, size: pointSize) {
    return named
  }
  return size == nil ? fallback : fallback.withSize(pointSize)
}
