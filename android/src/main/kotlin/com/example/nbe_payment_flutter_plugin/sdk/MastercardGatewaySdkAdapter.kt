package com.example.nbe_payment_flutter_plugin.sdk

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.example.nbe_payment_flutter_plugin.bridge.gatewayBridgeError
import com.example.nbe_payment_flutter_plugin.generated.AuthenticateRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.AuthenticationResultMessage
import com.example.nbe_payment_flutter_plugin.generated.CardMessage
import com.example.nbe_payment_flutter_plugin.generated.DeviceWallet
import com.example.nbe_payment_flutter_plugin.generated.WalletRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.WalletResultMessage
import com.example.nbe_payment_flutter_plugin.generated.GatewayFieldMessage
import com.example.nbe_payment_flutter_plugin.generated.InitializeRequestMessage
import com.example.nbe_payment_flutter_plugin.generated.SessionMessage
import com.example.nbe_payment_flutter_plugin.generated.errorCodeAlreadyInitialized
import com.example.nbe_payment_flutter_plugin.generated.errorCodeInitializationFailed
import com.example.nbe_payment_flutter_plugin.generated.errorCodeInvalidArgument
import com.example.nbe_payment_flutter_plugin.generated.errorCodeNotInitialized
import com.example.nbe_payment_flutter_plugin.generated.errorCodeUiUnavailable
import com.mastercard.gateway.android.sdk.AuthenticationCallback
import com.mastercard.gateway.android.sdk.AuthenticationHandler
import com.mastercard.gateway.android.sdk.AuthenticationResponse
import com.mastercard.gateway.android.sdk.GatewayAPI
import com.mastercard.gateway.android.sdk.GatewayCallback
import com.mastercard.gateway.android.sdk.GatewayMap
import com.mastercard.gateway.android.sdk.GatewaySDK
import com.mastercard.gateway.android.sdk.InitializationCallback
import org.emvco.threeds.core.exceptions.InvalidInputException
import org.emvco.threeds.core.ui.UiCustomization

/**
 * [GatewaySdkAdapter] backed by the Mastercard Gateway Android SDK.
 *
 * @param activityProvider returns the Activity currently attached to the Flutter engine, or
 * `null`. It is asked at the moment an operation needs UI, so a destroyed Activity is never
 * kept or reused.
 */
