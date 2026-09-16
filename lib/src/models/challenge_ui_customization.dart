import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable, mapEquals;

import '../generated/payment_api.g.dart'
    show ChallengeAppearance, ChallengeButtonType, ChallengeKeyboardAppearance;

/// Appearance of the native 3DS challenge screen (e.g. the OTP screen).
///
/// Top-level styles apply on both platforms. [android] and [ios] hold properties that
/// exist in only one native SDK, because the two SDKs use different customization models.
///
/// Font names must refer to fonts registered natively (system fonts, or fonts bundled in
/// the host app's Android/iOS project). Fonts declared only in Flutter assets are not
/// visible to the native challenge screen.
@immutable
class ChallengeUiCustomization {
  /// Creates a customization; every part is optional and falls back to the SDK default.
  const ChallengeUiCustomization({
    this.toolbar,
    this.button,
    this.label,
    this.textBox,
    this.regularFontName,
    this.headingFontName,
    this.android,
    this.ios,
  });

  /// Title bar of the challenge screen.
  final ChallengeToolbarStyle? toolbar;

  /// Applies to every button on the challenge screen; [AndroidChallengeCustomization]
  /// can override single buttons on Android.
  final ChallengeButtonStyle? button;

  /// Texts and headings of the challenge screen.
  final ChallengeLabelStyle? label;

  /// Input field the payer types the code into.
  final ChallengeTextBoxStyle? textBox;

  /// Native font family name used for normal text and buttons.
  final String? regularFontName;

  /// Native font family name used for headings and the toolbar title.
  final String? headingFontName;

  /// Customization supported by the Android SDK only.
  final AndroidChallengeCustomization? android;

  /// Customization supported by the iOS SDK only.
  final IosChallengeCustomization? ios;

  @override
  bool operator ==(Object other) =>
      other is ChallengeUiCustomization &&
      other.toolbar == toolbar &&
      other.button == button &&
      other.label == label &&
      other.textBox == textBox &&
      other.regularFontName == regularFontName &&
      other.headingFontName == headingFontName &&
      other.android == android &&
      other.ios == ios;

  @override
  int get hashCode => Object.hash(
    toolbar,
    button,
    label,
    textBox,
    regularFontName,
    headingFontName,
    android,
    ios,
  );
}

/// Style of the challenge screen title bar.
@immutable
class ChallengeToolbarStyle {
  /// Creates a toolbar style; unset properties keep the SDK default.
  const ChallengeToolbarStyle({
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.title,
    this.cancelText,
  });

  /// Background of the title bar.
  final Color? backgroundColor;

  /// Color of the title text.
  final Color? textColor;

  /// Title font size. Android only; the iOS theme has no toolbar font.
  final double? fontSize;

  /// Title text, for example `'Secure Payment'`.
  final String? title;

  /// Label of the cancel button in the title bar.
  final String? cancelText;

  @override
  bool operator ==(Object other) =>
      other is ChallengeToolbarStyle &&
      other.backgroundColor == backgroundColor &&
      other.textColor == textColor &&
      other.fontSize == fontSize &&
      other.title == title &&
      other.cancelText == cancelText;

  @override
  int get hashCode =>
      Object.hash(backgroundColor, textColor, fontSize, title, cancelText);
}

/// Style of the challenge screen buttons.
@immutable
class ChallengeButtonStyle {
  /// Creates a button style; unset properties keep the SDK default.
  const ChallengeButtonStyle({
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.cornerRadius,
  });

  /// Button background.
  final Color? backgroundColor;

  /// Button label color.
  final Color? textColor;

  /// Button label size.
  final double? fontSize;

  /// Button corner radius. On iOS this radius is shared with the input field, and the
  /// button value wins when both are set.
  final double? cornerRadius;

  @override
  bool operator ==(Object other) =>
      other is ChallengeButtonStyle &&
      other.backgroundColor == backgroundColor &&
      other.textColor == textColor &&
      other.fontSize == fontSize &&
      other.cornerRadius == cornerRadius;

  @override
  int get hashCode =>
      Object.hash(backgroundColor, textColor, fontSize, cornerRadius);
}

/// Style of the challenge screen texts.
@immutable
class ChallengeLabelStyle {
  /// Creates a label style; unset properties keep the SDK default.
  const ChallengeLabelStyle({
    this.textColor,
    this.fontSize,
    this.headingTextColor,
    this.headingFontSize,
  });

