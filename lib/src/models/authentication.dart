import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show immutable;

import 'challenge_ui_customization.dart';
import 'gateway_fields.dart';

/// Optional settings for a single payer authentication.
@immutable
class AuthenticationOptions {
  /// Creates options for one call; everything is optional.
  const AuthenticationOptions({this.authenticatePayerFields, this.ios});

  /// Extra gateway fields sent with the authenticate-payer request.
  final GatewayFields? authenticatePayerFields;

  /// Options supported by the iOS SDK only. Ignored on Android.
  final IosAuthenticationOptions? ios;
}

/// Authentication options that only the iOS SDK supports. Ignored on Android.
@immutable
class IosAuthenticationOptions {
  /// Creates iOS-only options for one call.
  const IosAuthenticationOptions({
    this.challengeUi,
    this.challengeLocale,
    this.initiateAuthenticationFields,
  });

  /// Replaces the challenge appearance set in `GatewayConfiguration` for this attempt.
  ///
  /// It is not merged with the initialization value: the iOS SDK takes a complete theme, so
  /// anything not set here falls back to the SDK default, not to the initialization value.
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
  /// Shared fields of both outcomes.
  const AuthenticationResult({
    required this.authenticationTransactionId,
    required this.authenticationPerformed,
    required this.challengePerformed,
    this.sdkTransactionId,
    this.threeDS2TransactionStatus,
  });

  /// Identifier of this authentication attempt. The merchant server must send it with
  /// the Pay / Authorize request so the gateway can attach this authentication.
  final String authenticationTransactionId;

  /// `false` when 3DS authentication was not available for the card.
  final bool authenticationPerformed;

  /// `true` when the payer had to complete a challenge (e.g. enter an OTP);
  /// `false` for a frictionless authentication.
  final bool challengePerformed;

  /// 3DS SDK transaction identifier. Reported by the iOS SDK only; always `null` on Android.
  final String? sdkTransactionId;

  /// 3DS2 transaction status from the issuer (`Y`, `N`, `U`, `A`, `R`), the most useful
  /// diagnostic for a decline. Reported by the iOS SDK only; always `null` on Android.
  final String? threeDS2TransactionStatus;
}

/// The gateway recommends continuing with the payment.
final class AuthenticationProceed extends AuthenticationResult {
  /// Creates a "continue with the payment" outcome.
  const AuthenticationProceed({
    required super.authenticationTransactionId,
    required super.authenticationPerformed,
    required super.challengePerformed,
    super.sdkTransactionId,
    super.threeDS2TransactionStatus,
  });
}

/// The payment must not continue with this authentication.
final class AuthenticationNotProceeded extends AuthenticationResult {
  /// Creates a "do not continue" outcome with its [reason].
  const AuthenticationNotProceeded({
    required this.reason,
    required super.authenticationTransactionId,
    required super.authenticationPerformed,
    required super.challengePerformed,
    super.sdkTransactionId,
    super.threeDS2TransactionStatus,
  });

  /// Why the payment must not continue.
  final AuthenticationDeclineReason reason;
}

/// Why an authentication ended without permission to continue the payment.
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
