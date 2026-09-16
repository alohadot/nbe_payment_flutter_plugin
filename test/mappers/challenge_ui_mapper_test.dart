import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/src/mappers/challenge_ui_mapper.dart';
import 'package:nbe_payment_flutter_plugin/src/models/challenge_ui_customization.dart';

// The colors sent to the native SDKs are 32-bit ARGB integers built from the channel
// components, because Color.toARGB32() does not exist in Flutter 3.27, the oldest version this
// plugin supports. These tests pin the conversion.
void main() {
  group('color conversion', () {
    // Each case: the color as created by an app, and the integer native code must receive.
    const cases = <String, (Color, int)>{
      'opaque color': (Color(0xFF112233), 0xFF112233),
      'half-transparent white': (Color(0x80FFFFFF), 0x80FFFFFF),
      'fully transparent black': (Color(0x00000000), 0x00000000),
      'opaque white': (Color(0xFFFFFFFF), 0xFFFFFFFF),
      'per-channel values': (Color(0x0A0B0C0D), 0x0A0B0C0D),
    };

    cases.forEach((name, testCase) {
      test('$name survives the round trip', () {
        final (color, expected) = testCase;

        final message = toChallengeUiMessage(
          ChallengeUiCustomization(
            toolbar: ChallengeToolbarStyle(backgroundColor: color),
          ),
        );

        expect(message.toolbar!.backgroundColor, expected);
      });
    });

    test('a color built from channel doubles keeps its 8-bit values', () {
      final message = toChallengeUiMessage(
        ChallengeUiCustomization(
          toolbar: ChallengeToolbarStyle(
            backgroundColor: const Color.from(
              alpha: 1,
              red: 0x11 / 255,
              green: 0x22 / 255,
              blue: 0x33 / 255,
            ),
          ),
        ),
      );

      expect(message.toolbar!.backgroundColor, 0xFF112233);
    });

    test('absent colors stay null', () {
      final message = toChallengeUiMessage(
        const ChallengeUiCustomization(
          toolbar: ChallengeToolbarStyle(title: 'Verify'),
        ),
      );

      expect(message.toolbar!.backgroundColor, isNull);
      expect(message.toolbar!.textColor, isNull);
      expect(message.toolbar!.title, 'Verify');
    });

    test('every color-carrying style is converted', () {
      final message = toChallengeUiMessage(
        const ChallengeUiCustomization(
          button: ChallengeButtonStyle(
            backgroundColor: Color(0xFF112233),
            textColor: Color(0x80FFFFFF),
          ),
          label: ChallengeLabelStyle(
            textColor: Color(0xFF010203),
            headingTextColor: Color(0xFF040506),
          ),
          textBox: ChallengeTextBoxStyle(
            textColor: Color(0xFF070809),
            borderColor: Color(0x0A0B0C0D),
          ),
          ios: IosChallengeCustomization(
            primaryBackgroundColor: Color(0xFF101112),
            tintColor: Color(0x80131415),
          ),
        ),
      );

      expect(message.button!.backgroundColor, 0xFF112233);
      expect(message.button!.textColor, 0x80FFFFFF);
      expect(message.label!.textColor, 0xFF010203);
      expect(message.label!.headingTextColor, 0xFF040506);
      expect(message.textBox!.textColor, 0xFF070809);
      expect(message.textBox!.borderColor, 0x0A0B0C0D);
      expect(message.ios!.primaryBackgroundColor, 0xFF101112);
      expect(message.ios!.tintColor, 0x80131415);
    });
  });
}
