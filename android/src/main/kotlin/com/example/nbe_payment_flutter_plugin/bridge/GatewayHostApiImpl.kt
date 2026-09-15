package com.example.nbe_payment_flutter_plugin.bridge

import com.example.nbe_payment_flutter_plugin.generated.AuthenticateRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.AuthenticationResultMessage
import com.example.nbe_payment_flutter_plugin.generated.CardMessage
import com.example.nbe_payment_flutter_plugin.generated.DeviceWallet
import com.example.nbe_payment_flutter_plugin.generated.GatewayFieldMessage
import com.example.nbe_payment_flutter_plugin.generated.InitializeRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.NbeGatewayHostApi
import com.example.nbe_payment_flutter_plugin.generated.SessionMessage
import com.example.nbe_payment_flutter_plugin.generated.WalletRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.WalletResultMessage
import com.example.nbe_payment_flutter_plugin.generated.errorCodeOperationInProgress
import com.example.nbe_payment_flutter_plugin.generated.errorCodeUnknown
import com.example.nbe_payment_flutter_plugin.sdk.GatewaySdkAdapter

/**
 * Implements the Pigeon host API on Android.
 *
 * Responsibilities kept here, and nothing SDK-specific:
 * - allow one gateway operation at a time;
 * - answer Flutter exactly once per call;
 * - never let a raw exception reach the channel (Pigeon would attach its stack trace).
 *
 * Pigeon invokes these methods on the main thread and the adapter answers on the main
 * thread, so the state below needs no synchronization.
 */
class GatewayHostApiImpl(private val sdkAdapter: GatewaySdkAdapter) : NbeGatewayHostApi {

    private var isOperationInProgress = false

    override fun initialize(request: InitializeRequestMessage, callback: (Result<Unit>) -> Unit) {
        runExclusively(callback) { complete -> sdkAdapter.initialize(request, complete) }
    }

    override fun updateSessionWithCard(
        session: SessionMessage,
        card: CardMessage,
        additionalFields: List<GatewayFieldMessage>?,
        callback: (Result<Unit>) -> Unit,
    ) {
        runExclusively(callback) { complete ->
            sdkAdapter.updateSessionWithCard(session, card, additionalFields, complete)
        }
    }

    override fun authenticatePayer(
        request: AuthenticateRequestMessage,
        callback: (Result<AuthenticationResultMessage>) -> Unit,
    ) {
        runExclusively(callback) { complete -> sdkAdapter.authenticatePayer(request, complete) }
    }

    override fun getAvailableWallet(
        request: WalletRequestMessage,
        callback: (Result<DeviceWallet>) -> Unit,
    ) = callback(notImplementedYet("getAvailableWallet"))

    override fun payWithDeviceWallet(
        request: WalletRequestMessage,
        callback: (Result<WalletResultMessage>) -> Unit,
    ) = callback(notImplementedYet("payWithDeviceWallet"))

    private fun <T> runExclusively(
        callback: (Result<T>) -> Unit,
        operation: (complete: (Result<T>) -> Unit) -> Unit,
    ) {
        if (isOperationInProgress) {
            callback(
                Result.failure(
                    gatewayBridgeError(
                        code = errorCodeOperationInProgress,
                        message = "Another gateway operation is still running.",
                    ),
                ),
            )
            return
        }

        isOperationInProgress = true
        var isCompleted = false
        val complete: (Result<T>) -> Unit = { result ->
            // An SDK that reports twice must not produce a second reply to Flutter.
            if (!isCompleted) {
                isCompleted = true
                isOperationInProgress = false
                callback(result)
            }
        }

        try {
            operation(complete)
        } catch (error: Exception) {
            complete(Result.failure(unexpectedBridgeError(error)))
        }
    }

    // Temporary: replaced method by method in the next implementation steps.
    private fun <T> notImplementedYet(method: String): Result<T> = Result.failure(
        gatewayBridgeError(
            code = errorCodeUnknown,
            message = "$method is not implemented on Android yet.",
        ),
    )
}
