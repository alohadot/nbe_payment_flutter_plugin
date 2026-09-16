# Architecture

How the plugin is built and which rules must keep holding. The public contract is in the
README; this document is for people changing the plugin.

## Layers

```
Flutter app
    │  public models only
    ▼
NbePaymentGateway                lib/src/api
    │  validation, one-operation rule, transaction ids, initialization state
    ▼
Mappers                          lib/src/mappers
    │  public models <-> messages, channel errors -> GatewayException
    ▼
Generated Dart (Pigeon)          lib/src/generated
    │
 ═══ platform channel ═══
    │
    ├── Android                                    └── iOS
    │   NbePaymentFlutterPlugin                        NbePaymentFlutterPlugin
    │     engine + Activity + activity results           engine lifetime
    │   bridge/GatewayHostApiImpl                      Bridge/GatewayHostApiImpl
    │     one operation at a time, single reply           same
    │   sdk/MastercardGatewaySdkAdapter                SDK/MastercardGatewaySdkAdapter
    │     the only class that calls the bank SDK          same
    │   sdk/GooglePayController                        SDK/ApplePayController
    │   sdk/* mappings                                 SDK/ChallengePresentationHost, SDK/* mappings
    ▼                                                  ▼
Gateway Android SDK 2.0.17                          Gateway iOS SDK 2.0.14
```

Each layer only knows the one below it. The adapters are the only place that mentions a bank
SDK type; the bridge classes contain no SDK code at all.

## The contract

`pigeons/payment_api.dart` is the single source of truth for everything that crosses the
channel: message classes, the shared value enums, and the error-code constants. It generates
Dart, Kotlin and Swift, so a rename cannot drift between platforms.

Two kinds of types live there:

- **Messages** (`...Message`) are transport only. They are mutable and their generated
  `toString`/`description` prints every field, so they must never be exposed to app developers.
  Public models in `lib/src/models` are hand-written and mapped to them.
- **Plain value enums** (`GatewayRegion`, `DeviceWallet`, `CardNetwork`, the challenge enums)
  carry no data and no risk, so they are defined once and exported as public API. Changing one
  is a public API change.

There is no `@FlutterApi`: neither native SDK emits intermediate events, so every operation is
one call with one result.

## Invariants

1. **Validation happens in Dart**, before anything reaches native code, so both platforms
   reject the same input with the same error (`lib/src/validation`).
2. **Payment outcomes are results; technical failures are exceptions.** Sealed result types
   force the app to handle both outcomes; `GatewayException` always carries a stable
   `GatewayErrorCode`, never a message to branch on.
3. **One operation at a time**, checked in Dart and again in each native side with a
   process-wide lock (`GatewayOperationLock`), because the SDK objects are singletons shared by
   every Flutter engine in the app. `getAvailableWallet` is exempt: it shows no UI and changes
   no session.
4. **Every operation replies exactly once.** The bridges wrap each completion so a double
   answer from an SDK, or an abort racing a late answer, cannot produce a second reply.
5. **A pending operation is failed when its screen disappears.** Engine detach on both
   platforms, Activity detach on Android, presentation timeouts on iOS. A lock left held would
   block every later call for the life of the process.
6. **No card data in logs or errors.** No logging in the Dart layer; both SDKs' own HTTP logging
   is switched off; models mask their values; `nativeDetails` carries only sanitized text.
7. **Native UI hosts are resolved at the moment they are needed**, never stored: the current
   Activity on Android, the top-most visible view controller on iOS. Missing one is
   `uiUnavailable`, not a crash.
8. **Wallet tokens never reach Dart.** They go from the wallet sheet into the session inside
   native code; Dart only receives a display description such as `Visa ••••1234`.

## Initialization model

The native SDKs keep process-wide state with no way to re-initialize, so:

- only the merchant identity (merchant ID, name, URL, region) is fixed for the process;
- calling `initialize` again for the same merchant is accepted, which lets an app initialize
  early and add wallet identifiers later;
- challenge appearance and language are applied by the SDKs at initialization; a later value is
  stored for future calls but does not reach the running SDK (iOS can override per call);
- a different merchant or region throws `alreadyInitialized`;
- concurrent calls for the same merchant await the same initialization;
- after a hot restart, Dart state is empty while the native side is still initialized — both
  natives therefore compare against their own remembered request, not against Dart.

## Error model

```
native SDK failure
   │  adapter maps it (the only place that knows SDK error types)
   ▼
GatewayBridgeError(code, message, details)      code = constant from the contract
   │  platform channel
   ▼
PlatformException
   │  lib/src/mappers/gateway_error_mapper.dart
   ▼
GatewayException(code, message, httpStatusCode?, nativeDetails?)
```

Rules: every `GatewayErrorCode` maps to exactly one channel constant (a test enforces it); an
unrecognized code becomes `unknown` with its message and details dropped, because Pigeon fills
those with raw exception text for anything that escapes a bridge; free text from the SDK, the
3DS server or the issuer is shortened, and challenge URLs lose their query string.

## Testing levels

| Level | Location | Runs without a device |
|---|---|---|
| Dart unit | `test/` | yes |
| Android JVM unit | `android/src/test/` | yes |
| iOS unit | `example/ios/RunnerTests/` | needs Xcode |
| Integration, real SDK | `example/integration_test/` | needs a device and network |
| Integration in a release APK | same tests, release build | needs a device |
| Manual, real session | `example/` + Postman | needs a device and MTF merchant |

Integration tests use a non-existent session on purpose: they prove the path from Dart to the
gateway and the error mapping. A successful payment and an OTP challenge are manual tests.

## Where to add what

| Change | Files |
|---|---|
| New gateway capability | `pigeons/payment_api.dart` → regenerate → adapters (Kotlin/Swift) → mappers → `NbePaymentGateway` → public model → tests at every level → README |
| New error case | contract constant → adapter mapping → `GatewayErrorCode` → `gatewayErrorCodesByChannelCode` → README table |
| New validation rule | `lib/src/validation/input_validation.dart` + test |
| SDK upgrade | see the two "Updating the … native SDK" sections in the README |
