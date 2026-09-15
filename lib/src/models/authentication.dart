import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show immutable;

import 'challenge_ui_customization.dart';
import 'gateway_fields.dart';

/// Optional settings for a single payer authentication.
@immutable
class AuthenticationOptions {
  const AuthenticationOptions({this.authenticatePayerFields, this.ios});

  /// Extra gateway fields sent with the authenticate-payer request.
  final GatewayFields? authenticatePayerFields;

  /// Options supported by the iOS SDK only. Ignored on Android.
  final IosAuthenticationOptions? ios;
}

/// Authentication options that only the iOS SDK supports. Ignored on Android.
@immutable
class IosAuthenticationOptions {
  const IosAuthenticationOptions({
    this.challengeUi,
    this.challengeLocale,
    this.initiateAuthenticationFields,
  });

  /// Overrides the challenge appearance set in `GatewayConfiguration` for this attempt.
  final ChallengeUiCustomization? challengeUi;

  /// Overrides the challenge language set in `GatewayConfiguration` for this attempt.
  final Locale? challengeLocale;

  /// Extra gateway fields sent with the initiate-authentication request.
  final GatewayFields? initiateAuthenticationFields;
}

/// Outcome of a payer authentication (3-D Secure).
///
/// Both variants are normal payment outcomes. Technical failures are thrown as
/// `GatewayException` instead.
@immutable
sealed class AuthenticationResult {
  const AuthenticationResult({
    required this.authenticationTransactionId,
    required this.authenticationPerformed,
    required this.challengePerformed,
  });

  /// Identifier of this authentication attempt. The merchant server must send it with
  /// the Pay / Authorize request so the gateway can attach this authentication.
  final String authenticationTransactionId;

  /// `false` when 3DS authentication was not available for the card.
  final bool authenticationPerformed;

  /// `true` when the payer had to complete a challenge (e.g. enter an OTP);
  /// `false` for a frictionless authentication.
  final bool challengePerformed;
}

/// The gateway recommends continuing with the payment.
final class AuthenticationProceed extends AuthenticationResult {
  const AuthenticationProceed({
    required super.authenticationTransactionId,
    required super.authenticationPerformed,
    required super.challengePerformed,
    this.sdkTransactionId,
    this.threeDS2TransactionStatus,
  });

  /// Reported by the iOS SDK only; always `null` on Android.
  final String? sdkTransactionId;

  /// Reported by the iOS SDK only; always `null` on Android.
  final String? threeDS2TransactionStatus;
}

/// The payment must not continue with this authentication.
final class AuthenticationNotProceeded extends AuthenticationResult {
  const AuthenticationNotProceeded({
    required this.reason,
    required super.authenticationTransactionId,
    required super.authenticationPerformed,
    required super.challengePerformed,
  });

  final AuthenticationDeclineReason reason;
}

enum AuthenticationDeclineReason {
  /// The payer closed the challenge screen.
  cancelledByUser,

  /// The payer did not complete the challenge in time.
  challengeTimedOut,

  /// Ask the payer for another card or payment method, then retry with a new session update.
  resubmitWithAlternativePaymentDetails,

  /// The issuer, scheme or payment provider requires abandoning the order.
  abandonOrder,

  /// Authentication failed and this transaction cannot succeed.
  doNotProceed,

  /// The gateway returned a recommendation this plugin version does not recognize.
  unknownRecommendation,
}
