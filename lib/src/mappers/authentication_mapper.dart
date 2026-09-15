import '../generated/payment_api.g.dart';
import '../models/authentication.dart';
import '../models/payment_session.dart';
import 'challenge_ui_mapper.dart';
import 'session_mapper.dart';

AuthenticateRequestMessage toAuthenticateRequestMessage(
  PaymentSession session, {
  required String authenticationTransactionId,
  AuthenticationOptions? options,
}) {
  final iosOptions = options?.ios;
  final iosChallengeUi = iosOptions?.challengeUi;
  return AuthenticateRequestMessage(
    session: toSessionMessage(session),
    authenticationTransactionId: authenticationTransactionId,
    authenticatePayerFields: toGatewayFieldMessages(
      options?.authenticatePayerFields,
    ),
    ios: iosOptions == null
        ? null
        : IosAuthenticationOptionsMessage(
            challengeUi: iosChallengeUi == null
                ? null
                : toChallengeUiMessage(iosChallengeUi),
            challengeLocale: iosOptions.challengeLocale?.toLanguageTag(),
            initiateAuthenticationFields: toGatewayFieldMessages(
              iosOptions.initiateAuthenticationFields,
            ),
          ),
  );
}

AuthenticationResult toAuthenticationResult(
  AuthenticationResultMessage message,
) {
  AuthenticationNotProceeded notProceeded(AuthenticationDeclineReason reason) =>
      AuthenticationNotProceeded(
        reason: reason,
        authenticationTransactionId: message.authenticationTransactionId,
        authenticationPerformed: message.authenticationPerformed,
        challengePerformed: message.challengePerformed,
      );

  return switch (message.outcome) {
    AuthenticationOutcomeMessage.proceed => AuthenticationProceed(
      authenticationTransactionId: message.authenticationTransactionId,
      authenticationPerformed: message.authenticationPerformed,
      challengePerformed: message.challengePerformed,
      sdkTransactionId: message.sdkTransactionId,
      threeDS2TransactionStatus: message.threeDS2TransactionStatus,
    ),
    AuthenticationOutcomeMessage.cancelledByUser => notProceeded(
      AuthenticationDeclineReason.cancelledByUser,
    ),
    AuthenticationOutcomeMessage.challengeTimedOut => notProceeded(
      AuthenticationDeclineReason.challengeTimedOut,
    ),
    AuthenticationOutcomeMessage.resubmitWithAlternativePaymentDetails =>
      notProceeded(
        AuthenticationDeclineReason.resubmitWithAlternativePaymentDetails,
      ),
    AuthenticationOutcomeMessage.abandonOrder => notProceeded(
      AuthenticationDeclineReason.abandonOrder,
    ),
    AuthenticationOutcomeMessage.doNotProceed => notProceeded(
      AuthenticationDeclineReason.doNotProceed,
    ),
    AuthenticationOutcomeMessage.unknownRecommendation => notProceeded(
      AuthenticationDeclineReason.unknownRecommendation,
    ),
  };
}
