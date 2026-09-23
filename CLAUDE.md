# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

A **private** Flutter plugin that wraps the official Mastercard Gateway (MPGS) native SDKs for
the NBE payment gateway. Flutter apps see one Dart API (`NbePaymentGateway`) and never touch
Kotlin, Swift, Activities, view controllers or platform channels.

The plugin **cannot complete a payment on its own**: sessions are created and payments are
captured by the merchant server (API password never belongs in the app). The plugin stores the
card or wallet token in a gateway session and runs 3-D Secure.

## Where everything is written down

| Document | Read it for |
|---|---|
| `README.md` | The public contract: install, native requirements, API, models, error codes, security, per-platform notes, SDK upgrade steps, troubleshooting, versioning |
| `doc/ARCHITECTURE.md` | Layers, the Pigeon contract, the invariants that must keep holding, where to add what |
| `doc/DECISIONS.md` | Why the API looks like this, and what was deliberately rejected |
| `doc/NATIVE_SDK_NOTES.md` | Verified facts about the bank SDKs and how each was established (regions, threading, UI, logging, release behavior, field names) |
| `doc/RELEASE_CHECKLIST.md` | What to run and check before any release, on both platforms |
| `example/README.md` | Running the demo app, creating a test session with Postman, testing each capability |
| `example/IOS_TESTING.md` | The exact steps for the first iOS build and verification on a Mac |
| `CHANGELOG.md` | What each version contains and which native SDKs it bundles |

Everything a new session needs is in those files; nothing important lives only in a chat.

## Current status (keep this updated)

| Area | State |
|---|---|
| Dart layer | Complete, 185 unit tests |
| Android | Complete: initialize, card update, security-code-only update, 3DS, Google Pay. Verified on an emulator in debug **and** release, with a real MTF session (card update + 3DS + server Authorize/Capture) |
| Saved card (CVV only) | `updateSessionWithSecurityCode` written and unit tested on both layers; not yet run against a real session holding a saved card |
| iOS | Written, **never compiled** (development machine is Windows). Verification steps: `example/IOS_TESTING.md` |
| Google Pay sheet | Not yet run on a device with a Google account |
| 3DS challenge (OTP) screen | Not yet triggered: the test card used so far authenticates frictionless. The back button and the screen's task placement were fixed in 0.2.1 from the SDK binary and the merged manifest; still to be confirmed on a device with a challenge card |
| Docs | README, example README, architecture, decisions, SDK notes, release checklist |

Pending, and blocked on someone else: iOS build on a Mac, Google Pay on a real device, a test
card that forces a challenge, a test session that already holds a saved card (`card_id`) to
verify the CVV-only update end to end, the bank enabling the wallets, company name in
`LICENSE`, the Git repository URL in the docs, reporting the Android SDK logging leak to the
bank.

## Layout

```
lib/src/api/          NbePaymentGateway, versions, transaction id generator
lib/src/models/       public models + GatewayException (hand-written, documented)
lib/src/mappers/      public models <-> Pigeon messages, error mapping
lib/src/validation/   input validation, runs before anything reaches native code
lib/src/generated/    Pigeon output — never edit
pigeons/payment_api.dart   the contract: messages, shared enums, error-code constants
android/src/main/kotlin/.../{plugin, bridge/, sdk/, generated/}
ios/Classes/{plugin, Bridge/, SDK/, Generated/}
android/gateway-repo/, ios/Frameworks/   bundled bank SDKs
example/              demo + manual test app, Postman collection, iOS test steps
doc/                  architecture, decisions, SDK notes, release checklist
```

## Commands

```sh
# Dart
flutter analyze
flutter test                     # 185 tests

# Regenerate the contract after editing pigeons/payment_api.dart
dart run pigeon --input pigeons/payment_api.dart

# Android unit tests (JVM)
cd example/android && ./gradlew :nbe_payment_flutter_plugin:testDebugUnitTest

# Integration tests against the real SDK (needs a device and network)
cd example && flutter test integration_test/plugin_integration_test.dart -d <device>

# Same tests inside a release APK (catches R8 problems; see doc/RELEASE_CHECKLIST.md)
cd example && flutter build apk --release -t integration_test/plugin_integration_test.dart

# iOS (macOS only)
cd example/ios && pod install && cd .. && flutter build ios --simulator --debug
```

On this Windows machine, chaining `flutter analyze` and `flutter test` in one shell command has
hung more than once; run them as separate commands.

```sh
# Check the oldest supported Flutter (3.27.4 / Dart 3.6.2) before a release. The dev
# dependencies (Pigeon, flutter_lints 6) need a newer SDK, so comment them out in pubspec.yaml
# for the run and restore them afterwards; consuming apps never see them.
/c/flutter_src/flutter_windows_3.27.4-stable/flutter/bin/flutter analyze
/c/flutter_src/flutter_windows_3.27.4-stable/flutter/bin/flutter test
cd example && /c/flutter_src/flutter_windows_3.27.4-stable/flutter/bin/flutter build apk --debug
```

The Flutter SDK on `PATH` (3.27.4, Dart 3.6.2) cannot even resolve the dev dependencies: the
pinned Pigeon 27.3.0 needs Dart 3.7+. Use a newer SDK installed on this machine for the dev
commands, for example `/c/flutter_src/flutter_windows_3.41.9-stable/flutter/bin/flutter`. The
package's own constraint stays `^3.6.0`, so host apps on 3.27 are unaffected. Pigeon formats its
Dart output with the *package's* language version, which reformats the whole generated file;
after regenerating, run
`dart format --language-version=latest lib/src/generated/payment_api.g.dart` to keep the diff to
the real change.

