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

## 4. Payment outcomes are values; technical failures are exceptions

`AuthenticationResult` and `WalletPaymentResult` are sealed types, so the compiler forces an app
to handle natural outcomes such as proceed/not-proceed and completed/cancelled. `DeviceWallet.none`
is also a successful availability answer. These outcomes say what the payer, issuer or device
decided; they are not malfunctions.

Technical and integration failures complete the ordinary Dart `Future<T>` with public
`GatewayException`, which always carries a stable `GatewayErrorCode`. Apps catch that type at the
UI boundary, map codes and rejection fields to localized safe copy, and never branch on or show
developer diagnostics.

A universal `GatewayResult<T>` wrapper was considered and rejected. It would produce nested
values such as `GatewaySuccess(AuthenticationNotProceeded(...))`, add a switch around every
`Future<void>` call, and depart from the error-channel convention used by Dart and Flutter APIs.
It would also make an ignored failure silent because Dart has no `must_use`. Direct `Future<T>`
values plus one typed exception keep the public contract smaller without losing structured
errors.

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

## 18. A typed CVV-only update, while `sourceOfFunds` stays reserved

A card saved by the merchant server is put into the session by the server, as a token. The
gateway still refuses a card payment without a security code, and a saved card never carries
one, so exactly one field has to be added from the app:
`sourceOfFunds.provided.card.securityCode`.

Three ways were possible; the third was chosen.

- **Allow `sourceOfFunds.*` in `GatewayFields`.** Rejected: that guard is what keeps card and
  wallet data out of the free-form escape hatch (decision 5). Opening it for one key would
  open it for `number` too, in any spelling.
- **Call `updateSessionWithCard` with a placeholder number and expiry.** Rejected: those fields
  are sent, so they would overwrite the saved card in the session.
- **A dedicated typed method**, `updateSessionWithSecurityCode`. It builds its own payload with
  that one key, so the stored card cannot be touched, and it reuses the existing validation,
  lock and error mapping.

The security code crosses the channel as a plain method parameter, not inside a message class:
Pigeon's generated classes print every field in `toString` (decision 3), and a parameter has no
`toString` to leak.

The same reasoning makes `CardDetails.securityCode` required (it was optional). The gateway
refuses a card payment without it, so an absent code could only turn into a failed PAY on the
server, far from the cause. The saved-card case, which was the one legitimate reason to omit
it, now has its own method.

Not enforced by the plugin: `updateSessionWithSecurityCode` must run *after* the server has put
the card in the session. The plugin cannot see what the server does with the session, so this
is stated in the README instead.

## 19. The gateway's own rejection fields are part of the failure

The gateway answers a rejected request with `error.cause`, `error.field` and
`error.validationType`: machine-readable names that say which value is wrong. Until 0.1.1 the
plugin parsed them natively and then flattened them into one diagnostic string, which left apps
with nothing to branch on and "something went wrong" as the only message a payer could see.

They are now carried on `GatewayException` as typed values (`GatewayRejectionCause`, the field
path, and `GatewayValidationType`), so an app can say "the security code is not correct" instead.
The field paths are exposed as `GatewayFieldNames` constants so apps do not retype them.

`error.explanation` is still dropped everywhere: it is free text and can quote the submitted
value, which would put a card number into a log or a crash report. What is exposed are names,
never values.

The limit is documented rather than hidden: these fields describe the request the app sent. A
decline by the issuer is decided by the server's PAY request, which the plugin never sees.

## Rejected

| Idea | Why not |
|---|---|
| Expose the SDKs' low-level `initiateAuthentication`/`authenticatePayer` | The 3DS transaction they need is built internally by the SDK; alone they are useless |
| Expose cancellation of `updateSession` (iOS can) | Cancelling after the request reached the gateway leaves the session state unknown |
| Free-form gateway host | Card data must not be sent to an arbitrary host, and Android cannot do it at all |
| Expose native SDK versions through a channel call | They are constants known at build time (`NbePaymentVersions`) |
| Swift Package Manager support now | It moves every iOS source file; doing that before the first successful Mac build would confuse a build failure with a layout problem |