class MastercardGatewaySdkAdapter(
    private val context: Context,
    private val activityProvider: () -> Activity?,
) : GatewaySdkAdapter {

    private val mainHandler = Handler(Looper.getMainLooper())

    private val googlePay = GooglePayController(context, activityProvider)

    private val challengeGuard = ChallengeScreenGuard(
        application = context.applicationContext as? Application,
        mainHandler = mainHandler,
    )

    override fun initialize(request: InitializeRequestMessage, callback: (Result<Unit>) -> Unit) {
        // The SDK keeps process-wide state that outlives a Flutter hot restart or a second
        // engine, so a repeated initialize must be checked against the SDK, not only Dart.
        //
        // Only the merchant identity is compared: challenge appearance and locale are applied
        // by the SDK at initialization and cannot be changed afterwards, so a new value for
        // them must not turn a repeated initialize into a hard failure.
        val previousRequest = lastSuccessfulInitializeRequest
        if (GatewaySDK.initialized && previousRequest != null) {
            callback(
                if (previousRequest.describesSameMerchant(request)) {
                    Result.success(Unit)
                } else {
                    Result.failure(
                        gatewayBridgeError(
                            code = errorCodeAlreadyInitialized,
                            message = "The Gateway SDK is already initialized with a different configuration.",
                        ),
                    )
                },
            )
            return
        }

        val application = context.applicationContext as? Application
        if (application == null) {
            callback(
                Result.failure(
                    gatewayBridgeError(
                        code = errorCodeInitializationFailed,
                        message = "The Android application context is unavailable.",
                    ),
                ),
            )
            return
        }

        val uiCustomization = try {
            request.challengeUi?.let(::toSdkUiCustomization) ?: UiCustomization()
        } catch (error: InvalidInputException) {
            callback(
                Result.failure(
                    gatewayBridgeError(
                        code = errorCodeInvalidArgument,
                        message = "The challenge UI customization was rejected by the 3DS SDK.",
                        nativeDetails = error.message,
                    ),
                ),
            )
            return
        }

        // The callback is delivered on the main thread by the SDK.
        GatewaySDK.initialize(
            application,
            request.merchantId,
            request.merchantName,
            request.merchantUrl,
            toSdkRegion(request.region),
            uiCustomization,
            object : InitializationCallback {
                override fun onSuccess() {
                    SdkNetworkLogSilencer.silence()
                    lastSuccessfulInitializeRequest = request
                    callback(Result.success(Unit))
                }

                override fun onError(throwable: Throwable) {
                    callback(
                        Result.failure(
                            gatewayBridgeError(
                                code = errorCodeInitializationFailed,
                                message = "The Gateway SDK failed to initialize.",
                                // Initialization carries no payer data, so the SDK message is
                                // safe and useful for diagnosing configuration problems.
                                nativeDetails = "${throwable.javaClass.simpleName}: ${throwable.message}",
                            ),
                        ),
                    )
                }
            },
        )
    }

    override fun updateSessionWithCard(
        session: SessionMessage,
        card: CardMessage,
        additionalFields: List<GatewayFieldMessage>?,
        callback: (Result<Unit>) -> Unit,
    ) = updateSession(session, callback) {
        buildUpdateSessionWithCardPayload(card, additionalFields)
    }

    override fun updateSessionWithSecurityCode(
        session: SessionMessage,
        securityCode: String,
        additionalFields: List<GatewayFieldMessage>?,
        callback: (Result<Unit>) -> Unit,
    ) = updateSession(session, callback) {
        buildUpdateSessionWithSecurityCodePayload(securityCode, additionalFields)
    }

    /**
     * Sends one update-session request to the gateway.
     *
     * [buildPayload] runs only once the SDK state has been checked. The payload holds payer
     * data, so it is handed to the SDK and never logged or stored.
     */
    private fun updateSession(
        session: SessionMessage,
        callback: (Result<Unit>) -> Unit,
        buildPayload: () -> GatewayMap,
    ) {
        // Without this check the SDK fails with an UninitializedPropertyAccessException.
        if (!GatewaySDK.initialized) {
            callback(
                Result.failure(
                    gatewayBridgeError(
                        code = errorCodeNotInitialized,
                        message = "The Gateway SDK is not initialized.",
                    ),
                ),
            )
            return
        }

        val payload = try {
            buildPayload()
        } catch (error: IllegalArgumentException) {
            callback(
                Result.failure(
                    gatewayBridgeError(
                        code = errorCodeInvalidArgument,
                        message = error.message ?: "Invalid gateway field.",
                    ),
                ),
            )
            return
        }

        // Must run before every gateway call: the SDK would otherwise log the card to logcat.
        SdkNetworkLogSilencer.silence()

        // Both callbacks are delivered on the main thread by the SDK.
        GatewayAPI.updateSession(
            toSdkSession(session),
            payload,
            object : GatewayCallback {
                override fun onSuccess(response: GatewayMap) {
                    callback(Result.success(Unit))
                }

                override fun onError(throwable: Throwable) {
                    callback(Result.failure(gatewayRequestBridgeError(throwable)))
                }
            },
        )
    }

    override fun authenticatePayer(
        request: AuthenticateRequestMessage,
        callback: (Result<AuthenticationResultMessage>) -> Unit,
    ) {
        if (!GatewaySDK.initialized) {
            callback(
                Result.failure(
                    gatewayBridgeError(
                        code = errorCodeNotInitialized,
                        message = "The Gateway SDK is not initialized.",
                    ),
                ),
            )
            return
        }

        // The challenge screen is started from this Activity. Without one (app in background,
        // engine running headless) the SDK cannot show it, so fail clearly instead of crashing.
        val activity = activityProvider()
        if (activity == null || activity.isFinishing || activity.isDestroyed) {
            callback(
                Result.failure(
                    gatewayBridgeError(
                        code = errorCodeUiUnavailable,
                        message = "No visible Android Activity is available to present 3-D Secure authentication.",
                    ),
                ),
            )
            return
        }

        val payload = try {
            buildGatewayFieldsPayload(request.authenticatePayerFields)
        } catch (error: IllegalArgumentException) {
            callback(
                Result.failure(
                    gatewayBridgeError(
                        code = errorCodeInvalidArgument,
                        message = error.message ?: "Invalid gateway field.",
                    ),
                ),
            )
            return
        }

        val session = toSdkSession(request.session)
        val transactionId = request.authenticationTransactionId
        val authenticationCallback = object : AuthenticationCallback {
            override fun onComplete(response: AuthenticationResponse) {
                // The bridge answers Flutter from the main thread; do not rely on the SDK's
                // choice of dispatcher for this callback.
                runOnMainThread {
                    challengeGuard.stop()
                    callback(toAuthenticationResult(response, transactionId))
                }
            }
        }

        // The challenge screen belongs to the 3DS SDK: its back button has to be bridged, and
        // it must never be able to disappear without an outcome, or the gateway lock would be
        // held for the life of the process. A late answer from the SDK is dropped by the
        // bridge, which replies to Flutter exactly once.
        challengeGuard.start(activity) {
            callback(Result.success(abandonedChallengeResult(transactionId)))
        }

        SdkNetworkLogSilencer.silence()
        // An empty map is also the SDK's own default for this parameter.
        AuthenticationHandler.authenticate(
            activity,
            session,
            transactionId,
            payload ?: GatewayMap(),
            authenticationCallback,
        )
    }

    override fun getAvailableWallet(request: WalletRequestMessage, callback: (Result<DeviceWallet>) -> Unit) {
        googlePay.getAvailableWallet(request, callback)
    }

    override fun payWithDeviceWallet(
        request: WalletRequestMessage,
        callback: (Result<WalletResultMessage>) -> Unit,
    ) {
        // The gateway merchant ID must be the one the SDK was initialized with, because the
        // token is stored in a session of that merchant.
        val gatewayMerchantId = lastSuccessfulInitializeRequest?.merchantId
        if (!GatewaySDK.initialized || gatewayMerchantId == null) {
            callback(
                Result.failure(
                    gatewayBridgeError(
                        code = errorCodeNotInitialized,
                        message = "The Gateway SDK is not initialized.",
                    ),
                ),
            )
            return
        }
        googlePay.pay(request, gatewayMerchantId, callback)
    }

    override fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean =
        googlePay.handleActivityResult(requestCode, resultCode, data)

    override fun onActivityDetached() {
        googlePay.abortPendingOperations()
    }

    private fun runOnMainThread(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) action() else mainHandler.post(action)
    }

    private companion object {
        // Mirrors the SDK's own process-wide lifetime.
        @Volatile
        var lastSuccessfulInitializeRequest: InitializeRequestMessage? = null

        fun InitializeRequestMessage.describesSameMerchant(
            other: InitializeRequestMessage,
        ): Boolean = merchantId == other.merchantId &&
            merchantName == other.merchantName &&
            merchantUrl == other.merchantUrl &&
            region == other.region
    }
}
