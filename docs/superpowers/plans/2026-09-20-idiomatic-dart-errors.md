# Idiomatic Dart Errors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the in-progress `GatewayResult` public API with ordinary Dart future values and typed `GatewayException` failures, then document safe payer-facing handling for every operation.

**Architecture:** Keep exceptions as the internal cross-layer carrier and let them pass through the public `Future<T>` boundary. Preserve sealed models for genuine payment outcomes, preserve native typed rejection metadata, and put localization/UX policy in the consuming app with comprehensive API documentation and examples.

**Tech Stack:** Dart 3.6+, Flutter 3.27+, Pigeon, Kotlin/JUnit, Swift/XCTest, Markdown.

**Spec:** `docs/superpowers/specs/2026-09-20-idiomatic-dart-errors-design.md`

## Global Constraints

- Dart SDK stays `^3.6.0`; Flutter stays `>=3.27.0`.
- Do not edit generated Pigeon files; the channel constants and generated outputs are already current.
- Preserve `GatewayException.cause`, `field`, `validationType`, `httpStatusCode`, and sanitized `nativeDetails` end to end.
- Never expose card data, CVV, wallet tokens, raw gateway bodies, or untrusted native messages.
- Natural payer outcomes return values; technical/integration failures throw `GatewayException`.
- Keep version 0.2.0 and describe it as typed rejection metadata plus saved-card/API documentation improvements, not a switch to result wrappers.

## Review Focus

- A native `PlatformException` must still emerge as the same public `GatewayException`, including typed rejection fields.
- A validation failure inside every async gateway method must be catchable through the returned future.
- `AuthenticationNotProceeded`, `WalletPaymentCancelled`, and `DeviceWallet.none` must return normally rather than throw.
- The one-operation lock must release after a thrown failure and reject overlap with `operationInProgress`.
- Documentation must never recommend displaying `message` or `nativeDetails` directly to a payer.

---

### Task 1: Restore the public Future/exception contract

**Files:**
- Modify: `test/api/nbe_payment_gateway_test.dart`
- Modify: `lib/src/api/nbe_payment_gateway.dart`
- Modify: `lib/nbe_payment_flutter_plugin.dart`
- Delete: `lib/src/models/gateway_result.dart`
- Modify: `lib/src/models/gateway_exception.dart`
- Modify: `lib/src/models/authentication.dart`
- Modify: `lib/src/models/device_wallet.dart`

**Interfaces:**
- Consumes: existing internal `GatewayException`, `toGatewayException`, authentication and wallet models.
- Produces: the six `Future<T>` signatures in the spec and a public `GatewayException` export.

- [ ] **Step 1: Rewrite focused API tests to express the desired contract**

Use direct returned values on success and `throwsA(isA<GatewayException>()...)` on failure. Add an assertion that typed rejection fields survive through the public method:

```dart
await expectLater(
  gateway.updateSessionWithCard(_session, _card),
  throwsA(
    isA<GatewayException>()
        .having((e) => e.code, 'code', GatewayErrorCode.gatewayRejected)
        .having((e) => e.field, 'field', GatewayFieldNames.securityCode)
        .having(
          (e) => e.validationType,
          'validationType',
          GatewayValidationType.invalid,
        ),
  ),
);
```

