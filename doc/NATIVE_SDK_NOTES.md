# Notes on the bundled bank SDKs

Facts about the Mastercard Gateway SDKs that the plugin depends on, with how each one was
established. Re-check the "verified in" items after every SDK upgrade — the plugin's behavior
is built on them.

Sources used: the integration guides (Android 2.0.17, iOS 2.0.14), the compiled Android AAR
(`javap` on `android/gateway-repo`), the iOS module interface
(`ios/Frameworks/Gateway.xcframework/.../arm64-apple-ios.swiftinterface`), and runs on an
emulator against the MTF environment.

## Versions and requirements

| | Android | iOS |
|---|---|---|
| Gateway SDK | 2.0.17 | 2.0.14 |
| 3DS SDK | `gateway-android-3ds` 6.7.60 (`com.usdk.android`) | mSignia `uSDK.xcframework` 6.7.63 |
| Minimum OS | API 23 (the plugin requires 24) | 12.0 (the plugin requires 13.0) |
| Minimum gateway API version | 61 (`AuthenticationHandler.MIN_API_VERSION`) | 61 |
| Third-party dependencies | Retrofit 2.9, OkHttp, Gson, Coroutines, Material, Play Services (wallet, location, ads-id, auth-phone), **legacy `com.android.support` appcompat-v7 28** | none beyond `uSDK` |

The legacy support library is why host apps need `android.enableJetifier=true`.

## What the SDKs do and do not do

- They never create sessions and never charge a card. Those calls need the merchant API
  password and belong on the merchant server.
- They emit **no intermediate events**: each operation ends with one result. This is why the
  plugin has no event streams.
- Tokenization (card on file) is a server operation performed on a session the plugin updated.

## Documentation mismatches (binary wins)

| The guide says | The SDK actually has |
|---|---|
| `GooglePayCallback.onReceivedPaymentData / onGooglePayCancelled / onGooglePayError` | `onSuccess / onCancelled / onError` |
| iOS `initialize(merchantId:merchantName:merchantUrl:region:)` | `initialize(merchantId:region:locale:challengeTheme:)` — no merchant name or URL |
| iOS requires iOS 11 | frameworks declare `MinimumOSVersion 12.0` |
| Android `authenticate(activity, session, txnId, callback)` | also takes an optional `GatewayMap` payload; the 4-argument overload is not visible from Kotlin |
| "Device vs simulator builds", Bitcode | obsolete: the xcframeworks contain both slices |

## Regions and hosts

The Android SDK hardcodes one host per enum constant; there is no custom host.

```
MTF           mtf.gateway.mastercard.com      (test)
EUROPE        eu.gateway.mastercard.com
NORTH_AMERICA na.gateway.mastercard.com
ASIA_PACIFIC  ap.gateway.mastercard.com
INDIA         in.gateway.mastercard.com
CHINA         gateway.sspriceless.cn
SAUDI_ARABIA  ksa.gateway.mastercard.com
QA01..QA07, PEAT                              (Mastercard-internal, not exposed by the plugin)
```

URLs are built as `https://<host>` + `/api/rest/` + `version/{apiVersion}/merchant/{merchantId}/…`,
and the region is used **only** there — 3DS configuration does not depend on it (verified in
bytecode). The iOS SDK exposes the same regions plus `GatewayRegion.other(id:name:baseURL:)`,
which the plugin does not expose because Android has no equivalent.

**A session must be created on the same host as the region**, otherwise the gateway answers
HTTP 401 "Authenticated entity not authorised" (observed with a session created on
`test-gateway.mastercard.com` while the app used MTF).

**Sessions expire quickly.** A session left idle while the payer decides fails the next server
call with `INVALID_REQUEST` / "Form Session not found or expired" (observed on MTF). The app
should ask its server for a session when the payer starts paying, not when the screen opens.

## Threading

| | Android | iOS |
|---|---|---|
| Work | `Dispatchers.IO` inside the SDK | `URLSession` queues |
| Callbacks | main thread (`withContext(dispatchers.main())`, verified in bytecode) | **not documented**; the guide's own sample hops to the main queue |

The plugin replies to Flutter on the main thread on both platforms and does not rely on the iOS
SDK's choice.

## UI requirements

