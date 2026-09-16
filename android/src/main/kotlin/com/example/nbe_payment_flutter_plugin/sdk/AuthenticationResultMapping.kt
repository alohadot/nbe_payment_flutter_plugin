package com.example.nbe_payment_flutter_plugin.sdk

import com.example.nbe_payment_flutter_plugin.bridge.gatewayBridgeError
import com.example.nbe_payment_flutter_plugin.bridge.sanitizedSdkDetail
import com.example.nbe_payment_flutter_plugin.generated.AuthenticationOutcomeMessage
import com.example.nbe_payment_flutter_plugin.generated.AuthenticationResultMessage
import com.example.nbe_payment_flutter_plugin.generated.errorCodeInvalidChallengeCompletionUrl
import com.example.nbe_payment_flutter_plugin.generated.errorCodeMissingSessionParameter
import com.example.nbe_payment_flutter_plugin.generated.errorCodeNotInitialized
import com.example.nbe_payment_flutter_plugin.generated.errorCodeUnknown
import com.mastercard.gateway.android.sdk.AuthenticationError
import com.mastercard.gateway.android.sdk.AuthenticationRecommendation
import com.mastercard.gateway.android.sdk.AuthenticationResponse

/**
 * Converts the Android SDK authentication response into the contract.
 *
 * The SDK reports every outcome through `AuthenticationResponse`: payment outcomes (declines,
 * cancellation) become result messages, while integration and technical failures become
 * channel errors.
 *
 * Authentication requests carry no card data (the card is already in the session), so SDK error
 * texts help diagnose gateway configuration problems. They are unbounded third-party text
 * (from the SDK, the 3DS server or the issuer), so they are shortened before being sent.
 */
internal fun toAuthenticationResult(
    response: AuthenticationResponse,
    authenticationTransactionId: String,
): Result<AuthenticationResultMessage> {
    fun outcome(outcome: AuthenticationOutcomeMessage) = Result.success(
        AuthenticationResultMessage(
            outcome = outcome,
            authenticationPerformed = response.authenticationPerformed,
            challengePerformed = response.challengePerformed,
            authenticationTransactionId = authenticationTransactionId,
            // Not reported by the Android SDK.
            sdkTransactionId = null,
            threeDS2TransactionStatus = null,
        ),
    )

    if (response.recommendation == AuthenticationRecommendation.PROCEED) {
        return outcome(AuthenticationOutcomeMessage.PROCEED)
    }

    return when (val error = response.error) {
        null -> outcome(AuthenticationOutcomeMessage.DO_NOT_PROCEED)

        is AuthenticationError.ChallengeCancelledByUser ->
            outcome(AuthenticationOutcomeMessage.CANCELLED_BY_USER)
        is AuthenticationError.ChallengeTimedOut ->
            outcome(AuthenticationOutcomeMessage.CHALLENGE_TIMED_OUT)
        is AuthenticationError.RecommendationResubmitWithAlternativePaymentDetails ->
            outcome(AuthenticationOutcomeMessage.RESUBMIT_WITH_ALTERNATIVE_PAYMENT_DETAILS)
        is AuthenticationError.RecommendationAbandonOrder ->
            outcome(AuthenticationOutcomeMessage.ABANDON_ORDER)
        is AuthenticationError.RecommendationDoNotProceed ->
            outcome(AuthenticationOutcomeMessage.DO_NOT_PROCEED)
        is AuthenticationError.RecommendationUnknown ->
            outcome(AuthenticationOutcomeMessage.UNKNOWN_RECOMMENDATION)

        is AuthenticationError.NotInitialized -> Result.failure(
            gatewayBridgeError(
                code = errorCodeNotInitialized,
                message = "The Gateway SDK is not initialized.",
                nativeDetails = sanitizedSdkDetail(error.error),
            ),
        )
        is AuthenticationError.MissingParameter -> Result.failure(
            gatewayBridgeError(
                code = errorCodeMissingSessionParameter,
                message = "The session is missing fields required for authentication.",
                nativeDetails = sanitizedSdkDetail(error.error),
            ),
        )
        is AuthenticationError.InvalidChallengeCompletionURL -> Result.failure(
            gatewayBridgeError(
                code = errorCodeInvalidChallengeCompletionUrl,
                message = "The 3DS challenge completion URL is invalid.",
                // Everything after "?" is dropped: a challenge URL's query can carry tokens.
                nativeDetails = sanitizedSdkDetail(error.error.substringBefore('?')),
            ),
        )
        is AuthenticationError.Other -> Result.failure(
            gatewayBridgeError(
                code = errorCodeUnknown,
                message = "Payer authentication failed.",
                nativeDetails = sanitizedSdkDetail("AuthenticationError.Other: ${error.error}"),
            ),
        )

        // Network and gateway failures from the authentication requests are surfaced raw by
        // the SDK, exactly like update-session failures.
        else -> Result.failure(gatewayRequestBridgeError(error))
    }
}
