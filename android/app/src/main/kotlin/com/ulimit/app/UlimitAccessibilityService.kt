package com.ulimit.app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/// The actual data source behind every usage number in the app. Fires
/// on every window-state change (the OS's signal for "a different app
/// (or a different screen within one) is now in front"), and forwards
/// the package name + timestamp to Dart via [UsageEventBridge].
///
/// Also enforces app blocking: when a blocked app comes to the foreground,
/// it launches the BlockOverlayActivity to prevent access. The list of
/// blocked packages is read from the Drift DB via [BlocklistBridge].
class UlimitAccessibilityService : AccessibilityService() {

    private var lastPackageName: String? = null

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return

        // The system UI / our own app switching to itself isn't a real
        // "the user picked up a different app" transition worth logging.
        if (packageName == this.packageName) return
        if (packageName == lastPackageName) return

        lastPackageName = packageName

        // Enforcement: if this package is blocked, show the overlay
        // instead of letting the user through. BlocklistBridge caches
        // the blocked set — updated by Dart via MethodChannel.
        if (BlocklistBridge.shouldBlock(packageName)) {
            val intent = Intent(this, BlockOverlayActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra("blocked_package", packageName)
            }
            startActivity(intent)
            return
        }

        UsageEventBridge.emit(packageName, System.currentTimeMillis())
    }

    override fun onInterrupt() {
        // Required override; nothing to clean up.
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        lastPackageName = null
    }
}
