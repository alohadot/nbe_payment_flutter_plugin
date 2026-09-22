package com.example.nbe_payment_flutter_plugin.sdk

/**
 * Notices that a 3-D Secure challenge screen disappeared without the SDK reporting an outcome.
 *
 * The bundled 3DS SDK only implements the legacy `Activity.onBackPressed`, which Android no
 * longer calls once predictive back is active, so the payer can close the challenge in a way
 * the SDK never learns about. The authentication callback then never fires and the pending
 * operation holds the gateway lock for the lifetime of the process.
 *
 * [ChallengeScreenGuard] bridges the back button so this should not happen, but a screen owned
 * by a third-party SDK can vanish for reasons this plugin cannot predict, so the outcome is
 * never left to that bridge alone.
 *
 * Closing is not reported immediately: a normal challenge also closes its screen just before
 * the SDK answers, so a grace period lets the real outcome win. Only when the grace period
 * passes with no answer is the operation treated as abandoned.
 *
 * Pure logic with no Android types, so every branch is covered by JVM tests. Main-thread only;
 * no synchronization needed.
 *
 * @param graceMillis how long an answer may still arrive after the last challenge screen closed.
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

    /** Challenge screens currently alive. A recreated screen is counted again. */
    private var openScreens = 0

    /** Without this an authentication that never showed a screen could be reported abandoned. */
    private var hasSeenScreen = false

    /** Starts watching one authentication. */
    fun start() {
        isWatching = true
        openScreens = 0
        hasSeenScreen = false
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

    /**
     * @param isChangingConfigurations `true` when the screen is being recreated (a rotation,
     * for example). The recreated screen re-opens immediately, so nothing is reported.
     */
    fun onChallengeScreenClosed(isChangingConfigurations: Boolean) {
        if (!isWatching) return
        if (openScreens > 0) openScreens--
        if (isChangingConfigurations || openScreens > 0 || !hasSeenScreen) return

        schedule(graceMillis) {
            // The SDK may have answered, or another screen may have opened, while waiting.
            if (!isWatching || openScreens > 0) return@schedule
            isWatching = false
            onStranded()
        }
    }
}
