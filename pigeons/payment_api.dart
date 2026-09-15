// Contract between the Dart layer of nbe_payment_flutter_plugin and its Android/iOS
// implementations. This is the single source of truth for everything that crosses the
// platform channel; the Dart, Kotlin and Swift files are generated from it.
//
// Regenerate after any change, from the package root:
//   dart run pigeon --input pigeons/payment_api.dart
// Never edit the generated files by hand.
//
// Rules for this file:
// - Types here are transport messages, not the public API. Every name ends with `Message`
//   and is mapped to/from public models in lib/src/mappers/.
// - Business outcomes (user cancelled, issuer declined) travel inside result messages.
//   Only technical failures are sent as channel errors, using the error codes below.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'nbe_payment_flutter_plugin',
    dartOut: 'lib/src/generated/payment_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/example/nbe_payment_flutter_plugin/generated/PaymentApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.example.nbe_payment_flutter_plugin.generated',
      errorClassName: 'GatewayBridgeError',
    ),
    swiftOut: 'ios/Classes/Generated/PaymentApi.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'GatewayBridgeError'),
  ),
)

// ---------------------------------------------------------------------------
// Channel error codes
// ---------------------------------------------------------------------------
// Native adapters must convert every failure into one of these codes. Uncaught native
// exceptions would otherwise reach Dart with a stack trace in `details`, which can leak
// internals, so adapters never let raw exceptions escape.

const String errorCodeNotInitialized = 'not_initialized';
const String errorCodeAlreadyInitialized = 'already_initialized';
const String errorCodeInitializationFailed = 'initialization_failed';
const String errorCodeOperationInProgress = 'operation_in_progress';
const String errorCodeInvalidArgument = 'invalid_argument';
const String errorCodeInvalidApiVersion = 'invalid_api_version';
const String errorCodeMissingSessionParameter = 'missing_session_parameter';
const String errorCodeNetwork = 'network';
const String errorCodeGatewayRejected = 'gateway_rejected';
const String errorCodeInvalidGatewayResponse = 'invalid_gateway_response';
const String errorCodeInvalidChallengeCompletionUrl =
    'invalid_challenge_completion_url';
const String errorCodeUiUnavailable = 'ui_unavailable';
const String errorCodeWalletUnavailable = 'wallet_unavailable';
const String errorCodeWalletConfigurationInvalid =
    'wallet_configuration_invalid';
const String errorCodeWalletFailed = 'wallet_failed';
const String errorCodeUnknown = 'unknown';

// Keys of the map sent as the channel error's `details`.
const String errorDetailsHttpStatusCode = 'httpStatusCode';
const String errorDetailsNative = 'nativeDetails';

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------

enum RegionMessage {
  mtf,
  europe,
  northAmerica,
  asiaPacific,
  india,
  china,
  saudiArabia,
}

class InitializeRequestMessage {
  InitializeRequestMessage({
    required this.merchantId,
    required this.merchantName,
    required this.merchantUrl,
    required this.region,
  });

  String merchantId;

  /// Used by the Android SDK only.
  String merchantName;

  /// Used by the Android SDK only.
  String merchantUrl;

  RegionMessage region;

  /// BCP-47 language tag for the 3DS challenge screen. Used by the iOS SDK only;
  /// the Android SDK always follows the device language.
  String? challengeLocale;

  ChallengeUiMessage? challengeUi;
}

// ---------------------------------------------------------------------------
// Session and card
// ---------------------------------------------------------------------------

class SessionMessage {
  SessionMessage({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.apiVersion,
  });

  String id;
  String orderId;

  /// Decimal string, e.g. "150.00". Kept as text to avoid floating-point rounding.
  String amount;

  String currency;
  String apiVersion;
}

/// Carries raw card data. Native code must use it only to build the update-session
/// payload and must never log it or keep a reference after the call.
class CardMessage {
  CardMessage({
    required this.number,
    required this.expiryMonth,
    required this.expiryYear,
  });

  String number;
  String? securityCode;
  String expiryMonth;
  String expiryYear;
  String? nameOnCard;
}

/// One gateway API field in dot notation (e.g. "billing.address.city").
/// Exactly one of the value fields is set. A list of these replaces a heterogeneous map,
/// which the channel cannot type safely.
class GatewayFieldMessage {
  GatewayFieldMessage({required this.key});

  String key;
  String? stringValue;
  int? intValue;
  double? doubleValue;
  bool? boolValue;
}

// ---------------------------------------------------------------------------
// 3DS authentication
// ---------------------------------------------------------------------------

class AuthenticateRequestMessage {
  AuthenticateRequestMessage({
    required this.session,
    required this.authenticationTransactionId,
  });

  SessionMessage session;

  /// Generated on the Dart side when the app does not provide one.
  String authenticationTransactionId;

  List<GatewayFieldMessage>? authenticatePayerFields;

  /// Ignored on Android.
  IosAuthenticationOptionsMessage? ios;
}

class IosAuthenticationOptionsMessage {
  ChallengeUiMessage? challengeUi;
  String? challengeLocale;
  List<GatewayFieldMessage>? initiateAuthenticationFields;
}

