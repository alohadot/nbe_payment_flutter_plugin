package com.example.nbe_payment_flutter_plugin.sdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.example.nbe_payment_flutter_plugin.bridge.gatewayBridgeError
import com.example.nbe_payment_flutter_plugin.generated.DeviceWallet
import com.example.nbe_payment_flutter_plugin.generated.SessionMessage
import com.example.nbe_payment_flutter_plugin.generated.WalletOutcomeMessage
import com.example.nbe_payment_flutter_plugin.generated.WalletRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.WalletResultMessage
import com.example.nbe_payment_flutter_plugin.generated.errorCodeInvalidArgument
import com.example.nbe_payment_flutter_plugin.generated.errorCodeInvalidGatewayResponse
import com.example.nbe_payment_flutter_plugin.generated.errorCodeOperationInProgress
import com.example.nbe_payment_flutter_plugin.generated.errorCodeUiUnavailable
import com.example.nbe_payment_flutter_plugin.generated.errorCodeWalletConfigurationInvalid
import com.example.nbe_payment_flutter_plugin.generated.errorCodeWalletConfigurationInvalid
import com.example.nbe_payment_flutter_plugin.generated.errorCodeWalletFailed
import com.google.android.gms.common.api.Status
import com.google.android.gms.wallet.IsReadyToPayRequest
import com.google.android.gms.wallet.PaymentDataRequest
import com.google.android.gms.wallet.PaymentsClient
import com.google.android.gms.wallet.Wallet
import com.google.android.gms.wallet.WalletConstants
import com.mastercard.gateway.android.sdk.GatewayAPI
import com.mastercard.gateway.android.sdk.GatewayCallback
import com.mastercard.gateway.android.sdk.GatewayMap
import com.mastercard.gateway.android.sdk.GooglePayCallback
import com.mastercard.gateway.android.sdk.GooglePayHandler
import org.json.JSONObject

/**
 * Google Pay flow on Android: availability check, payment sheet, and storing the resulting
 * token in the gateway session.
 *
 * The Gateway SDK launches the sheet with `startActivityForResult`, so the answer arrives in
 * [handleActivityResult], forwarded by the plugin's Activity result listener. The pending
 * payment is kept here (engine scope), not in the Activity, so a recreated Activity can still
 * deliver the result. It does not survive process death.
 *
 * All methods run on the main thread.
 */