## Rules for changes

- **Never edit generated files** (`lib/src/generated/`, `.../generated/PaymentApi.g.kt`,
  `ios/Classes/Generated/`). Change `pigeons/payment_api.dart` and regenerate. Pigeon is pinned
  to an exact version; keep the generated output committed.
- **Public API needs documentation.** `public_member_api_docs` is an analyzer **error**, and the
  analyzer runs with strict casts/inference/raw types.
- **Payment outcomes are values; technical failures are exceptions.** Methods return ordinary
  `Future<T>` values. A decline, cancelled challenge, closed wallet sheet or unavailable wallet
  is a normal typed outcome; a technical problem throws public `GatewayException` with a stable
  `GatewayErrorCode`. Apps catch that type at the UI boundary and never display its diagnostics
  directly to the payer.
- **A rejection says which field is wrong.** The gateway's `error.cause`, `error.field` and
  `error.validationType` travel as typed values on `GatewayException` so the app can tell the
  payer what to fix. `error.explanation` is never forwarded: it can quote the card number.
- **One gateway operation at a time**, enforced in Dart *and* in both natives with a
  process-wide lock. Whenever a native screen can disappear, make sure the pending operation is
  failed — a held lock blocks every later call for the life of the process.
- **`lib/` must compile on Flutter 3.27 / Dart 3.6**, the floor in `pubspec.yaml`. The dev
  toolchain is much newer, so an API added after 3.27 (`Color.toARGB32()` was one) analyzes
  cleanly here and breaks every app pinned to the floor. Analyze and test with the 3.27.4 SDK
  before a release; the example app is pinned to the same floor so it can prove the claim.
- **Never log or leak card data.** No `print` in `lib/`; `CardDetails`, `PaymentSession` and
  `GatewayFields` mask their values in `toString`; `nativeDetails` carries only sanitized text
  (types, HTTP status, gateway error codes), never messages from an unrecognized error.
- **Public models stay separate from Pigeon messages** (generated classes are mutable and print
  every field, card data included). Plain value enums are the exception: they are defined once
  in the contract and exported directly.
- Add tests at the level where the logic lives: Dart unit tests for the Dart layer, JVM tests
  for Kotlin, XCTest for Swift, integration tests for anything that must cross the channel.
- Do not introduce a mock that pretends to be an end-to-end test. Integration tests here use a
  non-existent session on purpose: they prove the path and the error mapping, not a payment.

## Known gaps and deferred work

Deliberate, with the reason. Do not "fix" one without reading the reason first.

- **`walletUnavailable` is reported by iOS only.** Android answers `none` from
  `getAvailableWallet`, and a payment on a device without Google Pay fails as `walletFailed`.
  Adding an availability check inside `payWithDeviceWallet` would make it symmetric at the cost
  of an extra round trip.
- **`merchantUrl` accepts `http://`.** It is merchant metadata passed to the Android SDK, not a
  gateway endpoint. Tighten to https only if the bank confirms nothing needs plain http.
- **`order.walletProvider = GOOGLE_PAY`** is sent with the Google Pay token by symmetry with the
  iOS guide, which documents `APPLE_PAY`. Still to be confirmed against the gateway.
- **Google Pay allowed authentication methods** (`PAN_ONLY`, `CRYPTOGRAM_3DS`) come from the
  Google Pay API, not from the bank's guide.
- **Swift Package Manager support** is planned after the first successful iOS build; see
  `doc/DECISIONS.md`.
- **Android instrumentation tests** do not exist: the same ground is covered by the Flutter
  integration tests, which run against the real SDK on a device.
- **Continuous integration** is not set up (the owner asked to skip it for now).

## Traps found the hard way

- A session must be created on the **same gateway host** as the region the app initializes with
  (`GatewayRegion.mtf` → `https://mtf.gateway.mastercard.com`). A session from another host
  fails with HTTP 401 "Authenticated entity not authorised".
- Android release builds need `android/consumer-rules.pro`; without it every gateway call fails
  with `ClassCastException` under R8 full mode. Release-mode integration tests catch this.
- The Android SDK logs full request bodies (card number, CVV) and the `Authorization` header to
  logcat. `SdkNetworkLogSilencer` switches that off and must keep working after any SDK or
  OkHttp change — verify with a card update in debug **and** release.
- Host apps need `android.enableJetifier=true` (the 3DS SDK uses the legacy support library).
- The 3DS SDK declares its challenge screen `singleTask` with no `taskAffinity`, so on a host
  whose Activity sets a different affinity (`android:taskAffinity=""`) Android opened it in a
  task of its own: a second card in recents, and back moved that task to the background instead
  of cancelling, holding the gateway lock forever. The plugin manifest replaces the launch mode
  with `standard`. Do not drop that override, and re-check it after a 3DS SDK upgrade.
- Request code `10001` belongs to the Gateway SDK's Google Pay sheet.
- The native SDKs stay initialized for the whole process: after a hot restart Dart thinks it is
  not initialized while the native side is. Only the merchant identity is fixed per process;
  challenge appearance and locale cannot be changed after initialization.
