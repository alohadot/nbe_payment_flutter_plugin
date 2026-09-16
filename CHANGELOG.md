# Changelog

All notable changes to this plugin. Versions follow [Semantic Versioning](https://semver.org);
see "Versioning" in the README.

## 0.0.1 — unreleased

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
