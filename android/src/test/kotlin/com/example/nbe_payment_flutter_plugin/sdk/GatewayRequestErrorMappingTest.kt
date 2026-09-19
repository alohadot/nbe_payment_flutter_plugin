package com.example.nbe_payment_flutter_plugin.sdk

import com.example.nbe_payment_flutter_plugin.generated.errorCodeGatewayRejected
import com.example.nbe_payment_flutter_plugin.generated.errorCodeInvalidGatewayResponse
import com.example.nbe_payment_flutter_plugin.generated.errorCodeNetwork
import com.example.nbe_payment_flutter_plugin.generated.errorCodeNotInitialized
import com.example.nbe_payment_flutter_plugin.generated.errorCodeUnknown
import com.example.nbe_payment_flutter_plugin.generated.errorDetailsGatewayCause
import com.example.nbe_payment_flutter_plugin.generated.errorDetailsGatewayField
import com.example.nbe_payment_flutter_plugin.generated.errorDetailsGatewayValidationType
import com.example.nbe_payment_flutter_plugin.generated.errorDetailsHttpStatusCode
import com.example.nbe_payment_flutter_plugin.generated.errorDetailsNative
import com.google.gson.JsonSyntaxException
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.ResponseBody.Companion.toResponseBody
import retrofit2.HttpException
import retrofit2.Response
import java.net.SocketTimeoutException
import javax.net.ssl.SSLPeerUnverifiedException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull

internal class GatewayRequestErrorMappingTest {

    private fun httpException(status: Int, body: String) = HttpException(
        Response.error<Any>(status, body.toResponseBody("application/json".toMediaType())),
    )

    private fun details(error: com.example.nbe_payment_flutter_plugin.generated.GatewayBridgeError) =
        error.details as Map<*, *>

    @Test
    fun httpErrorsKeepStatusAndGatewayErrorCodesButNotTheExplanation() {
        val error = gatewayRequestBridgeError(
            httpException(
                400,
                """{"error":{"cause":"INVALID_REQUEST","explanation":"Value '5123450000000008' is invalid",""" +
                    """"field":"sourceOfFunds.provided.card.number","validationType":"INVALID"},"result":"ERROR"}""",
            ),
        )

        assertEquals(errorCodeGatewayRejected, error.code)
        assertEquals(400, details(error)[errorDetailsHttpStatusCode])
        assertEquals(
            "HTTP 400; cause=INVALID_REQUEST; field=sourceOfFunds.provided.card.number; validationType=INVALID",
            details(error)[errorDetailsNative],
        )
        assertFalse(error.toString().contains("5123450000000008"))
        assertFalse(details(error).values.joinToString().contains("5123450000000008"))
    }

    @Test
    fun httpErrorsCarryTheGatewayRejectionFieldsSeparately() {
        val error = gatewayRequestBridgeError(
            httpException(
                400,
                """{"error":{"cause":"INVALID_REQUEST","explanation":"Value '100' is invalid",""" +
                    """"field":"sourceOfFunds.provided.card.securityCode","validationType":"INVALID"}}""",
            ),
        )

        // The app needs these as values, not inside a diagnostic string: they are what turns
        // "something went wrong" into "check the security code".
        assertEquals("INVALID_REQUEST", details(error)[errorDetailsGatewayCause])
        assertEquals(
            "sourceOfFunds.provided.card.securityCode",
            details(error)[errorDetailsGatewayField],
        )
        assertEquals("INVALID", details(error)[errorDetailsGatewayValidationType])
    }

    @Test
    fun httpErrorsWithoutRejectionFieldsCarryNone() {
        val error = gatewayRequestBridgeError(httpException(401, """{"error":{"explanation":"nope"}}"""))

        assertEquals(errorCodeGatewayRejected, error.code)
        assertFalse(details(error).containsKey(errorDetailsGatewayCause))
        assertFalse(details(error).containsKey(errorDetailsGatewayField))
        assertFalse(details(error).containsKey(errorDetailsGatewayValidationType))
    }

    @Test
    fun httpErrorsWithAnUnreadableBodyKeepOnlyTheStatus() {
        val error = gatewayRequestBridgeError(httpException(502, "<html>Bad gateway</html>"))

        assertEquals(errorCodeGatewayRejected, error.code)
        assertEquals("HTTP 502", details(error)[errorDetailsNative])
    }

    @Test
    fun ioFailuresAreNetworkErrors() {
        val timeout = gatewayRequestBridgeError(SocketTimeoutException("timeout"))
        val pinning = gatewayRequestBridgeError(SSLPeerUnverifiedException("Certificate pinning failure"))

        assertEquals(errorCodeNetwork, timeout.code)
        assertEquals("SocketTimeoutException", details(timeout)[errorDetailsNative])
        assertEquals(errorCodeNetwork, pinning.code)
        assertEquals("SSLPeerUnverifiedException", details(pinning)[errorDetailsNative])
    }

    @Test
    fun unreadableResponsesAreInvalidGatewayResponses() {
        val error = gatewayRequestBridgeError(JsonSyntaxException("bad json"))

        assertEquals(errorCodeInvalidGatewayResponse, error.code)
    }

    @Test
    fun usingTheSdkBeforeInitializationIsNotInitialized() {
        val error = gatewayRequestBridgeError(
            UninitializedPropertyAccessException("lateinit property gatewayService has not been initialized"),
        )

        assertEquals(errorCodeNotInitialized, error.code)
        assertNull(error.details)
    }

    @Test
    fun otherFailuresKeepOnlyTheirType() {
        val error = gatewayRequestBridgeError(IllegalStateException("card 5123450000000008"))

        assertEquals(errorCodeUnknown, error.code)
        assertEquals("IllegalStateException", details(error)[errorDetailsNative])
    }
}