  /// Color of normal text.
  final Color? textColor;

  /// Size of normal text.
  final double? fontSize;

  /// Color of headings.
  final Color? headingTextColor;

  /// Size of headings.
  final double? headingFontSize;

  @override
  bool operator ==(Object other) =>
      other is ChallengeLabelStyle &&
      other.textColor == textColor &&
      other.fontSize == fontSize &&
      other.headingTextColor == headingTextColor &&
      other.headingFontSize == headingFontSize;

  @override
  int get hashCode =>
      Object.hash(textColor, fontSize, headingTextColor, headingFontSize);
}

/// Style of the field the payer types the challenge code into.
@immutable
class ChallengeTextBoxStyle {
  /// Creates an input field style; unset properties keep the SDK default.
  const ChallengeTextBoxStyle({
    this.textColor,
    this.fontSize,
    this.borderColor,
    this.borderWidth,
    this.cornerRadius,
  });

  /// Color of the typed text. On iOS this also sets the general text color when
  /// [ChallengeLabelStyle.textColor] is not given.
  final Color? textColor;

  /// Size of the typed text.
  final double? fontSize;

  /// Border color of the field.
  final Color? borderColor;

  /// Border width of the field.
  final double? borderWidth;

  /// Corner radius of the field. On iOS this radius is shared with the buttons.
  final double? cornerRadius;

  @override
  bool operator ==(Object other) =>
      other is ChallengeTextBoxStyle &&
      other.textColor == textColor &&
      other.fontSize == fontSize &&
      other.borderColor == borderColor &&
      other.borderWidth == borderWidth &&
      other.cornerRadius == cornerRadius;

  @override
  int get hashCode =>
      Object.hash(textColor, fontSize, borderColor, borderWidth, cornerRadius);
}

/// Challenge customization supported by the Android SDK only. Ignored on iOS.
@immutable
class AndroidChallengeCustomization {
  /// Creates Android-only customization.
  const AndroidChallengeCustomization({this.buttonStyles = const {}});

  /// Per-button overrides of [ChallengeUiCustomization.button].
  final Map<ChallengeButtonType, ChallengeButtonStyle> buttonStyles;

  @override
  bool operator ==(Object other) =>
      other is AndroidChallengeCustomization &&
      mapEquals(other.buttonStyles, buttonStyles);

  @override
  int get hashCode => Object.hashAllUnordered(
    buttonStyles.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );
}

/// Challenge customization supported by the iOS SDK only. Ignored on Android.
@immutable
class IosChallengeCustomization {
  /// Creates iOS-only customization.
  const IosChallengeCustomization({
    this.primaryBackgroundColor,
    this.secondaryBackgroundColor,
    this.labelBackgroundColor,
    this.tintColor,
    this.navigationBarTintColor,
    this.cancelTextColor,
    this.keyboardAppearance,
    this.appearance,
  });

  /// Background of the challenge screen.
  final Color? primaryBackgroundColor;

  /// Background of secondary views such as text fields.
  final Color? secondaryBackgroundColor;

  /// Background behind labels.
  final Color? labelBackgroundColor;

  /// Tint color of controls such as the text cursor.
  final Color? tintColor;

  /// Tint color of the navigation bar items.
  final Color? navigationBarTintColor;

  /// Color of the cancel text.
  final Color? cancelTextColor;

  /// Keyboard appearance used by the challenge input.
  final ChallengeKeyboardAppearance? keyboardAppearance;

  /// Light or dark appearance of the challenge screen.
  final ChallengeAppearance? appearance;

  @override
  bool operator ==(Object other) =>
      other is IosChallengeCustomization &&
      other.primaryBackgroundColor == primaryBackgroundColor &&
      other.secondaryBackgroundColor == secondaryBackgroundColor &&
      other.labelBackgroundColor == labelBackgroundColor &&
      other.tintColor == tintColor &&
      other.navigationBarTintColor == navigationBarTintColor &&
      other.cancelTextColor == cancelTextColor &&
      other.keyboardAppearance == keyboardAppearance &&
      other.appearance == appearance;

  @override
  int get hashCode => Object.hash(
    primaryBackgroundColor,
    secondaryBackgroundColor,
    labelBackgroundColor,
    tintColor,
    navigationBarTintColor,
    cancelTextColor,
    keyboardAppearance,
    appearance,
  );
}
