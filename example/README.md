# NBE Payment Plugin — example app

The official demo and manual test app for `nbe_payment_flutter_plugin`. It uses only the
public plugin API, exactly like any host app, so a working example means the real integration
works.

It serves as:

- a usage reference for every plugin capability;
- a manual test harness against the Mastercard Gateway test environment (MTF);
- a verification app for the native integration on Android and iOS.

## Contents

- [Run the example](#run-the-example)
- [Test configuration](#test-configuration)
- [Create a test session](#create-a-test-session)
- [Screen overview](#screen-overview)
- [How to test each capability](#how-to-test-each-capability)
- [Lifecycle tests](#lifecycle-tests)
- [Common test errors](#common-test-errors)

## Run the example

```sh
git clone <company repository URL>
cd nbe_payment_flutter_plugin/example
flutter pub get
flutter devices
flutter run -d <device-id>
```

### Android setup

Nothing extra: `android/gradle.properties` already enables Jetifier, required by the bundled
3DS SDK. Google Pay needs a device (or emulator image with Google Play) signed in to a Google
account.

### iOS setup

```sh
cd ios && pod install && cd ..
flutter run -d <simulator-or-device-id>
```

For Apple Pay, add the Apple Pay capability with your merchant identifier to the `Runner`
target in Xcode. First-time iOS verification steps are in [`IOS_TESTING.md`](IOS_TESTING.md).

## Test configuration

The app starts in the **MTF test environment**. The yellow banner at the top always shows the
selected region; any production region turns it red and asks for confirmation before
initializing.

| Field | Where it comes from |
|---|---|
| Merchant ID | Your MTF test merchant (from the bank). |
| Merchant name, merchant URL | Your merchant details. Used by the Android SDK only. |
| Google Pay merchant ID | Google Pay & Wallet Console. Not needed in MTF. |
| Apple Pay merchant identifier | Apple Developer account. Needed for Apple Pay on iOS. |
| Session values | Created by your server or the Postman collection (below). |

Never put an API password, real cards or production credentials in the app or the repository.
The card fields are prefilled with a public Mastercard test card.

## Create a test session

Sessions need the merchant API password, so they are created outside the app.

1. Import [`postman/nbe_mtf_payment_flow.postman_collection.json`](postman/nbe_mtf_payment_flow.postman_collection.json)
   into Postman.
2. Create a Postman environment with `merchantId` and `apiPassword` (type **secret**).
3. Keep `baseUrl = https://mtf.gateway.mastercard.com` — it must be the host of the region
   selected in the app.
4. Run **1. Create Session** and **2. Update Session**.
5. Open the **Visualize** tab of request 2 and copy Session ID, Order ID, Amount, Currency and
   API version into the app.

The collection also contains the server steps that finish a payment: Retrieve Session,
Authorize, Capture, Pay, Retrieve Order, Void and Refund. Its description explains the order.

Two things to know before running them:

- **Sessions expire quickly.** Create the session immediately before you use it. A gap of a
  few minutes ends in `Form Session not found or expired`.
- **For a wallet payment, set the `walletProvider` collection variable** to `GOOGLE_PAY` or
  `APPLE_PAY` before Authorize or Pay: the iOS guide requires `order.walletProvider` on the
  request that completes the payment, not only on the session. Clear it again for a card run —
  the value sent is printed in the Postman console so a leftover one is visible.

## Screen overview

| Section | Purpose |
|---|---|
| Banner | Region and initialization state. |
| Last result | Status (IDLE, PROCESSING, SUCCESS, FAILED, CANCELLED) and details of the last operation. |
| 1. Initialization | Region, merchant and wallet settings, Initialize. |
| 2. Session | Values from the server. |
| 3. Card | Card fields, Update session with card. |
| 3b. Saved card (CVV only) | Sends only the CVV typed above, for a session the server already filled with a saved card. |
| 4. 3-D Secure | Optional transaction ID, Authenticate payer. |
| 5. Device wallet | Check available wallet, Pay with device wallet. |
| Error and concurrency scenarios | Buttons that must end with a specific error code. |
| Events | Timestamped log of operations and app lifecycle changes; Clear events. |
| Debug information | Platform, plugin and native SDK versions, environment, build mode. |

Card data in the event log is always masked.

## How to test each capability

| Capability | Steps | Expected result |
|---|---|---|
| Initialize | Fill merchant fields → Initialize | `SUCCESS: Initialized` |
| Card update | Session 1+2 in Postman → copy values → Update session with card | `SUCCESS`; Postman **3. Retrieve Session** shows the card |
| Saved card (CVV only) | Create a session that already holds a saved card (our backend: `POST /api/v1/payment/mastercard/session` with `card_id`) → paste the session values → type the CVV → Update session with security code | `SUCCESS`; Postman **3. Retrieve Session** still shows the saved card, now with a security code. Skipping this step makes the server's PAY fail. |
| 3-D Secure | After card update → Authenticate payer | `PROCEED` (frictionless) or the OTP screen, then `PROCEED`. Copy the transaction ID. |
| Challenge cancel | Authenticate payer → close the challenge screen | `CANCELLED: NOT PROCEEDED (cancelledByUser)` |
| Server payment | Paste the transaction ID into Postman `authenticationTransactionId` → **4. Authorize** → **5. Capture** → **7. Retrieve Order** | Order `CAPTURED` |
| One-step payment | New session → card update → authenticate → **6. Pay** | Order `CAPTURED` |
| Wallet availability | Check available wallet | `googlePay` / `applePay` on a configured device, otherwise `none` |
| Wallet payment | New session → Pay with device wallet → authorize in the sheet | `SUCCESS: Session updated with …`; then set `walletProvider` and run Authorize or Pay in Postman. `Missing merchant privilege 'Device Payments'` there means the bank has not enabled device payments for this merchant — the plugin's part already succeeded. |
| Wallet cancel | Pay with device wallet → close the sheet | `CANCELLED` |

Error and concurrency scenarios:

| Button | Expected error code |
|---|---|
| Before initialize → notInitialized | `notInitialized` — only on a fresh app start before Initialize |
| Invalid card → invalidArgument | `invalidArgument` |
| API version 60 → invalidApiVersion | `invalidApiVersion` |
| Unknown session → gatewayRejected | `gatewayRejected` with an HTTP status |
| Card in extra fields → invalidArgument | `invalidArgument` |
| Double call → operationInProgress | One attempt reaches the gateway, the other is `operationInProgress` |

The double-call protection lives in the plugin, not in the example UI: buttons are never
disabled to hide concurrency issues.

## Lifecycle tests

- Send the app to the background and back, then run a card update.
- Rotate the device, then authenticate.
- Start an authentication with a challenge, background the app, return, finish the challenge.
- Make several payments in a row without restarting.
- Cancel a challenge, then authenticate again on the same session.
- Android: enable *Developer options → Don't keep activities* and repeat the above.

Lifecycle changes appear in the event log as `App lifecycle: …`.

## Common test errors

| Result | Cause |
|---|---|
| `gatewayRejected` HTTP 401 on card update | Session created on another host than the selected region (e.g. `test-gateway.mastercard.com` instead of `mtf.gateway.mastercard.com`), or another merchant ID. |
| `alreadyInitialized` | Merchant or region changed after initializing. Restart the app. |
| `invalidApiVersion` | API version below 61. Use the same version as the server. |
| `missingSessionParameter` | Postman request 2 was not run on this session. |
| `uiUnavailable` | The app was not in the foreground. |
| Wallet `none` on an emulator | No Google account / Google Play services (Android) or no Wallet card (iOS). |
| `walletConfigurationInvalid` on iOS | Apple Pay merchant identifier missing or capability not configured. |
