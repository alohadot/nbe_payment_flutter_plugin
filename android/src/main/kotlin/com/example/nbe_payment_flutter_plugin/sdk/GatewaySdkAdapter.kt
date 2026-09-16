package com.example.nbe_payment_flutter_plugin.sdk

import android.content.Intent
import com.example.nbe_payment_flutter_plugin.generated.AuthenticateRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.AuthenticationResultMessage
import com.example.nbe_payment_flutter_plugin.generated.CardMessage
import com.example.nbe_payment_flutter_plugin.generated.DeviceWallet
import com.example.nbe_payment_flutter_plugin.generated.GatewayFieldMessage
import com.example.nbe_payment_flutter_plugin.generated.InitializeRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.SessionMessage
import com.example.nbe_payment_flutter_plugin.generated.WalletRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.WalletResultMessage

/**
 * Boundary between the Pigeon bridge and the Mastercard Gateway Android SDK.
 *
 * Implementations own every SDK-specific concern: SDK types, callbacks, threading and the
 * translation of SDK failures into channel errors. Failures are delivered as
 * `GatewayBridgeError` inside the [Result].
 *
 * Callbacks are invoked on the main thread.
 */
interface GatewaySdkAdapter {
    fun initialize(request: InitializeRequestMessage, callback: (Result<Unit>) -> Unit)

    /**
     * Stores [card] (and optional [additionalFields]) in the gateway session.
     * Implementations must not log or retain the card after the call.
     */
    fun updateSessionWithCard(
        session: SessionMessage,
        card: CardMessage,
        additionalFields: List<GatewayFieldMessage>?,
        callback: (Result<Unit>) -> Unit,
    )

    /**
     * Stores only [securityCode] (and optional [additionalFields]) in a session that already
     * holds a card. No other `sourceOfFunds` field is sent, so the stored card is left
     * untouched. Implementations must not log or retain the security code after the call.
     */
    fun updateSessionWithSecurityCode(
        session: SessionMessage,
        securityCode: String,
        additionalFields: List<GatewayFieldMessage>?,
        callback: (Result<Unit>) -> Unit,
    )

    /**
     * Runs 3-D Secure payer authentication. May present the issuer challenge screen over the
     * current Activity.
     */
    fun authenticatePayer(
        request: AuthenticateRequestMessage,
        callback: (Result<AuthenticationResultMessage>) -> Unit,
    )

    /** Reports whether Google Pay can be used on this device. Presents no UI. */
    fun getAvailableWallet(request: WalletRequestMessage, callback: (Result<DeviceWallet>) -> Unit)

    /** Shows the Google Pay sheet and stores the resulting token in the session. */
    fun payWithDeviceWallet(request: WalletRequestMessage, callback: (Result<WalletResultMessage>) -> Unit)

    /**
     * Receives Activity results forwarded by the plugin.
     *
     * @return `true` if the result belonged to an operation started by this adapter.
     */
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean

    /**
     * Called when the Activity that started a native screen goes away. Implementations must
     * fail anything that waits for that screen's result.
     */
    fun onActivityDetached()
}
