import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show immutable;

import '../generated/payment_api.g.dart' show GatewayRegion;
import 'challenge_ui_customization.dart';

@immutable
class GatewayConfiguration {
  const GatewayConfiguration({
    required this.merchantId,
    required this.merchantName,
    required this.merchantUrl,
    required this.region,
    this.challengeLocale,
    this.challengeUi,
    this.wallet,
  });

  final String merchantId;

  /// Used by the Android SDK only; ignored on iOS.
  final String merchantName;

  /// Used by the Android SDK only; ignored on iOS.
  final String merchantUrl;

  final GatewayRegion region;

  /// Language of the 3DS challenge screen. Used on iOS only; Android always follows the
  /// device language.
  final Locale? challengeLocale;

  /// Appearance of the 3DS challenge screen.
  final ChallengeUiCustomization? challengeUi;

  /// Required only when using device wallet payments.
  final WalletConfiguration? wallet;

  /// Whether this configuration points to the test environment.
  bool get isTestEnvironment => region == GatewayRegion.mtf;
}

@immutable
class WalletConfiguration {
  const WalletConfiguration({
    this.googlePayMerchantId,
    this.applePayMerchantIdentifier,
  });

  /// Google Pay merchant ID from the Google Pay & Wallet Console. Android only.
  /// Not needed in the test environment.
  final String? googlePayMerchantId;

  /// Apple Pay merchant identifier, e.g. `merchant.com.example.store`. iOS only.
  final String? applePayMerchantIdentifier;
}
