import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/src/generated/payment_api.g.dart';
import 'package:nbe_payment_flutter_plugin/src/mappers/authentication_mapper.dart';
import 'package:nbe_payment_flutter_plugin/src/models/authentication.dart';
import 'package:nbe_payment_flutter_plugin/src/models/challenge_ui_customization.dart';
import 'package:nbe_payment_flutter_plugin/src/models/gateway_fields.dart';
import 'package:nbe_payment_flutter_plugin/src/models/payment_session.dart';

const _session = PaymentSession(
  id: 'SESSION0002',
  orderId: 'ORDER-1',
  amount: '150.00',
  currency: 'EGP',
  apiVersion: '72',
);

AuthenticationResultMessage _resultMessage(
  AuthenticationOutcomeMessage outcome,
) => AuthenticationResultMessage(
  outcome: outcome,
  authenticationPerformed: true,
  challengePerformed: true,
  authenticationTransactionId: 'AUTH-002',
  sdkTransactionId: 'sdk-1',
  threeDS2TransactionStatus: 'Y',
);

void main() {
  group('toAuthenticateRequestMessage', () {
    test('without options sends only session and transaction id', () {
      final message = toAuthenticateRequestMessage(
        _session,
        authenticationTransactionId: 'AUTH-001',
      );

      expect(message.session.id, 'SESSION0002');
      expect(message.authenticationTransactionId, 'AUTH-001');
      expect(message.authenticatePayerFields, isNull);
      expect(message.ios, isNull);
    });

    test('maps shared and iOS-only options', () {
      final message = toAuthenticateRequestMessage(
        _session,
        authenticationTransactionId: 'AUTH-001',
        options: AuthenticationOptions(
          authenticatePayerFields: GatewayFields()
            ..setString('customer.email', 'a@b.c'),
          ios: IosAuthenticationOptions(
            challengeUi: const ChallengeUiCustomization(
              regularFontName: 'Cairo',
            ),
            challengeLocale: const Locale('en'),
            initiateAuthenticationFields: GatewayFields()
              ..setBool('flag', true),
          ),
        ),
      );

      expect(message.authenticatePayerFields!.single.key, 'customer.email');
      expect(message.ios!.challengeUi!.regularFontName, 'Cairo');
      expect(message.ios!.challengeLocale, 'en');
      expect(
        message.ios!.initiateAuthenticationFields!.single.boolValue,
        isTrue,
      );
    });
  });

  group('toAuthenticationResult', () {
    test('proceed keeps every field, including iOS-only ones', () {
      final result = toAuthenticationResult(
        _resultMessage(AuthenticationOutcomeMessage.proceed),
      );

      expect(result, isA<AuthenticationProceed>());
      final proceed = result as AuthenticationProceed;
      expect(proceed.authenticationTransactionId, 'AUTH-002');
      expect(proceed.authenticationPerformed, isTrue);
      expect(proceed.challengePerformed, isTrue);
      expect(proceed.sdkTransactionId, 'sdk-1');
      expect(proceed.threeDS2TransactionStatus, 'Y');
    });

    const declineReasons = {
      AuthenticationOutcomeMessage.cancelledByUser:
          AuthenticationDeclineReason.cancelledByUser,
      AuthenticationOutcomeMessage.challengeTimedOut:
          AuthenticationDeclineReason.challengeTimedOut,
      AuthenticationOutcomeMessage.resubmitWithAlternativePaymentDetails:
          AuthenticationDeclineReason.resubmitWithAlternativePaymentDetails,
      AuthenticationOutcomeMessage.abandonOrder:
          AuthenticationDeclineReason.abandonOrder,
      AuthenticationOutcomeMessage.doNotProceed:
          AuthenticationDeclineReason.doNotProceed,
      AuthenticationOutcomeMessage.unknownRecommendation:
          AuthenticationDeclineReason.unknownRecommendation,
    };

    test('every non-proceed outcome has a decline reason', () {
      final nonProceedOutcomes = AuthenticationOutcomeMessage.values.where(
        (outcome) => outcome != AuthenticationOutcomeMessage.proceed,
      );
      expect(declineReasons.keys, unorderedEquals(nonProceedOutcomes));
      expect(
        declineReasons.values,
        unorderedEquals(AuthenticationDeclineReason.values),
      );
    });

    for (final entry in declineReasons.entries) {
      test(
        '${entry.key.name} maps to not proceeded with ${entry.value.name}',
        () {
          final result = toAuthenticationResult(_resultMessage(entry.key));

          expect(result, isA<AuthenticationNotProceeded>());
          final notProceeded = result as AuthenticationNotProceeded;
          expect(notProceeded.reason, entry.value);
          expect(notProceeded.authenticationTransactionId, 'AUTH-002');
          expect(notProceeded.authenticationPerformed, isTrue);
          expect(notProceeded.challengePerformed, isTrue);
        },
      );
    }
  });
}