- **Android**: `AuthenticationHandler.authenticate` needs an `android.app.Activity` (a plain
  `Activity` is enough; `FlutterActivity` works). The challenge runs in the 3DS SDK's own
  `com.usdk.android.ChallengeActivity`, which declares **no** `android:configChanges`, so a
  rotation recreates it. A progress dialog is shown on the passed Activity. Its launch mode and
  the task it lands in need care of their own: see "The challenge screen's task and back button"
  below.
- **iOS**: `AuthenticationRequest` needs a `UINavigationController`. Flutter apps have none, so
  the plugin presents a transparent one over the top-most visible view controller for the
  duration. The SDK's release notes changed "Navigation Control for Challenge Flow" in 2.0.13,
  so this is the first thing to re-check after an iOS SDK upgrade.
- **Google Pay**: the SDK launches the sheet with `startActivityForResult` and **request code
  10001**, and returns the result through `GooglePayHandler.handleActivityResult`. That method
  returns `true` for any result code once the request code matches, but only calls back for
  `RESULT_OK / RESULT_CANCELED / AutoResolveHelper.RESULT_ERROR` — an unexpected result code is
  consumed without a callback, so the plugin detects that case itself.
- **Apple Pay**: the iOS SDK has no helper at all. The plugin implements the PassKit flow and
  only hands the token to `updateSession`.

## The challenge screen's task and back button (Android)

Established by reading `AndroidManifest.xml` and disassembling the classes inside
`gateway-android-3ds-6.7.60.aar`.

- The SDK declares the screen as `android:launchMode="singleTask"` and sets **no**
  `android:taskAffinity`, so its affinity is the host application's package name. A `singleTask`
  Activity always runs at the root of a task carrying its own affinity, so a host Activity that
  declares a different one — `android:taskAffinity=""` is the common case — can never share a
  task with the challenge, and Android is forced to open it in a task of its own. Two things
  break then: the challenge appears as a second card in the recents list (blank, see
  `FLAG_SECURE` below), and back on the root Activity of a task moves that task to the
  background on Android 12 and later instead of closing it, so the SDK's cancel never runs and
  no outcome ever arrives. The plugin's own `android/src/main/AndroidManifest.xml` replaces the
  launch mode with `standard`.
- The SDK opens the screen with a plain `startActivity(Intent(context, ChallengeActivity.class))`
  and **no intent flags**, from the Activity handed to `authenticate`. `standard` therefore puts
  it in that Activity's task whatever affinity the host declares.
- `ChallengeActivity` declares no `onNewIntent`, so nothing in the SDK depends on `singleTask`.
- `ChallengeActivity.onBackPressed` calls the SDK's own cancel, which logs "User canceled
  challenging", sends the issuer `CANCEL_BY_CARDHOLDER`, and only then closes the screen and
  answers through the authentication callback. Back is a proper cancellation — provided that
  method is reached.
- The screen implements the legacy `onBackPressed` only: its classes contain no reference to
  `OnBackInvoked`. An app that turns predictive back on (`android:enableOnBackInvokedCallback`,
  or a target SDK new enough to get it without asking) would stop the method being called at
  all, which is why `ChallengeScreenGuard` registers a callback on the new dispatcher that
  calls it.
- The screen sets `FLAG_SECURE` on its window (`setFlags(8192, 8192)` in `onCreate`), so its
  recents thumbnail and any screenshot of it are blank.

## Security findings

- **Android logs card data.** `ServiceProvider.buildHttpClient` installs OkHttp's
  `HttpLoggingInterceptor` at level `BODY` unconditionally, so every request body (card number,
  security code) and the `Authorization` header (merchant ID + session id) is written to
  logcat. Confirmed on an emulator in debug and release. The plugin switches the logging off in
  `SdkNetworkLogSilencer`; any app using the SDK directly is still affected, so this should be
  reported to the bank.
- **iOS** exposes `Gateway.loggingEnabled` and `Gateway.logRecorder`; the plugin sets both
  before every call.
- Both SDKs pin certificates for `*.gateway.mastercard.com` (pin expiry noted as 2038 in the
  release notes). The iOS SDK does it through `URLSessionDelegate`.
