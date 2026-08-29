package com.ulimit.app

/// Caches the current set of blocked package names, updated by Dart via
/// MethodChannel. UlimitAccessibilityService checks this on every
/// foreground-app transition to decide whether to show the block overlay.
///
/// Held in a companion object so the service (which may be instantiated
/// by the system, not us) can read what Dart last pushed.
object BlocklistBridge {
    @Volatile
    private var blockedPackages: Set<String> = emptySet()

    @Volatile
    private var blockingEnabled: Boolean = false

    fun updateBlocked(packages: List<String>, enabled: Boolean) {
        blockedPackages = packages.toSet()
        blockingEnabled = enabled
    }

    fun shouldBlock(packageName: String): Boolean {
        if (!blockingEnabled) return false
        return blockedPackages.contains(packageName)
    }
}
