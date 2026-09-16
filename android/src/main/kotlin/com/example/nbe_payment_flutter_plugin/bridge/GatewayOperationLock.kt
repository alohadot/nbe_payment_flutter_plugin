package com.example.nbe_payment_flutter_plugin.bridge

import androidx.annotation.VisibleForTesting
import com.example.nbe_payment_flutter_plugin.generated.GatewayBridgeError

/**
 * Allows one gateway operation at a time, for the whole process.
 *
 * The lock is process-wide, not per Flutter engine, because the state it protects is: the
 * Gateway SDK objects (`GatewaySDK`, `GatewayAPI`, `AuthenticationHandler`) are singletons, so
 * two engines in one app must not authenticate at the same time.
 *
 * Main-thread only; no synchronization needed.
 */
internal object GatewayOperationLock {

    /** Fails the running operation, if any. Set while an operation holds the lock. */
    private var failRunningOperation: ((GatewayBridgeError) -> Unit)? = null

    val isBusy: Boolean get() = failRunningOperation != null

    fun acquire(failOperation: (GatewayBridgeError) -> Unit) {
        failRunningOperation = failOperation
    }

    fun release() {
        failRunningOperation = null
    }

    /**
     * Fails the running operation and releases the lock.
     *
     * Used when the operation can no longer finish, for example when the engine goes away
     * while a wallet sheet is open: without this the lock would stay held for the lifetime of
     * the process and every later call would report "operation in progress".
     */
    fun abortRunningOperation(error: GatewayBridgeError) {
        val failOperation = failRunningOperation ?: return
        failRunningOperation = null
        failOperation(error)
    }

    @VisibleForTesting
    fun resetForTesting() {
        failRunningOperation = null
    }
}
