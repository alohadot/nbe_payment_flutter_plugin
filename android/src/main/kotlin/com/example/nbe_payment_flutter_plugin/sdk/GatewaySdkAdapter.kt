package com.example.nbe_payment_flutter_plugin.sdk

import com.example.nbe_payment_flutter_plugin.generated.CardMessage
import com.example.nbe_payment_flutter_plugin.generated.GatewayFieldMessage
import com.example.nbe_payment_flutter_plugin.generated.InitializeRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.SessionMessage

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
}
