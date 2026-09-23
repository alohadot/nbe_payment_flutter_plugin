package com.example.nbe_payment_flutter_plugin.sdk

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

internal class ChallengeWatchdogTest {

    /** Collects the delayed actions so a test decides when the grace period elapses. */
    private val scheduled = mutableListOf<Pair<Long, () -> Unit>>()
    private var strandedCount = 0

    private val watchdog = ChallengeWatchdog(
        graceMillis = GRACE,
        schedule = { delayMillis, action -> scheduled += delayMillis to action },
        onStranded = { strandedCount++ },
    )

    private fun elapseGracePeriod() {
        val actions = scheduled.toList()
        scheduled.clear()
        actions.forEach { (_, action) -> action() }
    }

    @Test
    fun `reports a challenge screen that closed without an outcome`() {
        watchdog.start()
        watchdog.onChallengeScreenOpened()
        watchdog.onChallengeScreenClosed(isChangingConfigurations = false)

        assertEquals(0, strandedCount, "nothing is reported before the grace period")
        elapseGracePeriod()
        assertEquals(1, strandedCount)
    }

    @Test
    fun `waits the grace period before reporting`() {
        watchdog.start()
        watchdog.onChallengeScreenOpened()
        watchdog.onChallengeScreenClosed(isChangingConfigurations = false)

        assertEquals(listOf(GRACE), scheduled.map { it.first })
    }

    @Test
    fun `reports nothing when the SDK answers first`() {
        watchdog.start()
        watchdog.onChallengeScreenOpened()
        watchdog.stop()
        watchdog.onChallengeScreenClosed(isChangingConfigurations = false)

        elapseGracePeriod()
        assertEquals(0, strandedCount)
    }

    @Test
    fun `reports nothing when the SDK answers during the grace period`() {
        watchdog.start()
        watchdog.onChallengeScreenOpened()
        watchdog.onChallengeScreenClosed(isChangingConfigurations = false)

        watchdog.stop()
        elapseGracePeriod()
        assertEquals(0, strandedCount)
    }

    @Test
    fun `reports nothing while the screen is being recreated`() {
        watchdog.start()
        watchdog.onChallengeScreenOpened()
        watchdog.onChallengeScreenClosed(isChangingConfigurations = true)

        assertTrue(scheduled.isEmpty(), "a rotation must not arm the watchdog")
        elapseGracePeriod()
        assertEquals(0, strandedCount)
    }

    @Test
    fun `reports nothing when the screen reopens before the grace period ends`() {
        watchdog.start()
        watchdog.onChallengeScreenOpened()
        watchdog.onChallengeScreenClosed(isChangingConfigurations = false)

        watchdog.onChallengeScreenOpened()
        elapseGracePeriod()
        assertEquals(0, strandedCount)
    }

    @Test
    fun `reports nothing when no challenge screen was ever shown`() {
        watchdog.start()
        watchdog.onChallengeScreenClosed(isChangingConfigurations = false)

        elapseGracePeriod()
        assertEquals(0, strandedCount, "a frictionless authentication shows no screen")
    }

    @Test
    fun `keeps watching while a second screen is still open`() {
        watchdog.start()
        watchdog.onChallengeScreenOpened()
        watchdog.onChallengeScreenOpened()
        watchdog.onChallengeScreenClosed(isChangingConfigurations = false)

        elapseGracePeriod()
        assertEquals(0, strandedCount)

        watchdog.onChallengeScreenClosed(isChangingConfigurations = false)
        elapseGracePeriod()
        assertEquals(1, strandedCount)
    }

    @Test
    fun `reports at most once per authentication`() {
        watchdog.start()
        watchdog.onChallengeScreenOpened()
        watchdog.onChallengeScreenClosed(isChangingConfigurations = false)
        elapseGracePeriod()

        watchdog.onChallengeScreenOpened()
        watchdog.onChallengeScreenClosed(isChangingConfigurations = false)
        elapseGracePeriod()

        assertEquals(1, strandedCount)
    }

    @Test
    fun `ignores screens reported before the authentication starts`() {
        watchdog.onChallengeScreenOpened()
        watchdog.onChallengeScreenClosed(isChangingConfigurations = false)

        elapseGracePeriod()
        assertEquals(0, strandedCount)
    }

    @Test
    fun `watches again after a previous authentication was reported`() {
        watchdog.start()
        watchdog.onChallengeScreenOpened()
        watchdog.onChallengeScreenClosed(isChangingConfigurations = false)
        elapseGracePeriod()

        watchdog.start()
        watchdog.onChallengeScreenOpened()
        watchdog.onChallengeScreenClosed(isChangingConfigurations = false)
        elapseGracePeriod()

        assertEquals(2, strandedCount)
    }

    @Test
    fun `reports a challenge screen the system moved to the background`() {
        openChallengeScreen()

        // Back on the root of a task hides the screen without destroying it, and the app the
        // payer came from is in front again.
        watchdog.onHostScreenResumed()
        watchdog.onChallengeScreenHidden()

        elapseGracePeriod()
        assertEquals(1, strandedCount, "an alive but abandoned challenge must not hold the lock")
    }

    @Test
    fun `reports it whichever way round the two screens are reported`() {
        openChallengeScreen()

        watchdog.onChallengeScreenHidden()
        assertTrue(scheduled.isEmpty(), "the payer may be reading the code in another app")
        watchdog.onHostScreenResumed()

        elapseGracePeriod()
        assertEquals(1, strandedCount)
    }

    @Test
    fun `reports nothing while the payer is in another app`() {
        openChallengeScreen()
        watchdog.onChallengeScreenHidden()

        elapseGracePeriod()
        assertEquals(0, strandedCount, "a one-time code is often read in a messaging app")
    }

    @Test
    fun `reports nothing when the payer returns to the challenge during the grace period`() {
        openChallengeScreen()
        watchdog.onHostScreenResumed()
        watchdog.onChallengeScreenHidden()

        watchdog.onChallengeScreenShown()
        elapseGracePeriod()
        assertEquals(0, strandedCount)
    }

    @Test
    fun `reports nothing when the host screen resumes with no challenge screen shown`() {
        watchdog.start()
        watchdog.onHostScreenResumed()

        elapseGracePeriod()
        assertEquals(0, strandedCount, "a frictionless authentication shows no screen")
    }

    @Test
    fun `keeps watching while a second screen is still visible`() {
        openChallengeScreen()
        watchdog.onChallengeScreenShown()

        watchdog.onHostScreenResumed()
        watchdog.onChallengeScreenHidden()
        elapseGracePeriod()
        assertEquals(0, strandedCount)

        watchdog.onChallengeScreenHidden()
        elapseGracePeriod()
        assertEquals(1, strandedCount)
    }

    /** Brings one challenge screen to the front, the way the SDK does. */
    private fun openChallengeScreen() {
        watchdog.start()
        watchdog.onHostScreenPaused()
        watchdog.onChallengeScreenOpened()
        watchdog.onChallengeScreenShown()
    }

    private companion object {
        const val GRACE = 2_000L
    }
}
