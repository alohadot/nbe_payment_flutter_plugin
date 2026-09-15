# iOS verification checklist

The iOS implementation was written without access to a Mac, so it has **not been compiled
yet**. Run these steps in order and record the result of each one. When something fails, copy
the exact error text (the first error is usually enough).

## 0. Requirements

- A recent Xcode. The bundled `Gateway.xcframework` was built with Swift 6.2.3; if Xcode
  reports that the `Gateway` module cannot be imported because of the compiler version, note
  the Xcode version you used.
- CocoaPods (`pod --version`).
- Flutter on the same version as the project (`flutter --version`).

## 1. Build

```sh
cd example
flutter pub get
cd ios && pod install && cd ..
flutter build ios --simulator --debug
```

Expected: `Built build/ios/iphonesimulator/Runner.app`.

If the build fails, copy the first error from the output. Errors inside
`ios/Classes/Generated/PaymentApi.g.swift` are generated code: report them, do not edit that
file.

## 2. Native unit tests

1. Open `example/ios/Runner.xcworkspace` in Xcode.
2. Select the `Runner` scheme and an iPhone simulator.
3. Product > Test.

Expected: `GatewayHostApiImplTests` and `SdkMappingTests` pass.

## 3. Integration tests (real SDK, needs internet)

```sh
cd example
flutter devices                       # pick a simulator id
flutter test integration_test/plugin_integration_test.dart -d <simulator-id>
```

Expected: 4 tests pass.

## 4. Manual test with a real MTF session

Use the Postman collection `example/postman/nbe_mtf_payment_flow.postman_collection.json` with
`baseUrl = https://mtf.gateway.mastercard.com`.

1. Postman: `1. Create Session`, then `2. Update Session`.
2. Run the example app on the simulator: `flutter run -d <simulator-id>`.
3. App: region `mtf`, merchant values, **Initialize** → expect `Success: Initialized`.
4. App: paste the session values, **Update session with card** → expect success.
5. Postman: `3. Retrieve Session` → the card is stored.
6. App: **Authenticate payer** → note what happens on screen:
   - Does a challenge (OTP) screen appear, or does it complete without a screen?
   - After it finishes, does the app return to the normal screen (no blank overlay left)?
   - Can you tap the app normally afterwards?
   Copy the result text shown in the app.
7. Postman: set `authenticationTransactionId` from the app, then `4. Authorize` → `5. Capture`
   → `7. Retrieve Order`.
8. Repeat step 6 and press Cancel on the challenge screen if one appears → expect
   `NOT PROCEEDED (cancelledByUser)`.

## 5. Logging check

While doing step 4, watch the Xcode console (or `flutter run` output). It must **not** show
the card number, the security code, `sourceOfFunds`, or an `Authorization` header. Report only
whether such lines appear, not their content.

## 6. Apple Pay (optional, needs setup)

Requires an Apple Pay merchant identifier, the Apple Pay capability on the `Runner` target, and
a payment processing certificate created with the CSR from the gateway.

1. App: enter the Apple Pay merchant identifier before **Initialize**.
2. **Check available wallet** → expect `applePay` (or `none` without a card in Wallet).
3. With a new session: **Pay with device wallet** → the Apple Pay sheet appears → authorize →
   expect `Session updated with applePay (...)`.

## What to send back

For each section: passed / failed, plus the exact error text or on-screen result for failures.
