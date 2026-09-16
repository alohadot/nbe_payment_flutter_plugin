import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show immutable;

import '../generated/payment_api.g.dart' show GatewayRegion;
import 'challenge_ui_customization.dart';

/// Settings the native SDK is initialized with, once per app process.
@immutable
class GatewayConfiguration {
  /// Creates a configuration. [merchantId] and [region] must match the merchant the sessions
  /// are created for.
  const GatewayConfiguration({
    required this.merchantId,
    required this.merchantName,
    required this.merchantUrl,
    required this.region,
    this.challengeLocale,
    this.challengeUi,
    this.wallet,
  });

  /// Gateway merchant ID, e.g. `TESTMERCHANT01`.
  final String merchantId;

  /// Used by the Android SDK only; ignored on iOS.
  final String merchantName;

  /// Used by the Android SDK only; ignored on iOS.
  final String merchantUrl;

  /// Gateway data center of the merchant account. `GatewayRegion.mtf` is the test
  /// environment.
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

  // Value equality lets `initialize` treat a repeated call with the same configuration
  // as a no-op instead of an error.
  @override
  bool operator ==(Object other) =>
      other is GatewayConfiguration &&
      other.merchantId == merchantId &&
      other.merchantName == merchantName &&
      other.merchantUrl == merchantUrl &&
      other.region == region &&
      other.challengeLocale == challengeLocale &&
      other.challengeUi == challengeUi &&
      other.wallet == wallet;

  @override
  int get hashCode => Object.hash(
    merchantId,
    merchantName,
    merchantUrl,
    region,
    challengeLocale,
    challengeUi,
    wallet,
  );
}

/// Merchant identifiers required by the device wallets.
@immutable
class WalletConfiguration {
  /// Creates wallet settings; each identifier is used by its own platform.
  const WalletConfiguration({
    this.googlePayMerchantId,
    this.applePayMerchantIdentifier,
  });

  /// Google Pay merchant ID from the Google Pay & Wallet Console. Android only.
  /// Not needed in the test environment.
  final String? googlePayMerchantId;

  /// Apple Pay merchant identifier, e.g. `merchant.com.example.store`. iOS only.
  final String? applePayMerchantIdentifier;

  @override
  bool operator ==(Object other) =>
      other is WalletConfiguration &&
      other.googlePayMerchantId == googlePayMerchantId &&
      other.applePayMerchantIdentifier == applePayMerchantIdentifier;

  @override
  int get hashCode =>
      Object.hash(googlePayMerchantId, applePayMerchantIdentifier);
}