internal class GooglePayController(
    private val context: Context,
    private val activityProvider: () -> Activity?,
) {

    private class PendingPayment(
        val session: SessionMessage,
        val callback: (Result<WalletResultMessage>) -> Unit,
    )

    private var pendingPayment: PendingPayment? = null
    private val pendingAvailabilityChecks = mutableListOf<(Result<DeviceWallet>) -> Unit>()

    /**
     * Fails everything still waiting, because the Activity or the engine is going away and the
     * Google Pay result can no longer be delivered.
     *
     * Without this a pending payment would hold the operation lock for the lifetime of the
     * process and every later call would report "operation in progress".
     */
    fun abortPendingOperations() {
        val payment = pendingPayment
        pendingPayment = null
        val availabilityChecks = pendingAvailabilityChecks.toList()
        pendingAvailabilityChecks.clear()

        val error = failure<Nothing>(
            errorCodeUiUnavailable,
            "The screen that started Google Pay went away before it finished.",
        ).exceptionOrNull()!!
        payment?.callback?.invoke(Result.failure(error))
        availabilityChecks.forEach { it(Result.failure(error)) }
    }

    fun getAvailableWallet(request: WalletRequestMessage, callback: (Result<DeviceWallet>) -> Unit) {
        if (!request.isTestEnvironment && request.googlePayMerchantId.isNullOrBlank()) {
            // Reported as a configuration error rather than "no wallet", so a missing merchant
            // ID is not mistaken for a device without Google Pay.
            callback(
                failure(
                    errorCodeWalletConfigurationInvalid,
                    "A Google Pay merchant ID is required outside the test environment.",
                ),
            )
            return
        }

        val readyRequest = try {
            IsReadyToPayRequest.fromJson(buildIsReadyToPayRequestJson(request.supportedNetworks))
        } catch (error: Exception) {
            callback(
                failure(
                    errorCodeWalletConfigurationInvalid,
                    "The Google Pay availability request could not be built.",
                    nativeDetails = error.javaClass.simpleName,
                ),
            )
            return
        }

        // Tracked so the answer can be dropped if the engine goes away while Google Play
        // services is still deciding.
        pendingAvailabilityChecks += callback
        paymentsClient(request).isReadyToPay(readyRequest).addOnCompleteListener { task ->
            if (!pendingAvailabilityChecks.remove(callback)) return@addOnCompleteListener
            // A failed task means Google Play services or Google Pay is not usable here, which
            // is an availability answer rather than an error for this check.
            val isReady = task.isSuccessful && task.result == true
            callback(Result.success(if (isReady) DeviceWallet.GOOGLE_PAY else DeviceWallet.NONE))
        }
    }

    fun pay(
        request: WalletRequestMessage,
        gatewayMerchantId: String,
        callback: (Result<WalletResultMessage>) -> Unit,
    ) {
        val session = request.session
        if (session == null) {
            callback(failure(errorCodeInvalidArgument, "A session is required for a wallet payment."))
            return
        }
        if (!request.isTestEnvironment && request.googlePayMerchantId.isNullOrBlank()) {
            callback(
                failure(
                    errorCodeWalletConfigurationInvalid,
                    "A Google Pay merchant ID is required outside the test environment.",
                ),
            )
            return
        }
        if (pendingPayment != null) {
            callback(failure(errorCodeOperationInProgress, "A Google Pay payment is already in progress."))
            return
        }
        val activity = activityProvider()
        if (activity == null || activity.isFinishing || activity.isDestroyed) {
            callback(
                failure(
                    errorCodeUiUnavailable,
                    "No visible Android Activity is available to present Google Pay.",
                ),
            )
            return
        }

        val paymentDataRequest = try {
            PaymentDataRequest.fromJson(buildPaymentDataRequestJson(request, session, gatewayMerchantId))
        } catch (error: Exception) {
            callback(
                failure(
                    errorCodeWalletConfigurationInvalid,
                    "The Google Pay request could not be built.",
                    nativeDetails = error.javaClass.simpleName,
                ),
            )
            return
        }

        pendingPayment = PendingPayment(session, callback)
        try {
            GooglePayHandler.requestData(activity, paymentsClient(request), paymentDataRequest)
        } catch (error: Exception) {
            pendingPayment = null
            callback(
                failure(
                    errorCodeWalletFailed,
                    "Google Pay could not be started.",
                    nativeDetails = error.javaClass.simpleName,
                ),
            )
        }
    }

    /** @return `true` when the result belonged to a Google Pay payment started by the plugin. */
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        val payment = pendingPayment ?: return false
        var isAnswered = false

        // The SDK checks the request code itself and returns false for results that are not
        // its Google Pay request, leaving them to other listeners.
        val isGooglePayResult = GooglePayHandler.handleActivityResult(
            requestCode,
            resultCode,
            data,
            object : GooglePayCallback {
                override fun onSuccess(paymentData: JSONObject) {
                    isAnswered = true
                    pendingPayment = null
                    storeTokenInSession(payment, paymentData)
                }

                override fun onCancelled() {
                    isAnswered = true
                    pendingPayment = null
                    payment.callback(
                        Result.success(
                            WalletResultMessage(
                                outcome = WalletOutcomeMessage.CANCELLED,
                                wallet = DeviceWallet.GOOGLE_PAY,
                            ),
                        ),
                    )
                }

                override fun onError(status: Status) {
                    isAnswered = true
                    pendingPayment = null
                    payment.callback(
                        failure(
                            errorCodeWalletFailed,
                            "Google Pay reported an error.",
                            nativeDetails = "Google Pay status ${status.statusCode}",
                        ),
                    )
                }
            },
        )

        // The SDK consumes its request code for any result code, but only calls back for the
        // three it knows. An unexpected result code would otherwise leave the payment pending
        // and the operation lock held forever.
        if (isGooglePayResult && !isAnswered) {
            pendingPayment = null
            payment.callback(
                failure(
                    errorCodeWalletFailed,
                    "Google Pay returned an unexpected result.",
                    nativeDetails = "Activity result code $resultCode",
                ),
            )
        }
        return isGooglePayResult
    }

    private fun storeTokenInSession(payment: PendingPayment, paymentData: JSONObject) {
        val parsed = try {
            parseGooglePayPaymentData(paymentData.toString())
        } catch (error: IllegalArgumentException) {
            payment.callback(failure(errorCodeInvalidGatewayResponse, error.message ?: "Invalid Google Pay response."))
            return
        }

        SdkNetworkLogSilencer.silence()
        // The token is only handed to the SDK; it is never logged or returned to Flutter.
        GatewayAPI.updateSession(
            toSdkSession(payment.session),
            buildGooglePayTokenPayload(parsed.token),
            object : GatewayCallback {
                override fun onSuccess(response: GatewayMap) {
                    payment.callback(
                        Result.success(
                            WalletResultMessage(
                                outcome = WalletOutcomeMessage.COMPLETED,
                                wallet = DeviceWallet.GOOGLE_PAY,
                                cardDescription = parsed.description,
                            ),
                        ),
                    )
                }

                override fun onError(throwable: Throwable) {
                    payment.callback(Result.failure(gatewayRequestBridgeError(throwable)))
                }
            },
        )
    }

    private fun paymentsClient(request: WalletRequestMessage): PaymentsClient = Wallet.getPaymentsClient(
        context,
        Wallet.WalletOptions.Builder()
            .setEnvironment(
                if (request.isTestEnvironment) WalletConstants.ENVIRONMENT_TEST else WalletConstants.ENVIRONMENT_PRODUCTION,
            )
            .build(),
    )

    private fun <T> failure(code: String, message: String, nativeDetails: String? = null): Result<T> =
        Result.failure(gatewayBridgeError(code = code, message = message, nativeDetails = nativeDetails))
}
