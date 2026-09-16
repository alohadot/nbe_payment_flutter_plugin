package com.example.nbe_payment_flutter_plugin.sdk

import com.example.nbe_payment_flutter_plugin.generated.CardMessage
import com.example.nbe_payment_flutter_plugin.generated.GatewayFieldMessage
import com.example.nbe_payment_flutter_plugin.generated.SessionMessage
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse

internal class SessionPayloadsTest {

    private val card = CardMessage(
        number = "5123450000000008",
        securityCode = "100",
        expiryMonth = "01",
        expiryYear = "39",
        nameOnCard = "Test User",
    )

    @Test
    fun sessionKeepsEveryField() {
        val session = toSdkSession(
            SessionMessage(
                id = "SESSION0002",
                orderId = "ORDER-1",
                amount = "150.00",
                currency = "EGP",
                apiVersion = "100",
            ),
        )

        assertEquals("SESSION0002", session.id)
        assertEquals("ORDER-1", session.orderId)
        assertEquals("150.00", session.amount)
        assertEquals("EGP", session.currency)
        assertEquals("100", session.apiVersion)
    }

    @Test
    fun cardFieldsUseTheIntegrationGuideKeys() {
        val payload = buildUpdateSessionWithCardPayload(card, null)

        assertEquals("5123450000000008", payload["sourceOfFunds.provided.card.number"])
        assertEquals("100", payload["sourceOfFunds.provided.card.securityCode"])
        assertEquals("01", payload["sourceOfFunds.provided.card.expiry.month"])
        assertEquals("39", payload["sourceOfFunds.provided.card.expiry.year"])
        assertEquals("Test User", payload["sourceOfFunds.provided.card.nameOnCard"])
    }

    @Test
    fun anAbsentNameOnCardIsOmitted() {
        val payload = buildUpdateSessionWithCardPayload(
            CardMessage(
                number = "5123450000000008",
                securityCode = "100",
                expiryMonth = "01",
                expiryYear = "39",
            ),
            null,
        )

        assertEquals("100", payload["sourceOfFunds.provided.card.securityCode"])
        assertFalse(payload.containsKey("sourceOfFunds.provided.card.nameOnCard"))
    }

    @Test
    fun additionalFieldsKeepTheirTypes() {
        val payload = buildUpdateSessionWithCardPayload(
            card,
            listOf(
                GatewayFieldMessage(key = "billing.address.city", stringValue = "Cairo"),
                GatewayFieldMessage(key = "order.itemCount", intValue = 2L),
                GatewayFieldMessage(key = "order.taxAmount", doubleValue = 1.5),
                GatewayFieldMessage(key = "customer.isReturning", boolValue = true),
            ),
        )

        assertEquals("Cairo", payload["billing.address.city"])
        assertEquals(2L, payload["order.itemCount"])
        assertEquals(1.5, payload["order.taxAmount"])
        assertEquals(true, payload["customer.isReturning"])
    }

    @Test
    fun cardFieldsCannotBeReplacedByAdditionalFields() {
        val payload = buildUpdateSessionWithCardPayload(
            card,
            listOf(GatewayFieldMessage(key = "sourceOfFunds.provided.card.number", stringValue = "4111111111111111")),
        )

        assertEquals("5123450000000008", payload["sourceOfFunds.provided.card.number"])
    }

    @Test
    fun additionalFieldWithoutValueIsRejectedWithoutItsValue() {
        val error = assertFailsWith<IllegalArgumentException> {
            buildUpdateSessionWithCardPayload(card, listOf(GatewayFieldMessage(key = "customer.email")))
        }

        assertEquals("Gateway field \"customer.email\" has no value.", error.message)
    }

    @Test
    fun securityCodePayloadCarriesTheSecurityCodeAndNothingElseFromTheCard() {
        val payload = buildUpdateSessionWithSecurityCodePayload("100", null)

        assertEquals("100", payload["sourceOfFunds.provided.card.securityCode"])
        assertFalse(payload.containsKey("sourceOfFunds.provided.card.number"))
        assertFalse(payload.containsKey("sourceOfFunds.provided.card.expiry.month"))
        assertFalse(payload.containsKey("sourceOfFunds.provided.card.expiry.year"))
        assertFalse(payload.containsKey("sourceOfFunds.provided.card.nameOnCard"))
    }

    @Test
    fun securityCodePayloadKeepsAdditionalFields() {
        val payload = buildUpdateSessionWithSecurityCodePayload(
            "100",
            listOf(GatewayFieldMessage(key = "billing.address.city", stringValue = "Cairo")),
        )

        assertEquals("Cairo", payload["billing.address.city"])
        assertEquals("100", payload["sourceOfFunds.provided.card.securityCode"])
    }

    @Test
    fun securityCodeCannotBeReplacedByAnAdditionalField() {
        val payload = buildUpdateSessionWithSecurityCodePayload(
            "100",
            listOf(
                GatewayFieldMessage(
                    key = "sourceOfFunds.provided.card.securityCode",
                    stringValue = "999",
                ),
            ),
        )

        assertEquals("100", payload["sourceOfFunds.provided.card.securityCode"])
    }

    @Test
    fun securityCodePayloadRejectsAnAdditionalFieldWithoutValueWithoutItsValue() {
        val error = assertFailsWith<IllegalArgumentException> {
            buildUpdateSessionWithSecurityCodePayload("100", listOf(GatewayFieldMessage(key = "customer.email")))
        }

        assertEquals("Gateway field \"customer.email\" has no value.", error.message)
    }
}
