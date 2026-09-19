# Idiomatic Dart Errors and Public API Documentation

## Goal

Expose the plugin through ordinary Dart `Future<T>` APIs: successful operations return their
natural value, while technical and integration failures complete the future with a public,
typed `GatewayException`. Document every operation well enough that a Flutter developer can
choose an appropriate payer-facing message without exposing sensitive diagnostics.

## Public contract

`NbePaymentGateway` has these signatures:

```dart
Future<void> initialize(GatewayConfiguration configuration);

Future<void> updateSessionWithCard(
  PaymentSession session,
  CardDetails card, {
  GatewayFields? additionalFields,
});

Future<void> updateSessionWithSecurityCode(
  PaymentSession session,
  String securityCode, {
  GatewayFields? additionalFields,
});

Future<AuthenticationResult> authenticatePayer(
  PaymentSession session, {
  String? authenticationTransactionId,
  AuthenticationOptions? options,
});

Future<DeviceWallet> getAvailableWallet(WalletPaymentRequest request);

Future<WalletPaymentResult> payWithDeviceWallet(
  PaymentSession session,
  WalletPaymentRequest request,
);
```

`GatewayException` is exported. It keeps the stable `GatewayErrorCode` plus the typed gateway
rejection metadata introduced for 0.2.0: `httpStatusCode`, `cause`, `field`,
`validationType`, and sanitized `nativeDetails`.

`GatewayResult`, `GatewaySuccess`, and `GatewayFailure` are removed. Version 0.2.0 remains a
minor release over 0.1.1: the established exception-based call style is preserved, while typed
gateway rejection details and saved-card support are added.

## Outcome versus failure

An operation that reached a trustworthy business outcome returns normally:

- `AuthenticationProceed`: 3DS recommends continuing to the server-side payment.
- `AuthenticationNotProceeded`: cancellation, timeout, or a Mastercard recommendation not to
  continue.
- `WalletPaymentCompleted`: the gateway session now holds the wallet payment token.
- `WalletPaymentCancelled`: the payer closed the wallet sheet.
- `DeviceWallet.none`: the availability check completed and no supported wallet is available.

An operation that could not produce a trustworthy outcome throws `GatewayException`. Examples
include input validation, missing initialization, concurrency conflicts, network failures,
gateway HTTP rejection, malformed responses, unavailable UI, and wallet integration failures.
Unexpected non-`GatewayException` errors remain plugin bugs and must not be converted to a
payment outcome.

## UI and message contract

The plugin does not display payer-facing error messages. `GatewayException.message` and
`nativeDetails` are English developer diagnostics and must never be shown directly. Host apps
branch on `code`, and for `gatewayRejected` may additionally branch on `field` and
`validationType`.

Documentation supplies recommended UX by operation:

- Initialization/configuration failures: payment unavailable, with retry only for transient
  failures.
- Card and saved-card updates: field-level card number, expiry, or security-code messages when
  `field` identifies one; otherwise a retry or generic preparation failure.
- Authentication outcomes: cancellation and timeout are normal `AuthenticationNotProceeded`
  values; network/UI/gateway problems are exceptions. Apps must query their backend before an
  unsafe retry when the final transaction state may be uncertain.
- Wallet availability: `none` and most availability failures hide the wallet button and retain
  card payment rather than showing a disruptive dialog.
- Wallet payment: cancellation is a normal result; wallet, UI, network, or gateway failures
  offer retry or an alternative payment method as appropriate.
- `operationInProgress` should normally be prevented by disabling the initiating control.
- `unknown` produces generic copy and sanitized logging.

The docs include a centralized application-side mapper example while emphasizing that copy and
localization belong to the consuming app, not the plugin.

## Validation behavior

Validation performed inside gateway methods completes their returned future with
`GatewayException`. `GatewayFields` setters remain synchronous builders and can reject malformed
or reserved keys immediately with the same public exception type; this distinction is explicitly
documented.

## Security

No payer-facing text or log example prints card data, CVV, wallet tokens, raw gateway bodies, or
untrusted native messages. `message` is for developers, `nativeDetails` is for sanitized logs,
and apps localize their own safe copy from stable enums and field constants.

## Compatibility and verification

- Keep Dart SDK `^3.6.0` and Flutter `>=3.27.0` compatibility.
- Preserve the Pigeon/native rejection-field transport already implemented for Android and iOS.
- Update Dart unit tests first and observe them fail against the `GatewayResult` API.
- Update the example and integration tests to demonstrate `try/on GatewayException`.
- Run analyzer, all Dart tests, Android JVM tests, and the Flutter 3.27 compatibility checks.
- iOS device/build, wallet device flows, OTP challenge, and saved-card end-to-end validation
  remain explicit release gates because this Windows machine cannot complete them.