- Gateway error bodies contain `error.cause`, `error.field`, `error.validationType` (safe field
  names) and `error.explanation` (free text that can quote submitted values). The plugin keeps
  the first three and drops the explanation.
- The 3DS SDK reads device data (location, phone state, wifi, bluetooth on Android) **only if
  the host app already holds those permissions**; neither SDK manifest requests any permission,
  and neither declares `INTERNET`, which the plugin adds.
- iOS privacy manifests ship inside the frameworks: `Gateway` collects payment info, `uSDK`
  collects other usage data and declares file-timestamp and user-defaults API reasons.

## Release-build behavior (Android)

R8 full mode (default from AGP 8) strips the generic signatures Retrofit needs for the SDK's
`suspend` service methods, and every gateway call then fails with `ClassCastException` in
release builds only. `android/consumer-rules.pro` keeps `kotlin.coroutines.Continuation`,
`retrofit2.Call` and `retrofit2.Response`. Verified by running the integration tests inside a
release APK: they fail without the rules and pass with them. R8 also renames
`okhttp3.OkHttpClient`, which is why the log silencer derives the logger name from the class
instead of a string literal.

## Field names and payloads

- Manual card entry: `sourceOfFunds.provided.card.number`, `.securityCode`, `.expiry.month`,
  `.expiry.year`, `.nameOnCard`.
- Wallet token: `sourceOfFunds.provided.card.devicePayment.paymentToken`, plus
  `order.walletProvider` = `APPLE_PAY` (from the iOS guide) or `GOOGLE_PAY`. The Android guide
  shows the Google Pay update **without** `walletProvider` at all. MTF accepted and stored
  `GOOGLE_PAY` (seen in Retrieve Session), but `updateSession` only stores the token — the
  gateway does not decrypt it there — so acceptance is not proof the value is correct. The iOS
  guide additionally requires `order.walletProvider` on the request that *completes* the
  payment (`AUTHORIZE`/`PAY`), not only on the session. Both points are with the bank.
- **Device payments need the `Device Payments` merchant privilege**, which the bank enables per
  environment. Without it the wallet flow looks healthy all the way to the session:
  `updateSession` returns `updateStatus: SUCCESS` and the token is stored, and only the
  server's `AUTHORIZE` fails, with `INVALID_REQUEST` / "Missing merchant privilege 'Device
  Payments'". Observed on MTF, merchant `TESTONELYMOSDK`, September 2026; the identical
  `AUTHORIZE` succeeds on that merchant when the session holds a manually entered card, which
  is what isolates the privilege as the cause.
- `GatewayMap` splits keys on `.` and supports array indices with the pattern `(.*)\[(.*)\]`
  (verified in bytecode), so `order.item[0].name` is valid. `GatewayFields` allows exactly that
  shape.
- Google Pay tokenization: `type: PAYMENT_GATEWAY`, `gateway: mpgs`, `gatewayMerchantId:` the
  gateway merchant ID (from the Android guide). The allowed authentication methods
  (`PAN_ONLY`, `CRYPTOGRAM_3DS`) come from the Google Pay API, not from the bank guide.

## Authentication results

Both SDKs report the same ten error types, which the plugin maps identically:
`ChallengeCancelledByUser`, `ChallengeTimedOut`,
`RecommendationResubmitWithAlternativePaymentDetails`, `RecommendationAbandonOrder`,
`RecommendationDoNotProceed`, `RecommendationUnknown` (payment outcomes) and `NotInitialized`,
`MissingParameter`, `InvalidChallengeCompletionURL`, `Other` (failures).

Behavior seen in the Android bytecode:

- 3DS not available for the card → `PROCEED` with `authenticationPerformed = false`;
- frictionless → `PROCEED` with `challengePerformed = false`;
- payer closes the challenge → `DO_NOT_PROCEED` with `ChallengeCancelledByUser`.

The iOS response additionally carries `sdkTransactionId` and `threeDS2TransactionStatus`; the
Android one does not, so those fields are `null` there.

`updateSession` failures are **not** wrapped by the Android SDK: Retrofit's `HttpException`,
`IOException` and Gson parse errors surface as they are. The iOS SDK has a typed `GatewayError`
(`failedRequest(status, message)`, `invalidAPIVersion`, `missingResponse`,
`unexpectedResponseType`).
