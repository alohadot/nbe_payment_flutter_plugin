package com.example.nbe_payment_flutter_plugin.bridge

import com.example.nbe_payment_flutter_plugin.generated.CardMessage
import com.example.nbe_payment_flutter_plugin.generated.GatewayBridgeError
import com.example.nbe_payment_flutter_plugin.generated.GatewayFieldMessage
import com.example.nbe_payment_flutter_plugin.generated.GatewayRegion
import com.example.nbe_payment_flutter_plugin.generated.InitializeRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.SessionMessage
import com.example.nbe_payment_flutter_plugin.generated.errorCodeInitializationFailed
import com.example.nbe_payment_flutter_plugin.generated.errorCodeOperationInProgress
import com.example.nbe_payment_flutter_plugin.generated.errorCodeUnknown
import com.example.nbe_payment_flutter_plugin.generated.errorDetailsNative
import com.example.nbe_payment_flutter_plugin.sdk.GatewaySdkAdapter
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

internal class GatewayHostApiImplTest {

    private val request = InitializeRequestMessage(
        merchantId = "TESTNBE000123",
        merchantName = "My Store",
        merchantUrl = "https://mystore.example",
        region = GatewayRegion.MTF,
    )

    private val session = SessionMessage(
        id = "SESSION0002",
        orderId = "ORDER-1",
        amount = "150.00",
        currency = "EGP",
        apiVersion = "100",
    )

    private val card = CardMessage(number = "5123450000000008", expiryMonth = "01", expiryYear = "39")

    /** Keeps the adapter callback so each test decides when and how the SDK answers. */
    private class ControllableSdkAdapter : GatewaySdkAdapter {
        val pendingCallbacks = mutableListOf<(Result<Unit>) -> Unit>()
        val calls = mutableListOf<String>()
        var errorToThrow: Exception? = null

        override fun initialize(request: InitializeRequestMessage, callback: (Result<Unit>) -> Unit) {
            calls += "initialize"
            errorToThrow?.let { throw it }
            pendingCallbacks += callback
        }

        override fun updateSessionWithCard(
            session: SessionMessage,
            card: CardMessage,
            additionalFields: List<GatewayFieldMessage>?,
            callback: (Result<Unit>) -> Unit,
        ) {
            calls += "updateSessionWithCard"
            errorToThrow?.let { throw it }
            pendingCallbacks += callback
        }
    }

    private val adapter = ControllableSdkAdapter()
    private val hostApi = GatewayHostApiImpl(adapter)
    private val results = mutableListOf<Result<Unit>>()

    private fun initialize() = hostApi.initialize(request) { results += it }

    private fun Result<*>.bridgeError(): GatewayBridgeError =
        exceptionOrNull() as GatewayBridgeError

    @Test
    fun forwardsAdapterSuccess() {
        initialize()
        adapter.pendingCallbacks.single()(Result.success(Unit))

        assertEquals(listOf(Result.success(Unit)), results)
    }

    @Test
    fun forwardsAdapterFailureUnchanged() {
        val failure = gatewayBridgeError(errorCodeInitializationFailed, "failed")

        initialize()
        adapter.pendingCallbacks.single()(Result.failure(failure))

        assertEquals(failure, results.single().exceptionOrNull())
    }

    @Test
    fun rejectsASecondOperationWhileTheFirstIsRunning() {
        initialize()
        initialize()

        assertEquals(1, adapter.pendingCallbacks.size)
        assertEquals(errorCodeOperationInProgress, results.single().bridgeError().code)
    }

    @Test
    fun allowsTheNextOperationAfterCompletion() {
        initialize()
        adapter.pendingCallbacks.single()(Result.success(Unit))

        initialize()

        assertEquals(2, adapter.pendingCallbacks.size)
    }

    @Test
    fun repliesOnlyOnceWhenTheAdapterReportsTwice() {
        initialize()
        val callback = adapter.pendingCallbacks.single()
        callback(Result.success(Unit))
        callback(Result.success(Unit))

        assertEquals(1, results.size)
    }

    @Test
    fun convertsThrownExceptionsWithoutTheirMessage() {
        adapter.errorToThrow = IllegalStateException("card 5123450000000008")

        initialize()

        val error = results.single().bridgeError()
        assertEquals(errorCodeUnknown, error.code)
        val details = error.details as Map<*, *>
        assertEquals("IllegalStateException", details[errorDetailsNative])
        assertTrue(!error.toString().contains("5123450000000008"))
    }

    @Test
    fun forwardsUpdateSessionWithCardToTheAdapter() {
        hostApi.updateSessionWithCard(session, card, null) { results += it }
        adapter.pendingCallbacks.single()(Result.success(Unit))

        assertEquals(listOf("updateSessionWithCard"), adapter.calls)
        assertEquals(listOf(Result.success(Unit)), results)
    }

    @Test
    fun cardUpdateAndInitializeShareTheSameLock() {
        initialize()
        hostApi.updateSessionWithCard(session, card, null) { results += it }

        assertEquals(listOf("initialize"), adapter.calls)
        assertEquals(errorCodeOperationInProgress, results.single().bridgeError().code)
    }

    @Test
    fun releasesTheLockAfterAThrownException() {
        adapter.errorToThrow = IllegalStateException()
        initialize()
        adapter.errorToThrow = null

        initialize()

        assertEquals(1, adapter.pendingCallbacks.size)
    }
}
