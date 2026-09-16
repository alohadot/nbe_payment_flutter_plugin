package com.example.nbe_payment_flutter_plugin.bridge

import android.content.Intent
import com.example.nbe_payment_flutter_plugin.generated.AuthenticateRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.CardNetwork
import com.example.nbe_payment_flutter_plugin.generated.DeviceWallet
import com.example.nbe_payment_flutter_plugin.generated.WalletRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.WalletResultMessage
import com.example.nbe_payment_flutter_plugin.generated.AuthenticationOutcomeMessage
import com.example.nbe_payment_flutter_plugin.generated.AuthenticationResultMessage
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
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
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

        val pendingAuthenticationCallbacks =
            mutableListOf<(Result<AuthenticationResultMessage>) -> Unit>()

        override fun authenticatePayer(
            request: AuthenticateRequestMessage,
            callback: (Result<AuthenticationResultMessage>) -> Unit,
        ) {
            calls += "authenticatePayer"
            pendingAuthenticationCallbacks += callback
        }

        val pendingAvailabilityCallbacks = mutableListOf<(Result<DeviceWallet>) -> Unit>()
        val pendingWalletCallbacks = mutableListOf<(Result<WalletResultMessage>) -> Unit>()

        override fun getAvailableWallet(request: WalletRequestMessage, callback: (Result<DeviceWallet>) -> Unit) {
            calls += "getAvailableWallet"
            pendingAvailabilityCallbacks += callback
        }

        override fun payWithDeviceWallet(
            request: WalletRequestMessage,
            callback: (Result<WalletResultMessage>) -> Unit,
        ) {
            calls += "payWithDeviceWallet"
            pendingWalletCallbacks += callback
        }

        override fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?) = false

        var activityDetachedCount = 0

        override fun onActivityDetached() {
            activityDetachedCount++
        }
    }

    private val walletRequest = WalletRequestMessage(
        merchantDisplayName = "My Store",
        countryCode = "EG",
        supportedNetworks = listOf(CardNetwork.VISA),
        isTestEnvironment = true,
        session = session,
    )

    @Test
    fun walletAvailabilityRunsWhileAnotherOperationIsInProgress() {
        initialize()
        val availability = mutableListOf<Result<DeviceWallet>>()

        hostApi.getAvailableWallet(walletRequest) { availability += it }
        adapter.pendingAvailabilityCallbacks.single()(Result.success(DeviceWallet.GOOGLE_PAY))

        assertEquals(listOf("initialize", "getAvailableWallet"), adapter.calls)
        assertEquals(DeviceWallet.GOOGLE_PAY, availability.single().getOrNull())
    }

    @Test
    fun walletPaymentIsExclusive() {
        val walletResults = mutableListOf<Result<WalletResultMessage>>()
        hostApi.payWithDeviceWallet(walletRequest) { walletResults += it }

        initialize()

        assertEquals(listOf("payWithDeviceWallet"), adapter.calls)
        assertEquals(errorCodeOperationInProgress, results.single().bridgeError().code)
    }

    private val adapter = ControllableSdkAdapter()
    private val hostApi = GatewayHostApiImpl(adapter)
    private val results = mutableListOf<Result<Unit>>()

    // The lock is process-wide, so every test starts from a released one.
    @BeforeTest
    fun releaseLock() = GatewayOperationLock.resetForTesting()

    @AfterTest
    fun releaseLockAfterwards() = GatewayOperationLock.resetForTesting()

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
    fun authenticationIsForwardedAndBlocksOtherOperationsUntilItCompletes() {
        val authenticationResults = mutableListOf<Result<AuthenticationResultMessage>>()
        val request = AuthenticateRequestMessage(session = session, authenticationTransactionId = "AUTH-1")

        hostApi.authenticatePayer(request) { authenticationResults += it }
        hostApi.updateSessionWithCard(session, card, null) { results += it }

        assertEquals(listOf("authenticatePayer"), adapter.calls)
        assertEquals(errorCodeOperationInProgress, results.single().bridgeError().code)

        val message = AuthenticationResultMessage(
            outcome = AuthenticationOutcomeMessage.PROCEED,
            authenticationPerformed = true,
            challengePerformed = true,
            authenticationTransactionId = "AUTH-1",
        )
        adapter.pendingAuthenticationCallbacks.single()(Result.success(message))

        assertEquals(message, authenticationResults.single().getOrNull())
    }

    @Test
    fun disposeFailsTheRunningOperationAndReleasesTheLock() {
        initialize()

        hostApi.dispose()

        assertEquals(errorCodeUnknown, results.single().bridgeError().code)
        assertFalse(GatewayOperationLock.isBusy)

        // The gateway is usable again after the engine is re-attached.
        initialize()
        assertEquals(2, adapter.pendingCallbacks.size)
    }

    @Test
    fun anSdkAnswerAfterDisposeIsIgnored() {
        initialize()
        hostApi.dispose()

        adapter.pendingCallbacks.single()(Result.success(Unit))

        assertEquals(1, results.size)
    }

    @Test
    fun disposeWithoutARunningOperationDoesNothing() {
        hostApi.dispose()

        assertTrue(results.isEmpty())
        assertFalse(GatewayOperationLock.isBusy)
    }

    @Test
    fun theLockIsSharedBetweenHostApiInstances() {
        // Two Flutter engines in one process share the SDK singletons.
        val otherHostApi = GatewayHostApiImpl(ControllableSdkAdapter())

        initialize()
        otherHostApi.initialize(request) { results += it }

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
