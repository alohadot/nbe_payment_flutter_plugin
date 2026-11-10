package com.example.nbe_payment_flutter_plugin.sdk

import android.app.Activity
import android.app.Application
import android.os.Build
import android.os.Bundle
import android.os.Handler
import androidx.annotation.ChecksSdkIntAtLeast
import java.lang.ref.WeakReference

/**
 * Keeps the back button working on the 3-D Secure challenge screen, and reports the screen
 * disappearing without an outcome.
 *
 * Two problems are solved here, both caused by the bundled 3DS SDK owning a screen this plugin
 * cannot change:
 *
 * 1. **The back button does nothing.** The SDK's challenge screen implements the legacy
 *    `Activity.onBackPressed` only — verified: its classes contain no reference to
 *    `OnBackInvoked` at all. Android routes back through `OnBackInvokedDispatcher` once
 *    predictive back is active (apps targeting recent SDK levels get it without asking), and
 *    then the legacy method is never called. The payer's back press closes the screen without
 *    running the SDK's cancel logic, so the issuer is never told and the SDK never answers.
 *    This guard registers a callback on the new dispatcher that calls the legacy method, which
 *    is exactly what the SDK expects ([BackInvokedBridge]). Devices below API 33 keep the
 *    legacy path and need no bridge — and must never load it, see that class.
 *
 * 2. **A stranded operation.** Whatever the reason a challenge screen stops being the payer's
 *    screen, [ChallengeWatchdog] fails the operation so the gateway lock is released. Lifecycle
 *    is reported to it in full — created, started, stopped, destroyed — because a challenge can
 *    be abandoned without ever being destroyed; see that class for which combination means what.
 *
 * The back bridge is limited to the 3DS SDK's own package: a host app's screens must keep their
 * own back behavior. The watchdog is deliberately broader — it counts every screen that is not
 * the host's — so a renamed SDK class loses the bridge but keeps the safety net.
 *
 * Main-thread only, like the rest of the bridge.
 */
internal class ChallengeScreenGuard(
    private val application: Application?,
    mainHandler: Handler,
) : Application.ActivityLifecycleCallbacks {

    private val watchdog = ChallengeWatchdog(
        graceMillis = GRACE_MILLIS,
        schedule = { delayMillis, action -> mainHandler.postDelayed(action, delayMillis) },
        onStranded = ::reportStranded,
    )

    // Weak: the guard outlives a host Activity that goes away mid-authentication, and the
    // safety net must keep working without holding a destroyed Activity alive.
    private var hostActivity: WeakReference<Activity>? = null
    private var onStranded: (() -> Unit)? = null
    private var isRegistered = false

    /**
     * `null` below API 33, which has no back dispatcher. Every use repeats the version check so
     * lint can prove none of it runs on an older device.
     */
    private val backBridge: BackInvokedBridge? =
        if (hasBackDispatcher()) BackInvokedBridge() else null

    /**
     * Starts guarding one authentication started from [hostActivity].
     *
     * @param onStranded called on the main thread when the challenge screen is gone and no
     * outcome arrived. Called at most once per [start].
     */
    fun start(hostActivity: Activity, onStranded: () -> Unit) {
        this.hostActivity = WeakReference(hostActivity)
        this.onStranded = onStranded
        watchdog.start()
        if (!isRegistered) {
            application?.registerActivityLifecycleCallbacks(this)
            isRegistered = application != null
        }
    }

    /** Stops guarding, because the SDK answered or the operation is over. */
    fun stop() {
        watchdog.stop()
        onStranded = null
        hostActivity = null
        if (isRegistered) {
            application?.unregisterActivityLifecycleCallbacks(this)
            isRegistered = false
        }
        if (hasBackDispatcher()) backBridge?.removeAll()
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        if (activity === hostActivity?.get()) return
        watchdog.onChallengeScreenOpened()
        // Limited to the 3DS SDK's own screens: the host app's keep their own back behavior.
        if (hasBackDispatcher() && activity.javaClass.name.startsWith(CHALLENGE_SDK_PACKAGE)) {
            backBridge?.add(activity)
        }
    }

    override fun onActivityStarted(activity: Activity) {
        if (activity === hostActivity?.get()) return
        watchdog.onChallengeScreenShown()
    }

    override fun onActivityResumed(activity: Activity) {
        if (activity !== hostActivity?.get()) return
        watchdog.onHostScreenResumed()
    }

    override fun onActivityPaused(activity: Activity) {
        if (activity !== hostActivity?.get()) return
        watchdog.onHostScreenPaused()
    }

    override fun onActivityStopped(activity: Activity) {
        if (activity === hostActivity?.get()) return
        watchdog.onChallengeScreenHidden()
    }

    override fun onActivityDestroyed(activity: Activity) {
        if (activity === hostActivity?.get()) return
        if (hasBackDispatcher()) backBridge?.remove(activity)
        watchdog.onChallengeScreenClosed(activity.isChangingConfigurations)
    }

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit

    /** Releases everything this guard holds before the operation is failed. */
    private fun reportStranded() {
        val callback = onStranded
        stop()
        callback?.invoke()
    }

    private companion object {
        @ChecksSdkIntAtLeast(api = Build.VERSION_CODES.TIRAMISU)
        fun hasBackDispatcher() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU

        /** Package of the bundled 3DS SDK, which owns the challenge screen. */
        const val CHALLENGE_SDK_PACKAGE = "com.usdk.android."

        /**
         * Long enough for the SDK to answer after the challenge screen goes away, short enough
         * that a payer who pressed back is not left waiting. The SDK answers immediately in
         * practice; this only covers the ordering between the screen going and the callback.
         */
        const val GRACE_MILLIS = 2_000L
    }
}