Also restore direct assertions for `AuthenticationResult`, `DeviceWallet`, and
`WalletPaymentResult`, and verify cancellation/decline values do not throw.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
C:\flutter_src\flutter_windows_3.41.9-stable\flutter\bin\flutter.bat test test/api/nbe_payment_gateway_test.dart
```

Expected: failures because the current methods return `GatewayResult<T>` instead of direct
values/exceptions.

- [ ] **Step 3: Implement the minimal public API change**

Remove `_guard` and `_guardVoid`; restore direct async method bodies and signatures. Export the
whole `gateway_exception.dart`, remove the `gateway_result.dart` export and file, and correct
model documentation from “technical failures are results” to “technical failures complete the
future with `GatewayException`.” Do not change native mapping or Pigeon.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the same command. Expected: all tests in `nbe_payment_gateway_test.dart` pass.

- [ ] **Step 5: Run the complete Dart suite**

```powershell
C:\flutter_src\flutter_windows_3.41.9-stable\flutter\bin\flutter.bat test
```

Expected: all tests pass.

### Task 2: Update the executable examples and integration contract

**Files:**
- Modify: `example/lib/payment_test_page.dart`
- Modify: `example/integration_test/plugin_integration_test.dart`

**Interfaces:**
- Consumes: Task 1 direct `Future<T>` API and public `GatewayException`.
- Produces: an example app and integration tests that demonstrate safe exception handling.

- [ ] **Step 1: Change integration expectations first**

Replace result-unwrapping helpers with `throwsA`/`try-on GatewayException`, and assert direct
values for wallet and authentication outcomes. Keep the real-channel nature of the integration
tests; do not add a fake end-to-end test.

- [ ] **Step 2: Run the analyzable test target and verify RED**

Run analyzer before changing the example implementation. Expected: type errors where the example
still expects `GatewayResult<T>` or references `GatewayFailure`.

- [ ] **Step 3: Update the example app**

Make `_run` accept operations that return `OperationOutcome` and catch only
`GatewayException` for expected payment failures. Convert direct authentication/wallet values
into outcomes, retain an explicit catch for unexpected exceptions as plugin bugs, and keep logs
free of sensitive values.

- [ ] **Step 4: Run analyzer and the Dart suite**

Expected: no analyzer issues and all Dart tests pass.

### Task 3: Write complete public API and error UX documentation

**Files:**
- Modify: `README.md`
- Modify: public Dartdoc in `lib/src/api/nbe_payment_gateway.dart`
- Modify: `example/README.md` if its call examples use the old result wrapper.

**Interfaces:**
- Consumes: Task 1 signatures, `GatewayErrorCode`, rejection enums, authentication reasons, and wallet outcomes.
- Produces: copy-pasteable Flutter usage and an operation-by-operation error/UX reference.

- [ ] **Step 1: Rewrite the quick start and full payment flows**

Show `try/on GatewayException`, direct authentication and wallet switches, backend payment after
`AuthenticationProceed`, and field-level handling through `GatewayFieldNames`.

- [ ] **Step 2: Add an “Errors and payer-facing messages” section**

For each of `initialize`, card update, security-code update, authentication, wallet availability,
and wallet payment, document:

- input and success value;
- normal non-error outcomes;
- relevant error codes;
- safe suggested UX copy/action;
- retry cautions where transaction state may be uncertain.

State prominently that apps must not display `message` or `nativeDetails` directly and that
localization belongs to the app. Include a centralized mapper example branching on stable codes.

- [ ] **Step 3: Correct every stale result/throw statement**

Search README, Dartdoc, and example docs for `GatewayResult`, `GatewaySuccess`, `GatewayFailure`,
“throws nothing,” and contradictory “technical failures are results” text. Preserve discussion of
natural authentication and wallet outcomes.

- [ ] **Step 4: Run analyzer**

Expected: Dartdoc snippets and public member docs introduce no analyzer issue.

### Task 4: Align architecture, decisions, changelog, and maintainer status

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `doc/ARCHITECTURE.md`
- Modify: `doc/DECISIONS.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: completed public contract and UX documentation.
- Produces: one consistent explanation for future maintainers.

- [ ] **Step 1: Rewrite the 0.2.0 changelog entry**

Describe public `GatewayException` with typed rejection metadata, retained direct future return
types, and the documented distinction between normal outcomes and technical failures.

- [ ] **Step 2: Update architecture and decision records**

Document the public future error channel, the internal/native mapping flow, why natural outcomes
are values, and why a universal result wrapper was rejected as non-idiomatic and nested.

- [ ] **Step 3: Update maintainer instructions and test counts**

Remove the result-wrapper invariant, preserve the security and one-operation invariants, and set
the exact test count only after the final suite reports it.

- [ ] **Step 4: Repository-wide consistency scan**

```powershell
rg -n "GatewayResult|GatewaySuccess|GatewayFailure|throws nothing|returns everything" README.md CHANGELOG.md CLAUDE.md doc example lib test
```

Expected: no stale public-contract claims; any intentional historical mention explains that the
wrapper was rejected rather than used.

### Task 5: Final compatibility verification

**Files:**
- No intended source changes; fix only failures proven by these commands.

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces: verified 0.2.0 worktree ready for device/Mac release gates.

- [ ] **Step 1: Format changed Dart files and verify the diff**

Run Dart format on hand-written Dart files only. Do not reformat or edit generated files. Run
`git diff --check` and inspect `git status --short` to preserve unrelated user changes.

- [ ] **Step 2: Run current-toolchain analyzer and Dart tests separately**

```powershell
C:\flutter_src\flutter_windows_3.41.9-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
C:\flutter_src\flutter_windows_3.41.9-stable\flutter\bin\flutter.bat test
```

Expected: no analyzer issues and all tests pass.

- [ ] **Step 3: Run Android JVM tests**

```powershell
cd example\android
.\gradlew.bat :nbe_payment_flutter_plugin:testDebugUnitTest
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 4: Verify Flutter 3.27 compatibility**

Use a temporary pubspec copy or carefully reversible dependency edit so Pigeon 27.3.0 and
flutter_lints 6 do not prevent dependency resolution. Run Flutter 3.27.4 analyze/test and the
example debug APK build, then restore the exact working-tree pubspec.

- [ ] **Step 5: Report remaining platform release gates**

List iOS compilation/device testing, Google Pay/Apple Pay device testing, forced OTP challenge,
and saved-card CVV end-to-end testing as unverified rather than claiming them complete.
