import 'dart:ui' show Color;

import '../generated/payment_api.g.dart';
import '../models/challenge_ui_customization.dart';

/// Converts the public challenge customization to the transport message, with colors as
/// 32-bit ARGB integers.
ChallengeUiMessage toChallengeUiMessage(
  ChallengeUiCustomization customization,
) {
  final iosCustomization = customization.ios;
  return ChallengeUiMessage(
    toolbar: _toToolbarMessage(customization.toolbar),
    button: _toButtonMessage(customization.button),
    label: _toLabelMessage(customization.label),
    textBox: _toTextBoxMessage(customization.textBox),
    regularFontName: customization.regularFontName,
    headingFontName: customization.headingFontName,
    androidButtonStyles: customization.android?.buttonStyles.entries
        .map(
          (entry) => AndroidButtonStyleMessage(
            type: entry.key,
            style: _toButtonMessage(entry.value)!,
          ),
        )
        .toList(),
    ios: iosCustomization == null
        ? null
        : IosChallengeUiMessage(
            primaryBackgroundColor: _toArgb(
              iosCustomization.primaryBackgroundColor,
            ),
            secondaryBackgroundColor: _toArgb(
              iosCustomization.secondaryBackgroundColor,
            ),
            labelBackgroundColor: _toArgb(
              iosCustomization.labelBackgroundColor,
            ),
            tintColor: _toArgb(iosCustomization.tintColor),
            navigationBarTintColor: _toArgb(
              iosCustomization.navigationBarTintColor,
            ),
            cancelTextColor: _toArgb(iosCustomization.cancelTextColor),
            keyboardAppearance: iosCustomization.keyboardAppearance,
            appearance: iosCustomization.appearance,
          ),
  );
}

ToolbarStyleMessage? _toToolbarMessage(ChallengeToolbarStyle? style) =>
    style == null
    ? null
    : ToolbarStyleMessage(
        backgroundColor: _toArgb(style.backgroundColor),
        textColor: _toArgb(style.textColor),
        fontSize: style.fontSize,
        title: style.title,
        cancelText: style.cancelText,
      );

ButtonStyleMessage? _toButtonMessage(ChallengeButtonStyle? style) =>
    style == null
    ? null
    : ButtonStyleMessage(
        backgroundColor: _toArgb(style.backgroundColor),
        textColor: _toArgb(style.textColor),
        fontSize: style.fontSize,
        cornerRadius: style.cornerRadius,
      );

LabelStyleMessage? _toLabelMessage(ChallengeLabelStyle? style) => style == null
    ? null
    : LabelStyleMessage(
        textColor: _toArgb(style.textColor),
        fontSize: style.fontSize,
        headingTextColor: _toArgb(style.headingTextColor),
        headingFontSize: style.headingFontSize,
      );

TextBoxStyleMessage? _toTextBoxMessage(ChallengeTextBoxStyle? style) =>
    style == null
    ? null
    : TextBoxStyleMessage(
        textColor: _toArgb(style.textColor),
        fontSize: style.fontSize,
        borderColor: _toArgb(style.borderColor),
        borderWidth: style.borderWidth,
        cornerRadius: style.cornerRadius,
      );

// Built from the channel components instead of Color.toARGB32(), which does not exist in
// Flutter 3.27, the oldest version this plugin supports. The components are doubles in 0..1;
// the gateway SDKs expect an 8-bit channel each, alpha first.
int _channel(double value) => (value * 255).round() & 0xff;

int? _toArgb(Color? color) => color == null
    ? null
    : _channel(color.a) << 24 |
          _channel(color.r) << 16 |
          _channel(color.g) << 8 |
          _channel(color.b);
