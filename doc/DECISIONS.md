# Design decisions

Why the plugin looks the way it does. Each entry records the decision, the reason, and what
would make us revisit it. Facts about the SDKs are in `NATIVE_SDK_NOTES.md`.

## 1. One unified Dart API, no platform-specific classes

`NbePaymentGateway` is the only entry point. Android and iOS differences are resolved inside
the native adapters.

The exceptions are documented fields, never separate APIs: `merchantName`/`merchantUrl`
(Android only), `challengeLocale` and `AuthenticationOptions.ios` (iOS only),
`sdkTransactionId`/`threeDS2TransactionStatus` (reported by iOS only), and the `android:`/`ios:`
sections of `ChallengeUiCustomization`. The customization models are genuinely different in the
two SDKs — EMVCo per-button styles versus one global theme — so hiding that would produce
silent no-ops.

## 2. The plugin is one half of a payment

Session creation and `PAY`/`AUTHORIZE`+`CAPTURE` stay on the merchant server, because they need
the API password. The plugin's job is: store a card or wallet token in a session, and run 3-D
Secure. The final payment status always comes from the server, which also matters when the app
is killed during a challenge.

## 3. Public models are separate from Pigeon messages

Generated message classes are mutable and their generated `toString` prints every field,
including the card number. They are therefore internal, and hand-written models form the public
API.

Plain value enums are the exception: they carry no data, so they are defined once in the
contract and exported directly. This removed an earlier duplication where the same seven-value
region enum existed twice.

## 4. Payment outcomes are results, not exceptions

`AuthenticationResult` and `WalletPaymentResult` are sealed types, so the compiler forces an app
to handle both outcomes. `GatewayException` is reserved for technical failures and always
carries a stable `GatewayErrorCode`; apps must never branch on a message.

## 5. Typed fields, with one deliberate escape hatch

Card data has a dedicated model. Everything else the gateway accepts (billing address,
customer, order items) is impossible to model exhaustively, so `GatewayFields` offers typed
setters over dot-notation keys, validates the key shape, and rejects `sourceOfFunds.*` in any
spelling — card and wallet data may only travel through their own models.

## 6. The plugin generates the authentication transaction id

The SDKs require an identifier per authentication attempt but neither generates nor returns
one, and every retry needs a new one. The plugin generates a UUID v4 when the app does not pass
one and always returns the value used, which the server needs for the payment. An app whose
server wants to own the identifier can still pass it.

## 7. Only the regions both SDKs support

`mtf`, `europe`, `northAmerica`, `asiaPacific`, `india`, `china`, `saudiArabia`. Mastercard's
internal QA/PEAT regions (Android only) and `GatewayRegion.other` with a custom host (iOS only)
are not exposed: a capability that exists on one platform only would produce confusing
behavior. Revisit if the bank requires a bank-specific host — that would need a way to make the
Android SDK talk to it, which it does not support today.

## 8. One wallet API for Google Pay and Apple Pay

`getAvailableWallet` and `payWithDeviceWallet` with shared parameters (display name, country,
card networks) plus each platform's merchant identifier in `WalletConfiguration`. The amount and
currency come from the session so the sheet cannot show something other than what will be
charged. Card networks default to Visa and Mastercard and can be overridden, because both
wallet APIs require the app to declare them even though the accepted networks are really a
gateway setting.

## 9. No event streams

Neither SDK reports intermediate events, so there is no `@FlutterApi` and every operation is a
single `Future`. Inventing progress events would mean inventing data.

## 10. One operation at a time, enforced everywhere

Dart, Android and iOS each refuse a second operation with `operationInProgress`, and the native
locks are process-wide because the SDK objects are singletons shared by all Flutter engines.
Availability checks are exempt: no UI, no session change. The example app deliberately does not
disable its buttons, so the protection is visible in manual testing.

## 11. Initialization is per merchant, not per configuration

Comparing whole configurations made harmless changes fail permanently: adding wallet
identifiers later (they never reach the SDK) or changing the challenge theme. Only merchant
identity is compared; appearance and locale are documented as fixed at initialization, with iOS
per-call overrides. Concurrent calls for the same merchant await the same initialization.

## 12. Native UI hosts are resolved when needed

The current Activity on Android and the top-most visible view controller on iOS, both looked up
at call time, never stored. On iOS the plugin presents its own transparent navigation
controller, because the SDK requires one and Flutter apps have none; the overlay also blocks
double taps during authentication. Missing a host is `uiUnavailable` rather than a crash.

## 13. Pending operations are failed when their screen disappears

Engine detach (both platforms), Activity detach (Android), presentation and session-update
timeouts (iOS). Without this, a lock stays held and every later call in the process fails with
`operationInProgress` while the Dart future never completes.

## 14. The SDKs' own HTTP logging is switched off

The Android SDK writes card numbers and security codes to logcat; the plugin silences the
logger it uses (deriving the name from the class, because R8 renames it) and repeats this before
every call. iOS has explicit switches, which are also set before every call. Verified with
control runs in debug and release. This is a workaround for an SDK problem and must be
re-verified after every SDK upgrade.

## 15. Diagnostics are sanitized, never raw

`nativeDetails` carries exception types, HTTP status and the gateway's machine-readable error
fields. Free text from the SDK, the 3DS server or the issuer is shortened; challenge URLs lose
their query string; an unrecognized channel error drops its message and details entirely,
because Pigeon fills those with raw exception text and a stack trace.

## 16. The example app is a test harness, not a demo screen

It uses only the public API, covers every capability, includes deliberate error and concurrency
scenarios with the expected error code on each button, logs app lifecycle changes, and shows
platform/SDK/build information. It is locked to the test region by default and asks for
confirmation before a production one.

## 17. Private distribution

`publish_to: none`; the package is consumed from the company Git repository with a pinned tag.
The bundled SDK binaries stay in the repository so consumers need no extra setup beyond
Jetifier on Android.

## Rejected

| Idea | Why not |
|---|---|
| Expose the SDKs' low-level `initiateAuthentication`/`authenticatePayer` | The 3DS transaction they need is built internally by the SDK; alone they are useless |
| Expose cancellation of `updateSession` (iOS can) | Cancelling after the request reached the gateway leaves the session state unknown |
| Free-form gateway host | Card data must not be sent to an arbitrary host, and Android cannot do it at all |
| Expose native SDK versions through a channel call | They are constants known at build time (`NbePaymentVersions`) |
| Swift Package Manager support now | It moves every iOS source file; doing that before the first successful Mac build would confuse a build failure with a layout problem |
