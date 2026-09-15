import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable;

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

  final ChallengeToolbarStyle? toolbar;
  final ChallengeButtonStyle? button;
  final ChallengeLabelStyle? label;
  final ChallengeTextBoxStyle? textBox;
  final String? regularFontName;
  final String? headingFontName;
  final AndroidChallengeCustomization? android;
  final IosChallengeCustomization? ios;
}

@immutable
class ChallengeToolbarStyle {
  const ChallengeToolbarStyle({
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.title,
    this.cancelText,
  });

  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final String? title;
  final String? cancelText;
}

@immutable
class ChallengeButtonStyle {
  const ChallengeButtonStyle({
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.cornerRadius,
  });

  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final double? cornerRadius;
}

@immutable
class ChallengeLabelStyle {
  const ChallengeLabelStyle({
    this.textColor,
    this.fontSize,
    this.headingTextColor,
    this.headingFontSize,
  });

  final Color? textColor;
  final double? fontSize;
  final Color? headingTextColor;
  final double? headingFontSize;
}

@immutable
class ChallengeTextBoxStyle {
  const ChallengeTextBoxStyle({
    this.textColor,
    this.fontSize,
    this.borderColor,
    this.borderWidth,
    this.cornerRadius,
  });

  final Color? textColor;
  final double? fontSize;
  final Color? borderColor;
  final double? borderWidth;
  final double? cornerRadius;
}

/// Challenge customization supported by the Android SDK only. Ignored on iOS.
@immutable
class AndroidChallengeCustomization {
  const AndroidChallengeCustomization({this.buttonStyles = const {}});

  /// Per-button overrides of [ChallengeUiCustomization.button].
  final Map<ChallengeButtonType, ChallengeButtonStyle> buttonStyles;
}

/// Challenge customization supported by the iOS SDK only. Ignored on Android.
@immutable
class IosChallengeCustomization {
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

  final Color? primaryBackgroundColor;

  /// Background of secondary views such as text fields.
  final Color? secondaryBackgroundColor;

  final Color? labelBackgroundColor;
  final Color? tintColor;
  final Color? navigationBarTintColor;
  final Color? cancelTextColor;
  final ChallengeKeyboardAppearance? keyboardAppearance;
  final ChallengeAppearance? appearance;
}
