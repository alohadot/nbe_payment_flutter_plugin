package com.example.nbe_payment_flutter_plugin.sdk

import com.example.nbe_payment_flutter_plugin.generated.ButtonStyleMessage
import com.example.nbe_payment_flutter_plugin.generated.ChallengeButtonType
import com.example.nbe_payment_flutter_plugin.generated.GatewayRegion
import org.emvco.threeds.core.ui.ButtonType
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

// Only pure mapping is tested here. Building the SDK customization objects calls
// android.graphics.Color, which is not available in JVM unit tests; that path is exercised
// by the example app's integration tests on a device.
internal class SdkMappingTest {

    @Test
    fun everyRegionMapsToTheSdkRegionWithTheSameName() {
        for (region in GatewayRegion.values()) {
            assertEquals(region.name, toSdkRegion(region).name)
        }
    }

    @Test
    fun mtfMapsToTheTestHost() {
        assertTrue(toSdkRegion(GatewayRegion.MTF).baseUrl.contains("mtf.gateway.mastercard.com"))
    }

    @Test
    fun everyButtonTypeHasAnSdkButtonType() {
        val mapped = ChallengeButtonType.values().map(::toSdkButtonType)

        assertEquals(ButtonType.values().toSet(), mapped.toSet())
    }

    @Test
    fun formatsArgbAsEightDigitHex() {
        assertEquals("#FF006A4E", toHexColor(0xFF006A4EL))
        assertEquals("#80112233", toHexColor(0x80112233L))
        assertEquals("#00000000", toHexColor(0L))
    }

    @Test
    fun ignoresBitsAboveThirtyTwo() {
        assertEquals("#FFFFFFFF", toHexColor(0x1FFFFFFFFL))
    }

    @Test
    fun buttonOverrideReplacesOnlyTheProvidedProperties() {
        val base = ButtonStyleMessage(backgroundColor = 1L, textColor = 2L, fontSize = 14.0, cornerRadius = 4.0)
        val override = ButtonStyleMessage(backgroundColor = 9L)

        val merged = mergeButtonStyles(base, override)!!

        assertEquals(9L, merged.backgroundColor)
        assertEquals(2L, merged.textColor)
        assertEquals(14.0, merged.fontSize)
        assertEquals(4.0, merged.cornerRadius)
    }

    @Test
    fun mergingWithoutStylesGivesNull() {
        assertNull(mergeButtonStyles(null, null))
    }
}