enum AuthenticationOutcomeMessage {
  proceed,
  cancelledByUser,
  challengeTimedOut,
  resubmitWithAlternativePaymentDetails,
  abandonOrder,
  doNotProceed,
  unknownRecommendation,
}

class AuthenticationResultMessage {
  AuthenticationResultMessage({
    required this.outcome,
    required this.authenticationPerformed,
    required this.challengePerformed,
    required this.authenticationTransactionId,
  });

  AuthenticationOutcomeMessage outcome;
  bool authenticationPerformed;
  bool challengePerformed;
  String authenticationTransactionId;

  /// iOS only; always null on Android.
  String? sdkTransactionId;

  /// iOS only; always null on Android.
  String? threeDS2TransactionStatus;
}

// ---------------------------------------------------------------------------
// Device wallet (Google Pay on Android, Apple Pay on iOS)
// ---------------------------------------------------------------------------

enum DeviceWalletMessage { googlePay, applePay, none }

enum CardNetworkMessage { visa, mastercard, amex, discover, jcb }

class WalletRequestMessage {
  WalletRequestMessage({
    required this.merchantDisplayName,
    required this.countryCode,
    required this.supportedNetworks,
    required this.isTestEnvironment,
  });

  /// Null when only checking wallet availability.
  SessionMessage? session;

  String merchantDisplayName;

  /// ISO 3166-1 alpha-2, e.g. "EG".
  String countryCode;

  List<CardNetworkMessage> supportedNetworks;

  /// Selects the Google Pay TEST environment on Android.
  bool isTestEnvironment;

  /// Android only.
  String? googlePayMerchantId;

  /// iOS only, e.g. "merchant.com.example.store".
  String? applePayMerchantIdentifier;
}

enum WalletOutcomeMessage { completed, cancelled }

class WalletResultMessage {
  WalletResultMessage({required this.outcome, required this.wallet});

  WalletOutcomeMessage outcome;
  DeviceWalletMessage wallet;

  /// Display-only description such as "Visa ••••1234". Never the wallet token.
  String? cardDescription;
}

// ---------------------------------------------------------------------------
// 3DS challenge screen customization
// ---------------------------------------------------------------------------
// Colors are 32-bit ARGB integers; each platform converts them to its own color type.

class ChallengeUiMessage {
  ToolbarStyleMessage? toolbar;
  ButtonStyleMessage? button;
  LabelStyleMessage? label;
  TextBoxStyleMessage? textBox;

  /// Font names must be registered natively (system fonts or fonts bundled in the host
  /// app's native project). Fonts declared only in Flutter assets are not visible here.
  String? regularFontName;
  String? headingFontName;

  /// Per-button-type overrides. Android only.
  List<AndroidButtonStyleMessage>? androidButtonStyles;

  /// Extra theme properties that exist only in the iOS SDK.
  IosChallengeUiMessage? ios;
}

class ToolbarStyleMessage {
  int? backgroundColor;
  int? textColor;
  double? fontSize;
  String? title;
  String? cancelText;
}

class ButtonStyleMessage {
  int? backgroundColor;
  int? textColor;
  double? fontSize;
  double? cornerRadius;
}

class LabelStyleMessage {
  int? textColor;
  double? fontSize;
  int? headingTextColor;
  double? headingFontSize;
}

class TextBoxStyleMessage {
  int? textColor;
  double? fontSize;
  int? borderColor;
  double? borderWidth;
  double? cornerRadius;
}

enum ChallengeButtonTypeMessage {
  submit,
  continueButton,
  next,
  cancel,
  resend,
  openOutOfBandApp,
  addChoice,
}

class AndroidButtonStyleMessage {
  AndroidButtonStyleMessage({required this.type, required this.style});

  ChallengeButtonTypeMessage type;
  ButtonStyleMessage style;
}

enum ChallengeAppearanceMessage { light, dark }

enum KeyboardAppearanceMessage { systemDefault, light, dark }

class IosChallengeUiMessage {
  int? primaryBackgroundColor;
  int? secondaryBackgroundColor;
  int? labelBackgroundColor;
  int? tintColor;
  int? navigationBarTintColor;
  int? cancelTextColor;
  KeyboardAppearanceMessage? keyboardAppearance;
  ChallengeAppearanceMessage? appearance;
}

// ---------------------------------------------------------------------------
// Host API (Flutter → native)
// ---------------------------------------------------------------------------
// There is no @FlutterApi: neither native SDK emits intermediate events, every operation
// completes with a single result.

@HostApi()
abstract class NbeGatewayHostApi {
  @async
  void initialize(InitializeRequestMessage request);

  @async
  void updateSessionWithCard(
    SessionMessage session,
    CardMessage card,
    List<GatewayFieldMessage>? additionalFields,
  );

  @async
  AuthenticationResultMessage authenticatePayer(
    AuthenticateRequestMessage request,
  );

  @async
  DeviceWalletMessage getAvailableWallet(WalletRequestMessage request);

  @async
  WalletResultMessage payWithDeviceWallet(WalletRequestMessage request);
}
