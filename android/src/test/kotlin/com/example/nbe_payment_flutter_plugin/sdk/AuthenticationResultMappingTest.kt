package com.example.nbe_payment_flutter_plugin.sdk

import com.example.nbe_payment_flutter_plugin.generated.AuthenticationOutcomeMessage
import com.example.nbe_payment_flutter_plugin.generated.GatewayBridgeError
import com.example.nbe_payment_flutter_plugin.generated.errorCodeGatewayRejected
import com.example.nbe_payment_flutter_plugin.generated.errorCodeInvalidChallengeCompletionUrl
import com.example.nbe_payment_flutter_plugin.generated.errorCodeMissingSessionParameter
import com.example.nbe_payment_flutter_plugin.generated.errorCodeNetwork
import com.example.nbe_payment_flutter_plugin.generated.errorCodeNotInitialized
import com.example.nbe_payment_flutter_plugin.generated.errorCodeUnknown
import com.mastercard.gateway.android.sdk.AuthenticationError
import com.mastercard.gateway.android.sdk.AuthenticationRecommendation
import com.mastercard.gateway.android.sdk.AuthenticationResponse
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.ResponseBody.Companion.toResponseBody
import retrofit2.HttpException
import retrofit2.Response
import java.io.IOException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class AuthenticationResultMappingTest {

    private fun response(
        recommendation: AuthenticationRecommendation = AuthenticationRecommendation.DO_NOT_PROCEED,
        error: Exception? = null,
        authenticationPerformed: Boolean = true,
        challengePerformed: Boolean = true,
    ) = AuthenticationResponse(recommendation, authenticationPerformed, challengePerformed, error)

    private fun outcomeOf(response: AuthenticationResponse) =
        toAuthenticationResult(response, "AUTH-1").getOrThrow().outcome

    private fun bridgeErrorOf(response: AuthenticationResponse) =
        toAuthenticationResult(response, "AUTH-1").exceptionOrNull() as GatewayBridgeError

    @Test
    fun proceedKeepsFlagsAndTheTransactionId() {
        val message = toAuthenticationResult(
            response(AuthenticationRecommendation.PROCEED, authenticationPerformed = false, challengePerformed = false),
            "AUTH-1",
        ).getOrThrow()

        assertEquals(AuthenticationOutcomeMessage.PROCEED, message.outcome)
        assertEquals("AUTH-1", message.authenticationTransactionId)
        assertFalse(message.authenticationPerformed)
        assertFalse(message.challengePerformed)
        assertNull(message.sdkTransactionId)
        assertNull(message.threeDS2TransactionStatus)
    }

    @Test
    fun proceedWinsEvenIfAnErrorIsAttached() {
        assertEquals(
            AuthenticationOutcomeMessage.PROCEED,
            outcomeOf(response(AuthenticationRecommendation.PROCEED, AuthenticationError.Other("ignored"))),
        )
    }

    @Test
    fun doNotProceedWithoutErrorIsADecline() {
        assertEquals(AuthenticationOutcomeMessage.DO_NOT_PROCEED, outcomeOf(response()))
    }

    @Test
    fun paymentOutcomesAreResultsNotErrors() {
        val expectations = mapOf(
            AuthenticationError.ChallengeCancelledByUser("x") to AuthenticationOutcomeMessage.CANCELLED_BY_USER,
            AuthenticationError.ChallengeTimedOut("x") to AuthenticationOutcomeMessage.CHALLENGE_TIMED_OUT,
            AuthenticationError.RecommendationResubmitWithAlternativePaymentDetails("x") to
                AuthenticationOutcomeMessage.RESUBMIT_WITH_ALTERNATIVE_PAYMENT_DETAILS,
            AuthenticationError.RecommendationAbandonOrder("x") to AuthenticationOutcomeMessage.ABANDON_ORDER,
            AuthenticationError.RecommendationDoNotProceed("x") to AuthenticationOutcomeMessage.DO_NOT_PROCEED,
            AuthenticationError.RecommendationUnknown("x") to AuthenticationOutcomeMessage.UNKNOWN_RECOMMENDATION,
        )

        for ((error, expected) in expectations) {
            assertEquals(expected, outcomeOf(response(error = error)), error.javaClass.simpleName)
        }
    }

    @Test
    fun integrationFailuresAreErrors() {
        assertEquals(
            errorCodeNotInitialized,
            bridgeErrorOf(response(error = AuthenticationError.NotInitialized("x"))).code,
        )
        assertEquals(
            errorCodeMissingSessionParameter,
            bridgeErrorOf(response(error = AuthenticationError.MissingParameter("order.amount"))).code,
        )
        assertEquals(
            errorCodeInvalidChallengeCompletionUrl,
            bridgeErrorOf(response(error = AuthenticationError.InvalidChallengeCompletionURL("x"))).code,
        )
    }

    @Test
    fun otherSdkErrorsKeepTheirTextForDiagnosis() {
        val error = bridgeErrorOf(response(error = AuthenticationError.Other("3DS server unavailable")))

        assertEquals(errorCodeUnknown, error.code)
        assertTrue((error.details as Map<*, *>).values.joinToString().contains("3DS server unavailable"))
    }

    @Test
    fun networkAndGatewayFailuresUseTheGatewayRequestMapping() {
        val http = HttpException(
            Response.error<Any>(401, "{}".toResponseBody("application/json".toMediaType())),
        )

        assertEquals(errorCodeGatewayRejected, bridgeErrorOf(response(error = http)).code)
        assertEquals(errorCodeNetwork, bridgeErrorOf(response(error = IOException())).code)
    }
}
