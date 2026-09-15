import '../generated/payment_api.g.dart';
import '../models/gateway_configuration.dart';
import 'challenge_ui_mapper.dart';

// Wallet settings are not part of the initialize message: the Dart layer keeps the
// configuration and attaches them to each wallet request instead.
InitializeRequestMessage toInitializeRequestMessage(
  GatewayConfiguration configuration,
) {
  final challengeUi = configuration.challengeUi;
  return InitializeRequestMessage(
    merchantId: configuration.merchantId,
    merchantName: configuration.merchantName,
    merchantUrl: configuration.merchantUrl,
    region: configuration.region,
    challengeLocale: configuration.challengeLocale?.toLanguageTag(),
    challengeUi: challengeUi == null ? null : toChallengeUiMessage(challengeUi),
  );
}
