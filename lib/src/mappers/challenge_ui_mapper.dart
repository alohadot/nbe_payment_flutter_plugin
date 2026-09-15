import 'dart:ui' show Color;

import '../generated/payment_api.g.dart';
import '../models/challenge_ui_customization.dart';

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

int? _toArgb(Color? color) => color?.toARGB32();
