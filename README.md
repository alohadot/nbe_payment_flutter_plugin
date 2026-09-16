# nbe_payment_flutter_plugin

A Flutter plugin for card payments through the NBE payment gateway, built on the official
Mastercard Gateway (MPGS) native SDKs for Android and iOS.

Flutter code uses one Dart API. It never deals with Kotlin, Swift, Activities, view
controllers, platform channels or the native SDKs.

```dart
final gateway = NbePaymentGateway();
await gateway.initialize(configuration);
await gateway.updateSessionWithCard(session, card);
final result = await gateway.authenticatePayer(session);
```

## Contents

- [What the plugin does](#what-the-plugin-does)
- [Supported platforms and versions](#supported-platforms-and-versions)
- [Installation](#installation)
- [Native requirements](#native-requirements)
- [Payment flow](#payment-flow)
- [Usage](#usage)
  - [Paying with a saved card](#paying-with-a-saved-card)
- [Public API](#public-api)
- [Models](#models)
- [Results and errors](#results-and-errors)
- [Callbacks and events](#callbacks-and-events)
- [Security](#security)
- [Android notes](#android-notes)
- [iOS notes](#ios-notes)
- [Architecture](#architecture)
- [Pigeon code generation](#pigeon-code-generation)
- [Testing](#testing)
- [Updating the Android native SDK](#updating-the-android-native-sdk)
- [Updating the iOS native SDK](#updating-the-ios-native-sdk)
- [Troubleshooting](#troubleshooting)
- [Versioning](#versioning)

## What the plugin does

| Capability | Android | iOS |
|---|---|---|
| Initialize the gateway SDK | ✅ | ✅ |
| Store a card in a gateway session | ✅ | ✅ |
| 3-D Secure payer authentication (frictionless or OTP challenge) | ✅ | ✅ |
| Device wallet: check availability | ✅ Google Pay | ✅ Apple Pay |
| Device wallet: pay and store the token in the session | ✅ Google Pay | ✅ Apple Pay |
| Customize the 3-D Secure challenge screen | ✅ | ✅ |

What the plugin does **not** do, by design of the gateway:

- It does not create sessions and does not charge the card. Session creation and the final
  `PAY` / `AUTHORIZE` + `CAPTURE` calls need the merchant API password and must run on your
  server.
- Tokenization (card on file) is a server operation on a session updated by the plugin.

> **iOS status:** the iOS implementation has not been compiled and verified on a Mac yet. See
> [`example/IOS_TESTING.md`](example/IOS_TESTING.md).

## Supported platforms and versions

| | Minimum | Notes |
|---|---|---|
| Flutter | 3.27 | Dart 3.11 |
| Android | API 24 (Android 7.0) | compileSdk 36. The Gateway SDK itself supports API 23. |
| iOS | 13.0 | The Gateway SDK itself supports iOS 12. |

Bundled native SDKs (see [Versioning](#versioning)):

| Platform | SDK | Version |
|---|---|---|
| Android | Mastercard Gateway Android SDK | 2.0.17 (3DS SDK 6.7.60) |
| iOS | Mastercard Gateway iOS SDK | 2.0.14 (mSignia uSDK 6.7.63) |

The same values are available at runtime in `NbePaymentVersions`.

## Installation

The package is private and distributed from the company Git repository.

```yaml
dependencies:
  nbe_payment_flutter_plugin:
    git:
      url: <company repository URL>
      ref: v0.1.0 # always pin a tag
```

Then complete the [native requirements](#native-requirements).

## Native requirements

### Android

1. **Jetifier** — add to `android/gradle.properties` of the app:

   ```properties
   android.enableJetifier=true
   ```

   The bundled 3DS SDK still references the legacy `com.android.support` libraries. Without
   Jetifier the build fails with a manifest merger or duplicate class error.

2. **minSdk 24** or higher in the app.

3. Nothing else is needed for a standard Flutter app. The plugin itself:
   - registers its bundled Maven repository (`gateway-repo`) for the whole build;
   - declares the `INTERNET` permission and the Google Pay API meta-data;
   - ships R8 rules required for release builds.

   If your `settings.gradle(.kts)` uses `RepositoriesMode.FAIL_ON_PROJECT_REPOS`, add the
   repository there manually:

   ```kotlin
   maven { url = uri("<path to the plugin>/android/gateway-repo") }
   ```

4. **Google Pay in production** needs a Google Pay merchant ID from the Google Pay & Wallet
   Console, and the gateway merchant must be enabled for Google Pay by the bank.

### iOS

1. CocoaPods (the plugin vendors `Gateway.xcframework` and `uSDK.xcframework`).
2. A recent Xcode: the Gateway framework was built with Swift 6.2.3.
3. **Apple Pay** (optional) needs:
   - an Apple Pay merchant identifier;
   - the Apple Pay capability on the app target with that identifier;
   - a payment processing certificate created with the CSR provided by the gateway;
   - the gateway merchant enabled for Apple Pay by the bank.
4. App Store privacy: both frameworks ship privacy manifests (payment info; other usage data;
   file timestamp and user defaults API reasons). Reflect them in App Store Connect.

## Payment flow

```
Your server     Create Session + Update Session (order, amount, currency, 3DS settings)
                     │  returns session id, order id, amount, currency, API version
                     ▼
App (plugin)    initialize (once)
                     ▼
App (plugin)    updateSessionWithCard  ─or─  payWithDeviceWallet
                ─or─  updateSessionWithSecurityCode  (saved card, see below)
                     ▼
App (plugin)    authenticatePayer  → may show the issuer OTP screen
                     │  returns authenticationTransactionId
                     ▼
Your server     PAY  (or AUTHORIZE, then CAPTURE) with session.id and
                authentication.transactionId
```

The final payment status always comes from your server. If the app is killed during the OTP
screen, the plugin result is lost; query the order on the server.

A ready-made Postman collection for the server side in the test environment is in
[`example/postman`](example/postman).

## Usage

```dart
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin.dart';

final gateway = NbePaymentGateway();

await gateway.initialize(
  const GatewayConfiguration(
    merchantId: 'TESTMERCHANT01',
    merchantName: 'My Store',          // Android only
    merchantUrl: 'https://mystore.example', // Android only
    region: GatewayRegion.mtf,          // test environment
    wallet: WalletConfiguration(
      applePayMerchantIdentifier: 'merchant.com.mystore',
    ),
  ),
);

// Values created by your server.
final session = PaymentSession(
  id: serverSession.id,
  orderId: serverSession.orderId,
  amount: '150.00',
  currency: 'EGP',
  apiVersion: '100',
);

try {
  await gateway.updateSessionWithCard(
    session,
    CardDetails(
      number: cardNumber,
      expiryMonth: '01',
      expiryYear: '39',
      securityCode: cvv,
      nameOnCard: name,
    ),
  );

  final authentication = await gateway.authenticatePayer(session);

  switch (authentication) {
    case AuthenticationProceed():
      await myServer.pay(
        sessionId: session.id,
        authenticationTransactionId: authentication.authenticationTransactionId,
      );
    case AuthenticationNotProceeded(:final reason):
      showDecline(reason);
  }
} on GatewayException catch (error) {
  switch (error.code) {
    case GatewayErrorCode.network:
      showRetry();
    default:
      showGenericError();
  }
}
```

### Paying with a saved card

A card your server saved for the payer (a token) is put into the session by the server, not by
the app. The gateway still refuses a card payment without a security code, and a saved card
never carries one, so the payer types the CVV and the app adds that single field:

```dart
// 1. Your server creates the session AND puts the saved card in it (card_id / token).
final session = await myServer.createSessionWithSavedCard(cardId);

// 2. Ask the payer for the CVV and add it to the session. The saved card is left untouched:
//    only sourceOfFunds.provided.card.securityCode is sent.
await gateway.updateSessionWithSecurityCode(session, cvv);

// 3. Continue exactly as with a typed card.
final authentication = await gateway.authenticatePayer(session);
```

Order matters: call `updateSessionWithSecurityCode` **after** the server has put the card in
the session. A server update that runs afterwards replaces the session's payment details and
drops the security code, and the server's PAY then fails with no visible cause in the app.

Do not use `updateSessionWithCard` for this: it sends the card number and expiry, which
replaces the saved card in the session.

Device wallet:

```dart
const walletRequest = WalletPaymentRequest(
  merchantDisplayName: 'My Store',
  countryCode: 'EG',
  // supportedNetworks defaults to {visa, mastercard}
);

if (await gateway.getAvailableWallet(walletRequest) != DeviceWallet.none) {
  final result = await gateway.payWithDeviceWallet(session, walletRequest);
  if (result is WalletPaymentCompleted) {
    // The session now holds the wallet token: continue as with a card.
  }
}
```

## Public API

`NbePaymentGateway()` always returns the same instance: the native SDKs are process-wide.

| Method | Description |
|---|---|
| `bool isInitialized` | Whether `initialize` completed in this Dart isolate. |
| `initialize(GatewayConfiguration)` | Initializes the native SDK. An equal configuration again is a no-op; a different one throws `alreadyInitialized`. |
| `updateSessionWithCard(session, card, {additionalFields})` | Stores the card in the gateway session. |
| `updateSessionWithSecurityCode(session, securityCode, {additionalFields})` | Adds only the security code (CVV) to a session that already holds a card, for a card saved by your server. Sends no other `sourceOfFunds` field. |
| `authenticatePayer(session, {authenticationTransactionId, options})` | Runs 3-D Secure. Generates a UUID transaction ID when none is given and returns it in the result. |
| `getAvailableWallet(WalletPaymentRequest)` | Google Pay / Apple Pay / none. Shows no UI. |
| `payWithDeviceWallet(session, WalletPaymentRequest)` | Shows the wallet sheet and stores the token in the session. |

Initialization rules:

- Only the merchant identity (merchant ID, name, URL, region) is fixed for the app process.
  Calling `initialize` again for the same merchant is accepted, so wallet identifiers can be
  added later; a different merchant or region throws `alreadyInitialized`.
- The challenge appearance and language are applied by the native SDKs at initialization and
  cannot be changed afterwards. A later value is accepted but does not reach the running SDK;
  on iOS, `AuthenticationOptions.ios` overrides them per call.
- Concurrent `initialize` calls for the same merchant await the same initialization.

Rules that apply to every operation:

- Input is validated in Dart before anything reaches native code, with the same result on
  both platforms.
- **One operation at a time.** A second call while one is running throws
  `operationInProgress` (a double tap cannot start two payments). `getAvailableWallet` is
  exempt because it shows no UI.
- Payment outcomes are **results**; technical failures are **`GatewayException`**.

## Models

| Model | Purpose |
|---|---|
| `GatewayConfiguration` | Merchant ID, region, challenge language and appearance, wallet settings. `isTestEnvironment` is true for `GatewayRegion.mtf`. |
| `GatewayRegion` | `mtf` (test), `europe`, `northAmerica`, `asiaPacific`, `india`, `china`, `saudiArabia`. |
| `WalletConfiguration` | `googlePayMerchantId` (Android, production), `applePayMerchantIdentifier` (iOS). |
| `PaymentSession` | Session created by your server. Amount is a decimal string. API version ≥ 61 and identical to the server's. |
| `CardDetails` | Card entered by the payer; `securityCode` is required, the gateway refuses a card payment without it. `toString()` masks every field. |
| `GatewayFields` | Extra gateway fields in dot notation (`billing.address.city`, `customer.email`, `order.item[0].name`), typed setters. `sourceOfFunds.*` is rejected in any spelling. |
| `AuthenticationOptions` | Extra authenticate-payer fields; `ios:` options (challenge UI, locale, initiate-authentication fields) ignored on Android. |
| `AuthenticationResult` | `AuthenticationProceed` or `AuthenticationNotProceeded(reason)`, both with `authenticationTransactionId`, `authenticationPerformed`, `challengePerformed`. `sdkTransactionId` and `threeDS2TransactionStatus` are iOS only. |
| `WalletPaymentRequest` | Name on the sheet, country code, card networks. Amount and currency come from the session. |
| `WalletPaymentResult` | `WalletPaymentCompleted(wallet, cardDescription)` or `WalletPaymentCancelled(wallet)`. The wallet token is never returned to Dart. |
| `ChallengeUiCustomization` | Shared styles (toolbar, buttons, labels, text box, fonts) plus `android:` (per-button styles) and `ios:` (backgrounds, tint, keyboard, light/dark). Fonts must be registered natively. |
| `NbePaymentVersions` | Plugin and bundled native SDK versions. |

Platform-specific fields are documented on each field and ignored by the other platform. They
never change the payment outcome.

## Results and errors

### Authentication outcomes (not exceptions)

| `AuthenticationDeclineReason` | Meaning |
|---|---|
| `cancelledByUser` | The payer closed the challenge screen. |
| `challengeTimedOut` | The payer did not finish the challenge in time. |
| `resubmitWithAlternativePaymentDetails` | Ask for another card or payment method. |
| `abandonOrder` | The issuer/scheme requires abandoning the order. |
| `doNotProceed` | Authentication failed; this transaction cannot succeed. |
| `unknownRecommendation` | A recommendation this plugin version does not know. |

### `GatewayException`

Branch on `code`, never on `message`.

| `GatewayErrorCode` | When |
|---|---|
| `notInitialized` | Operation before `initialize`. |
| `alreadyInitialized` | `initialize` with a different configuration in the same process. |
| `initializationFailed` | The native SDK failed to initialize (Android). |
| `operationInProgress` | Another operation is running. |
| `invalidArgument` | Validation failed before contacting the gateway. |
| `invalidApiVersion` | Session API version below 61. |
| `missingSessionParameter` | The session lacks fields required for 3DS (set them on the server). |
| `network` | Gateway unreachable (includes certificate pinning failures). |
| `gatewayRejected` | HTTP error from the gateway; see `httpStatusCode`. |
| `invalidGatewayResponse` | Response could not be read. |
| `invalidChallengeCompletionUrl` | 3DS challenge completion URL invalid. |
| `uiUnavailable` | No visible screen to show 3DS or the wallet sheet (e.g. app in background). |
| `walletUnavailable` | Wallet not usable on the device. |
| `walletConfigurationInvalid` | Missing/invalid wallet merchant settings. |
| `walletFailed` | The wallet reported an error. |
| `unknown` | Anything else. |

`nativeDetails` contains sanitized diagnostic text (exception type, HTTP status, gateway error
cause/field names). It never contains card data, tokens or gateway response bodies. Free text
coming from the SDK, the 3DS server or the issuer is shortened to 120 characters, challenge URLs
are stripped of their query string, and an unrecognized error from a newer native version is
reported as `unknown` with its message and details dropped entirely.

## Callbacks and events

There are none. Neither native SDK reports intermediate events: every operation completes
with one result, so each method is a single `Future`. Build any UI state or analytics events
around those futures (the example app does this for its event log).

## Security

- Card data is sent once, from Dart to the native SDK, and is never stored or logged by the
  plugin. `CardDetails`, `PaymentSession` and `GatewayFields` mask their values in `toString()`.
- The security code passed to `updateSessionWithSecurityCode` travels as a plain argument and
  is never held in a plugin object, printed or kept after the call. Keep it short-lived in the
  app as well: never store it, and never put it in a log line or an error report.
- Wallet tokens go from the wallet sheet to the gateway inside native code and never reach
  Dart.
- **Android SDK logging:** Mastercard Gateway Android SDK 2.0.17 logs every HTTP request body
  and the `Authorization` header to logcat, which includes the card number and security code.
  The plugin switches that logging off (see `SdkNetworkLogSilencer`); this was verified in
  debug and release builds. Apps that use the SDK directly are still affected.
- **iOS SDK logging** is switched off through the SDK's `loggingEnabled` flag.
- The API password never belongs in the app. Sessions are created by your server.
- The example app starts in the test region and asks for confirmation before any production
  region.

## Android notes

- 3-D Secure and Google Pay need an attached `Activity`. The plugin takes the current one at
  the moment of the call and never keeps a stale reference; without one it returns
  `uiUnavailable`.
- Google Pay results arrive through `onActivityResult` (request code `10001`, owned by the
  Gateway SDK). The plugin forwards them automatically.
- The Android SDK always uses the device language for the challenge screen;
  `challengeLocale` applies to iOS only.
- If Android kills the process while the OTP or Google Pay screen is open, the pending result
  is lost. Check the order on your server. If only the Activity goes away (not the process),
  the plugin fails the pending operation with `uiUnavailable` instead of hanging.
- **Keep the `android:configChanges` attribute** that the Flutter template puts on the host
  Activity. The bundled 3DS SDK's challenge Activity does not declare it, and the plugin cannot
  cancel an authentication that is already running inside the SDK, so an Activity recreation in
  the middle of one can fail the challenge.
- **Request code `10001` is reserved** by the Gateway SDK for the Google Pay sheet. Do not use
  it for your own `startActivityForResult` calls while a wallet payment is running.
- Release builds rely on `android/consumer-rules.pro`. Without it every gateway call fails
  with `ClassCastException` under R8.

## iOS notes

- The iOS SDK needs a `UINavigationController` for the challenge. The plugin presents a
  transparent navigation controller over the top-most visible view controller for the
  duration of the authentication, then dismisses it. It never assumes the root view controller
  is the right presenter.
- The iOS SDK initializes synchronously and reports no failure; configuration problems surface
  on the first gateway call.
- The Apple Pay sheet stays open while the token is stored in the session, then shows success
  or failure, as Apple requires. Storing the token has a 20-second timeout, so the sheet cannot
  freeze on the spinner past Apple's own deadline.
- `AuthenticationOptions.ios.challengeUi` **replaces** the appearance set at initialization for
  that call; it is not merged with it, because the iOS SDK takes a complete theme.
- SDK completions arrive on background queues; the plugin replies to Flutter on the main
  thread.
- Dependencies are managed with CocoaPods. Swift Package Manager support (a `Package.swift`
  with the two frameworks as binary targets) is planned after the first verified iOS build;
  apps that enable Swift Package Manager keep working meanwhile, because Flutter falls back to
  CocoaPods for plugins without a package manifest.

## Architecture

```
Flutter app
    │
    ▼
NbePaymentGateway (lib/src/api)          validation, one-operation rule, transaction IDs
    │  public models (lib/src/models)
    ▼
Mappers (lib/src/mappers)                public models ⇄ Pigeon messages, error mapping
    │
    ▼
Pigeon (lib/src/generated)  ═══ platform channel ═══
    │                                         │
    ▼                                         ▼
Android (Kotlin)                          iOS (Swift)
NbePaymentFlutterPlugin                   NbePaymentFlutterPlugin
  bridge/GatewayHostApiImpl                 Bridge/GatewayHostApiImpl
  sdk/MastercardGatewaySdkAdapter           SDK/MastercardGatewaySdkAdapter
  sdk/GooglePayController                   SDK/ApplePayController
    │                                         │
    ▼                                         ▼
Gateway Android SDK                       Gateway iOS SDK
```

```
lib/
  nbe_payment_flutter_plugin.dart   public exports only
  src/api/                          NbePaymentGateway, versions, transaction ID generator
  src/models/                       public models and GatewayException
  src/mappers/                      model ⇄ message and error mapping
  src/validation/                   input validation
  src/generated/                    Pigeon output (do not edit)
pigeons/payment_api.dart            the contract (single source of truth)
android/
  gateway-repo/                     bundled Maven repository of the Gateway SDK
  consumer-rules.pro                R8 rules applied to host apps
  src/main/kotlin/.../              plugin, bridge/, sdk/, generated/
ios/
  Frameworks/                       Gateway.xcframework, uSDK.xcframework
  Classes/                          plugin, Bridge/, SDK/, Generated/
example/                            demo and manual test app, Postman collection
test/                               Dart unit tests
```

Deeper documentation for people changing the plugin:

- [`doc/ARCHITECTURE.md`](doc/ARCHITECTURE.md) — layers, the contract, the invariants that must
  keep holding, and where to add what.
- [`doc/DECISIONS.md`](doc/DECISIONS.md) — why the API looks like this, including what was
  deliberately rejected.
- [`doc/NATIVE_SDK_NOTES.md`](doc/NATIVE_SDK_NOTES.md) — verified facts about the bank SDKs
  (regions, threading, UI requirements, logging, release-build behavior) and how each was
  established.
- [`doc/RELEASE_CHECKLIST.md`](doc/RELEASE_CHECKLIST.md) — what to run before a release.
- [`CLAUDE.md`](CLAUDE.md) — short orientation for AI coding sessions.

Design rules:

- Public models are separate from Pigeon messages: generated classes are mutable and their
  generated `toString` prints every field, including card data. Plain value enums
  (`GatewayRegion`, `DeviceWallet`, `CardNetwork`, challenge enums) are defined once in the
  contract and exported directly.
- Each platform has one adapter class that talks to the SDK; the bridge class holds only the
  one-operation rule and reply handling.
- Error codes are constants in the contract, generated identically for Dart, Kotlin and
  Swift.

## Pigeon code generation

The contract is `pigeons/payment_api.dart`. After changing it, from the package root:

```sh
dart run pigeon --input pigeons/payment_api.dart
```

This regenerates:

- `lib/src/generated/payment_api.g.dart`
- `android/src/main/kotlin/com/example/nbe_payment_flutter_plugin/generated/PaymentApi.g.kt`
- `ios/Classes/Generated/PaymentApi.g.swift`

Rules: Pigeon is pinned to an exact version in `pubspec.yaml`; generated files are committed
and never edited by hand; app developers never run Pigeon.

## Testing

| Level | What | How |
|---|---|---|
| Dart unit | Models, validation, masking, mappers, error mapping, `NbePaymentGateway` rules with a fake host API | `flutter test` |
| Android unit (JVM) | Bridge rules, SDK payloads, error and authentication mapping, Google Pay JSON | `cd example/android && ./gradlew :nbe_payment_flutter_plugin:testDebugUnitTest` |
| iOS unit | Bridge rules, payloads, region/network/color mapping, gateway errors | Xcode: `example/ios/Runner.xcworkspace` → Product > Test |
| Integration (real SDK, network) | Initialization, card update and authentication reaching the gateway, wallet availability, concurrency | `cd example && flutter test integration_test/plugin_integration_test.dart -d <device>` |
| Integration in a release build (Android) | Same tests after R8 | see below |
| Manual (example app + Postman) | Real session, card, OTP challenge, wallet, Authorize/Capture/Pay | [`example/README.md`](example/README.md) |

Integration tests use a non-existent session: they prove the path to the gateway and the error
mapping, not a successful payment. Successful payments and OTP challenges are manual tests
with a real MTF session.

Android release-mode check:

```sh
cd example
flutter build apk --release -t integration_test/plugin_integration_test.dart
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.example.nbe_payment_flutter_plugin_example/.MainActivity
adb logcat | grep -E "All tests passed|Some tests failed"
```

Then confirm logcat contains no `okhttp`, `sourceOfFunds`, `securityCode` or `Authorization:`
lines.

The full pre-release list is in [`doc/RELEASE_CHECKLIST.md`](doc/RELEASE_CHECKLIST.md).

## Updating the Android native SDK

1. Download the new SDK ZIP from the Gateway Merchant Administration portal and replace
   `android/gateway-repo` with its Maven repository (both `Mobile_SDK_Android` and
   `gateway-android-3ds`).
2. Update `gatewaySdkVersion` in `android/build.gradle.kts` and
   `NbePaymentVersions.androidGatewaySdk`. `test/api/nbe_payment_versions_test.dart` fails
   until both match.
3. Read `android/GATEWAY_RELEASE_NOTES.md` from the new ZIP.
4. Re-check the SDK internals the plugin depends on:
   - HTTP logging: the silencer targets OkHttp's `java.util.logging` logger. Run a card update
     and confirm logcat has no card data, in debug **and** release.
   - Retrofit version: if the SDK moves to Retrofit 2.10+, the rules in `consumer-rules.pro`
     become redundant (harmless). If it changes networking library, re-run the release check.
   - Public API used by `MastercardGatewaySdkAdapter`, `GooglePayController` and the mapping
     files (`GatewaySDK.initialize`, `GatewayAPI.updateSession`,
     `AuthenticationHandler.authenticate`, `AuthenticationError` subclasses,
     `GooglePayHandler`). New `AuthenticationError` types map to `unknown` until added.
   - Whether the legacy support library is still referenced (Jetifier requirement).
5. Run every test level, including the release-mode integration tests.
6. Update `CHANGELOG.md` and the version table in this README.

## Updating the iOS native SDK

1. Replace `ios/Frameworks/Gateway.xcframework`, `ios/Frameworks/uSDK.xcframework` and
   `ios/Frameworks/CHANGES.md` with the new ones from the ZIP.
2. Update `NbePaymentVersions.iosGatewaySdk` (the versions test reads `CHANGES.md`) and the
   podspec comment.
3. Diff the new `Gateway.swiftinterface` against the old one. Check the APIs used by
   `MastercardGatewaySdkAdapter`, `ApplePayController` and the mapping files, especially
   `AuthenticationRequest`, `AuthenticationResponse`, `AuthenticationError`, `GatewayError`,
   `ChallengeTheme`, `GatewayRegion` and `loggingEnabled`.
4. Check the minimum Swift compiler of the new framework against the Xcode used for release.
5. On a device: run an authentication with a challenge and confirm the challenge screen
   appears over the app and the transparent host disappears afterwards (the SDK has changed
   its navigation handling before).
6. Run the iOS unit tests, the integration tests and the manual checklist.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `gatewayRejected`, HTTP 401 "Authenticated entity not authorised" on card update | The session was created on a different gateway host than the app's region. MTF uses `https://mtf.gateway.mastercard.com`; create sessions there. Also check the merchant ID matches. |
| `alreadyInitialized` after changing merchant or region | The native SDK stays initialized for the process lifetime. Restart the app. |
| Android build: manifest merger `appComponentFactory` or duplicate classes | Add `android.enableJetifier=true`. |
| Android release only: `unknown` with `nativeDetails: ClassCastException` | `consumer-rules.pro` not applied (e.g. a custom build that ignores consumer rules). Add the three rules to the app's R8 configuration. |
| `uiUnavailable` | The app was in the background or no screen was attached when 3DS or the wallet started. |
| `getAvailableWallet` returns `none` on an emulator | Google Pay needs Google Play services and a signed-in Google account. Apple Pay needs a card in Wallet (or sandbox). |
| `walletConfigurationInvalid` on iOS | Missing Apple Pay merchant identifier, or the Apple Pay capability is not configured. |
| `missingSessionParameter` | The server did not load order amount/currency or `authentication.*` fields into the session. |
| Card data visible in logcat | The SDK version or its OkHttp setup changed. Stop using that build and see [Updating the Android native SDK](#updating-the-android-native-sdk). |

## Versioning

The plugin follows [Semantic Versioning](https://semver.org):

- **MAJOR** — a breaking change to the public Dart API (removed/renamed members, new required
  parameters, changed result or error semantics), or a native requirement that breaks existing
  apps (higher minSdk/iOS version).
- **MINOR** — new capabilities or optional parameters; updating a native SDK without breaking
  changes.
- **PATCH** — fixes with no API change.

Pigeon upgrades, regenerated code and adapter changes are internal and do not change the
version level by themselves; changing a public enum defined in the contract is a public API
change.

Every release records in `CHANGELOG.md` the bundled Android and iOS SDK versions and the Pigeon
version.
