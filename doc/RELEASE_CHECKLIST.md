# Release checklist

Run the whole list for every release, on **Android and iOS**, against the MTF test
environment. A release is not ready because the package compiles; it is ready when every item
below is checked on both platforms with the real native SDKs.

Record for each run: plugin version, Git commit, device/emulator and OS version, Xcode and
Android Studio/AGP versions, tester, date.

## 1. Automated tests

- [ ] `flutter analyze` — no issues
- [ ] `flutter test` (package root) — all pass
- [ ] `test/api/nbe_payment_versions_test.dart` passes (version constants match pubspec and the
      bundled SDKs)
- [ ] Android JVM tests: `cd example/android && ./gradlew :nbe_payment_flutter_plugin:testDebugUnitTest`
- [ ] iOS unit tests: Xcode → `Runner` scheme → Product > Test
- [ ] Example widget test: `cd example && flutter test`
- [ ] Integration tests on an Android device/emulator (debug)
- [ ] Integration tests on an iOS simulator or device (debug)
- [ ] Integration tests inside an Android **release** APK (see README, Testing)
- [ ] Pigeon output is up to date: `dart run pigeon --input pigeons/payment_api.dart` produces no
      Git diff

## 2. Builds

- [ ] `cd example && flutter build apk --release`
- [ ] `cd example && flutter build ios --release` (or archive in Xcode)
- [ ] Example app launches in debug and release on both platforms

## 3. Card payment (manual, real MTF session)

Use `example/postman/nbe_mtf_payment_flow.postman_collection.json`.

| Check | Android | iOS |
|---|---|---|
| Plugin initializes (`Success: Initialized`) | ☐ | ☐ |
| Repeated initialize with the same values succeeds | ☐ | ☐ |
| Update session with card succeeds; Retrieve Session shows the card | ☐ | ☐ |
| Authenticate payer: frictionless flow returns `PROCEED` | ☐ | ☐ |
| Authenticate payer: challenge (OTP) screen appears and completes | ☐ | ☐ |
| Challenge cancelled → `NOT PROCEEDED (cancelledByUser)`, app usable afterwards | ☐ | ☐ |
| Authorize + Capture with the authentication transaction ID succeed; Retrieve Order shows both | ☐ | ☐ |
| Pay (one step) on a new session succeeds | ☐ | ☐ |
| Refund succeeds | ☐ | ☐ |

## 4. Device wallet (manual)

| Check | Android (Google Pay) | iOS (Apple Pay) |
|---|---|---|
| `Check available wallet` reports the wallet on a configured device | ☐ | ☐ |
| Wallet sheet shows the session amount and currency | ☐ | ☐ |
| Authorizing updates the session; Pay succeeds on the server | ☐ | ☐ |
| Closing the sheet → `cancelled` | ☐ | ☐ |

## 5. Errors (example app, "Error and concurrency scenarios")

| Scenario | Expected | Android | iOS |
|---|---|---|---|
| Before initialize (fresh app start) | `notInitialized` | ☐ | ☐ |
| Invalid card | `invalidArgument` | ☐ | ☐ |
| API version 60 | `invalidApiVersion` | ☐ | ☐ |
| Unknown session | `gatewayRejected` + HTTP status | ☐ | ☐ |
| Card in extra fields | `invalidArgument` | ☐ | ☐ |
| Double call | one result + `operationInProgress` | ☐ | ☐ |
| Airplane mode during card update | `network` | ☐ | ☐ |
| Session created on another gateway host | `gatewayRejected` 401 | ☐ | ☐ |

## 6. Lifecycle

| Check | Android | iOS |
|---|---|---|
| Background → foreground, then card update works | ☐ | ☐ |
| Rotate the device on the payment screen, then authenticate works | ☐ | ☐ |
| Background during the OTP screen, return, finish challenge: result arrives | ☐ | ☐ |
| Three payments in a row without restarting the app | ☐ | ☐ |
| Cancel a challenge, then retry authentication on the same session | ☐ | ☐ |
| Hot restart during development, then initialize again with the same values succeeds | ☐ | ☐ |
| Android: no crash or stale Activity after "Don't keep activities" (Developer options) | ☐ | — |
| iOS: challenge presentation still works after presenting and dismissing another modal | — | ☐ |

## 7. Security

- [ ] Android logcat during a card update (debug **and** release) contains no `okhttp`,
      `sourceOfFunds`, `securityCode`, `Authorization:` lines and no card number
- [ ] Same logcat check during a security-code-only update (Saved card section of the example)
- [ ] Xcode console during a card update contains no card data or `Authorization` header
- [ ] No API password, real card or production credentials in the repository
- [ ] `CardDetails`, `PaymentSession` printed in the example event log are masked

## 8. Oldest supported Flutter

The dev toolchain is far newer than the floor in `pubspec.yaml`, so an API added after Flutter
3.27 passes analysis here and breaks every app pinned to the floor.

- [ ] `flutter analyze` and `flutter test` pass with the 3.27.4 SDK (comment the dev
      dependencies out for the run; consuming apps never see them)
- [ ] The example app builds a debug APK with the 3.27.4 SDK
- [ ] No new deprecation warnings on the newest SDK

## 9. Documentation and versioning

- [ ] Version bumped per Semantic Versioning in `pubspec.yaml` and `NbePaymentVersions.plugin`
- [ ] `CHANGELOG.md` lists changes, bundled Android/iOS SDK versions and the Pigeon version
- [ ] README version tables and requirements are current
- [ ] Git tag `v<version>` created
