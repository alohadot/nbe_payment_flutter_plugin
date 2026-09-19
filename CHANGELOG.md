# Changelog

All notable changes to this plugin. Versions follow [Semantic Versioning](https://semver.org);
see "Versioning" in the README.

## 0.2.0 — 2026-09-18

Gateway rejections now say what the gateway objected to, while the API keeps ordinary Dart
`Future<T>` return values and typed `GatewayException` failures.

Added:

- `GatewayException.cause`, `.field` and `.validationType`: the gateway's own `error.cause`,
  `error.field` and `error.validationType`, as typed values instead of text buried in
  `nativeDetails`. An app can tell the payer which field to correct without parsing text.
- `GatewayFieldNames` with the card field paths, to compare against `field` without retyping
  them.
- `GatewayRejectionCause` and `GatewayValidationType`.
- iOS also reads those fields now: the SDK hands the response body to `failedRequest`, which the
  plugin previously discarded.
- Complete Flutter integration guidance for every public method, including normal payment
  outcomes, expected error codes, safe field-level feedback, retry cautions and suggested UX.

Unchanged:

- Successful methods return their natural values (`void`, `AuthenticationResult`,
  `DeviceWallet` or `WalletPaymentResult`); technical failures throw `GatewayException`.
- Payer decisions remain normal values: an authentication decline is
  `AuthenticationNotProceeded`, a closed wallet sheet is `WalletPaymentCancelled`, and no
  available wallet is `DeviceWallet.none`.

- `error.explanation` is still never forwarded (free text that can quote a card number), and
  what an issuer decides about the card still comes from the server's PAY response, not from
  the plugin.

## 0.1.1 — 2026-09-17

Fixes the build on Flutter 3.27, the oldest version `pubspec.yaml` allows.

Fixed:

- `challenge_ui_mapper.dart` used `Color.toARGB32()`, which does not exist in Flutter 3.27, so
  any app pinned to it failed to compile. The ARGB integer is now built from the colour's
  channel components, which exist in 3.27 and are not deprecated in newer versions. A unit test
  pins the conversion.
- The example app used `DropdownButtonFormField(initialValue:)`, a parameter renamed after
  Flutter 3.27, and took its `minSdk` from `flutter.minSdkVersion`, which is 21 on that version
  while the plugin needs 24. Its Dart SDK constraint also still said `^3.11.5`, inherited from
  `flutter create`; it now matches the plugin (`^3.6.0`), so the example builds on the oldest
  supported Flutter and can prove that claim.

Verified: `flutter analyze` and all unit tests on Flutter 3.27.4 (Dart 3.6.2) as well as on
3.41.9, plus a debug APK of the example built with 3.27.4.

The plugin's own dev dependencies (Pigeon, flutter_lints 6) still need a newer SDK. They never
reach consuming apps; see "Commands" in `CLAUDE.md`.

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
