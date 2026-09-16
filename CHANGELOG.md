# Changelog

All notable changes to this plugin. Versions follow [Semantic Versioning](https://semver.org);
see "Versioning" in the README.

## 0.1.0 — 2026-09-17

Adds the saved-card flow. First tagged version; apps pin this tag.

Bundled: unchanged from 0.0.1 (Android SDK 2.0.17, iOS SDK 2.0.14, Pigeon 27.3.0).

Added:

- `NbePaymentGateway.updateSessionWithSecurityCode(session, securityCode, {additionalFields})`:
  puts only `sourceOfFunds.provided.card.securityCode` into a session that already holds a card
  saved by the merchant server. No other `sourceOfFunds` field is sent, so the stored card is
  left untouched. It runs under the same one-operation lock, validation and error mapping as
  `updateSessionWithCard`.
- A "Saved card (CVV only)" action in the example app and an integration test for the path.

Changed (breaking):

- `CardDetails.securityCode` is now required. The gateway refuses a card payment without a
  security code, so an absent one could only fail later, on the server's PAY. A card saved by
  the server no longer needs a placeholder here: use `updateSessionWithSecurityCode`.

Status:

- Android: the new call is covered by JVM unit tests and the Flutter integration tests; not yet
  run against a real session holding a saved card.
- iOS: written symmetrically with Android, still never compiled.

## 0.0.1 — internal, never tagged

First internal version.

Bundled:

- Mastercard Gateway Android SDK 2.0.17 (Gateway 3DS SDK 6.7.60)
- Mastercard Gateway iOS SDK 2.0.14 (mSignia uSDK 6.7.63)
- Pigeon 27.3.0

Added:

- `NbePaymentGateway` with `initialize`, `updateSessionWithCard`, `authenticatePayer`,
  `getAvailableWallet` and `payWithDeviceWallet`.
- Google Pay (Android) and Apple Pay (iOS) behind one device wallet API.
- 3-D Secure challenge screen customization with shared, Android-only and iOS-only styles.
- Typed results for payment outcomes and `GatewayException` with stable error codes.
- One-operation-at-a-time protection in Dart and native code.
- Suppression of the Android SDK's HTTP body logging (card data in logcat).
- R8 consumer rules required for release builds with the Android SDK.

Status:

- Android: verified on an emulator, in debug and release builds, including a real MTF card
  update, 3-D Secure authentication and server-side Authorize/Capture.
- iOS: implemented, not yet compiled or verified on a Mac.
- Google Pay and Apple Pay sheets: not yet verified on configured devices.
