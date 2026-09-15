package com.example.nbe_payment_flutter_plugin.sdk

import com.example.nbe_payment_flutter_plugin.generated.CardNetwork
import com.example.nbe_payment_flutter_plugin.generated.SessionMessage
import com.example.nbe_payment_flutter_plugin.generated.WalletRequestMessage
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class GooglePayRequestsTest {

    private val session = SessionMessage(
        id = "SESSION0002",
        orderId = "ORDER-1",
        amount = "150.00",
        currency = "EGP",
        apiVersion = "100",
    )

    private fun walletRequest(googlePayMerchantId: String? = null) = WalletRequestMessage(
        merchantDisplayName = "My Store",
        countryCode = "EG",
        supportedNetworks = listOf(CardNetwork.VISA, CardNetwork.MASTERCARD),
        isTestEnvironment = true,
        googlePayMerchantId = googlePayMerchantId,
        session = session,
    )

    private fun parse(json: String): JsonObject = JsonParser.parseString(json).asJsonObject

    private fun JsonObject.cardMethod() = getAsJsonArray("allowedPaymentMethods")[0].asJsonObject

    @Test
    fun paymentDataRequestUsesTheMpgsTokenizationFromTheIntegrationGuide() {
        val json = parse(buildPaymentDataRequestJson(walletRequest(), session, "TESTONELYMOSDK"))

        val tokenization = json.cardMethod().getAsJsonObject("tokenizationSpecification")
        assertEquals("PAYMENT_GATEWAY", tokenization["type"].asString)
        assertEquals("mpgs", tokenization.getAsJsonObject("parameters")["gateway"].asString)
        assertEquals("TESTONELYMOSDK", tokenization.getAsJsonObject("parameters")["gatewayMerchantId"].asString)
    }

    @Test
    fun paymentDataRequestTakesAmountAndCurrencyFromTheSession() {
        val json = parse(buildPaymentDataRequestJson(walletRequest(), session, "M"))

        val transaction = json.getAsJsonObject("transactionInfo")
        assertEquals("150.00", transaction["totalPrice"].asString)
        assertEquals("EGP", transaction["currencyCode"].asString)
        assertEquals("EG", transaction["countryCode"].asString)
        assertEquals("FINAL", transaction["totalPriceStatus"].asString)
        assertEquals(2, json["apiVersion"].asInt)
    }

    @Test
    fun networksAndMerchantInfoAreMapped() {
        val json = parse(buildPaymentDataRequestJson(walletRequest("BCR2DN"), session, "M"))

        val networks = json.cardMethod().getAsJsonObject("parameters").getAsJsonArray("allowedCardNetworks")
        assertEquals(listOf("VISA", "MASTERCARD"), networks.map { it.asString })
        assertEquals("My Store", json.getAsJsonObject("merchantInfo")["merchantName"].asString)
        assertEquals("BCR2DN", json.getAsJsonObject("merchantInfo")["merchantId"].asString)
    }

    @Test
    fun merchantIdIsOmittedWhenNotConfigured() {
        val json = parse(buildPaymentDataRequestJson(walletRequest(), session, "M"))

        assertFalse(json.getAsJsonObject("merchantInfo").has("merchantId"))
    }

    @Test
    fun readyToPayRequestHasNoTokenizationOrTransaction() {
        val json = parse(buildIsReadyToPayRequestJson(listOf(CardNetwork.AMEX)))

        assertFalse(json.cardMethod().has("tokenizationSpecification"))
        assertFalse(json.has("transactionInfo"))
        assertEquals(
            listOf("AMEX"),
            json.cardMethod().getAsJsonObject("parameters").getAsJsonArray("allowedCardNetworks").map { it.asString },
        )
    }

    @Test
    fun everyNetworkHasAGooglePayName() {
        assertEquals(
            listOf("VISA", "MASTERCARD", "AMEX", "DISCOVER", "JCB"),
            CardNetwork.values().map(::toGooglePayNetwork),
        )
    }

    @Test
    fun parsesTokenAndDescriptionWithoutPrintingTheToken() {
        val parsed = parseGooglePayPaymentData(
            """{"apiVersion":2,"paymentMethodData":{"type":"CARD","description":"Visa •••• 1111",""" +
                """"tokenizationData":{"type":"PAYMENT_GATEWAY","token":"{\"signature\":\"secret\"}"}}}""",
        )

        assertEquals("{\"signature\":\"secret\"}", parsed.token)
        assertEquals("Visa •••• 1111", parsed.description)
        assertFalse(parsed.toString().contains("secret"))
    }

    @Test
    fun descriptionIsOptional() {
        val parsed = parseGooglePayPaymentData(
            """{"paymentMethodData":{"tokenizationData":{"token":"t"}}}""",
        )

        assertNull(parsed.description)
    }

    @Test
    fun responsesWithoutTokenAreRejected() {
        assertFailsWith<IllegalArgumentException> { parseGooglePayPaymentData("""{"paymentMethodData":{}}""") }
        assertFailsWith<IllegalArgumentException> { parseGooglePayPaymentData("not json") }
    }

    @Test
    fun tokenPayloadSetsTokenAndWalletProvider() {
        val payload = buildGooglePayTokenPayload("token")

        assertEquals("token", payload["sourceOfFunds.provided.card.devicePayment.paymentToken"])
        assertEquals("GOOGLE_PAY", payload["order.walletProvider"])
        assertTrue(payload.containsKey("order.walletProvider"))
    }
}
