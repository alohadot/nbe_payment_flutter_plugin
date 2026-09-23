package com.example.nbe_payment_flutter_plugin.sdk

/**
 * Notices that a 3-D Secure challenge screen went away without the SDK reporting an outcome.
 *
 * The challenge screen belongs to the bundled 3DS SDK, and it can stop being the payer's screen
 * in ways the SDK never learns about — a back press the SDK's own handler never sees, or a
 * challenge that ended up in a task of its own and was sent to the background. The
 * authentication callback then never fires and the pending operation holds the gateway lock for
 * the lifetime of the process.
 *
 * Two independent signals arm the watchdog, because a challenge can be abandoned without being
 * destroyed:
 *
 * * **the last challenge screen was destroyed** ([onChallengeScreenClosed]);
 * * **the host screen is in front while no challenge screen is visible**. This is the one that
 *   catches a challenge the system merely moved to the background: the Activity is alive, so
 *   nothing is ever destroyed, but the payer is back in the app and will never see that screen
 *   again. Android does not order those two lifecycle events, so the state is tracked from both
 *   sides and either one can arm the watchdog.
 *
 * Visibility is deliberately not enough on its own to report anything: a payer who leaves to
 * read the one-time code in another app also hides the challenge, and that authentication must
 * survive. Only the host screen being in front instead says the challenge is over.
 *
 * Neither signal is acted on immediately: a normal challenge also closes its screen just before
 * the SDK answers, so a grace period lets the real outcome win. Only when the grace period
 * passes with the challenge still gone is the operation treated as abandoned.
 *
 * Pure logic with no Android types, so every branch is covered by JVM tests. Main-thread only;
 * no synchronization needed.
 *
 * @param graceMillis how long an answer may still arrive after the challenge went away.
 * @param schedule runs [action] after the given delay; never cancelled, the action re-checks
 * the state instead.
 * @param onStranded called at most once per [start], when the challenge is gone for good.
 */
internal class ChallengeWatchdog(
    private val graceMillis: Long,
    private val schedule: (delayMillis: Long, action: () -> Unit) -> Unit,
    private val onStranded: () -> Unit,
) {

    private var isWatching = false

    /** Challenge screens that exist. A recreated screen is counted again. */
    private var openScreens = 0

    /** Challenge screens the payer can see. Zero while another app is in front. */
    private var visibleScreens = 0

    /** Without this an authentication that never showed a screen could be reported abandoned. */
    private var hasSeenScreen = false

    /**
     * Whether the screen the authentication was started from is in front. It is when an
     * authentication starts; the challenge pushes it into the background moments later.
     */
    private var isHostScreenInFront = true

    /** Starts watching one authentication. */
    fun start() {
        isWatching = true
        openScreens = 0
        visibleScreens = 0
        hasSeenScreen = false
        isHostScreenInFront = true
    }

    /** Stops watching, because the SDK answered or the operation is over. */
    fun stop() {
        isWatching = false
    }

    fun onChallengeScreenOpened() {
        if (!isWatching) return
        openScreens++
        hasSeenScreen = true
    }

    fun onChallengeScreenShown() {
        if (!isWatching) return
        visibleScreens++
        hasSeenScreen = true
    }

    fun onChallengeScreenHidden() {
        if (!isWatching) return
        if (visibleScreens > 0) visibleScreens--
        if (visibleScreens == 0 && isHostScreenInFront) armChallengeIsGone()
    }

    /**
     * @param isChangingConfigurations `true` when the screen is being recreated (a rotation,
     * for example). The recreated screen re-opens immediately, so nothing is reported.
     */
    fun onChallengeScreenClosed(isChangingConfigurations: Boolean) {
        if (!isWatching) return
        if (openScreens > 0) openScreens--
        if (isChangingConfigurations || openScreens > 0 || !hasSeenScreen) return

        // A screen created during the grace period means the challenge carried on.
        armGracePeriod { openScreens > 0 }
    }

    /** The screen the authentication was started from is in front again. */
    fun onHostScreenResumed() {
        if (!isWatching) return
        isHostScreenInFront = true
        if (visibleScreens == 0) armChallengeIsGone()
    }

    /** The screen the authentication was started from is no longer in front. */
    fun onHostScreenPaused() {
        if (!isWatching) return
        isHostScreenInFront = false
    }

    /**
     * The payer is looking at the host app and no challenge screen is visible, so the challenge
     * is over whether or not its Activity still exists.
     */
    private fun armChallengeIsGone() {
        if (!hasSeenScreen) return

        // A challenge screen that becomes visible again during the grace period means the payer
        // went back to it, so the authentication is still the payer's screen.
        armGracePeriod { visibleScreens > 0 }
    }

    private fun armGracePeriod(isChallengeBack: () -> Boolean) {
        schedule(graceMillis) {
            // The SDK may have answered, or the challenge may have come back, while waiting.
            if (!isWatching || isChallengeBack()) return@schedule
            isWatching = false
            onStranded()
        }
    }
}
