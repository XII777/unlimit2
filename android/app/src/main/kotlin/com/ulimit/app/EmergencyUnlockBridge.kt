package com.ulimit.app

/// Records emergency unlocks and exposes the list to Dart. When a user
/// bypasses a block via the overlay's "Emergency unlock" button, the
/// timestamp + package is logged here and synced to the Drift DB.
object EmergencyUnlockBridge {
    private val pendingUnlocks = mutableListOf<Map<String, Any>>()

    fun recordUnlock(packageName: String) {
        pendingUnlocks.add(mapOf(
            "package" to packageName,
            "timestamp" to System.currentTimeMillis()
        ))
    }

    /// Drained by Dart via MethodChannel on each usage sync — returns the
    /// list of unlocks since last drain and clears the buffer.
    fun drainUnlocks(): List<Map<String, Any>> {
        val copy = ArrayList(pendingUnlocks)
        pendingUnlocks.clear()
        return copy
    }
}
