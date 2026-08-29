package com.ulimit.app

/// Bridges batching state from Dart to the NotificationListenerService.
/// When enabled, the service cancels non-priority notifications and
/// holds them for later release.
object NotificationBatchingBridge {
    @Volatile
    private var batchingEnabled: Boolean = false

    @Volatile
    private var reason: String = "focus" // "focus" or "bedtime"

    private val batchedCount = mutableMapOf<String, Int>()

    fun setBatching(enabled: Boolean, batchReason: String) {
        batchingEnabled = enabled
        reason = batchReason
        if (!enabled) {
            // Batching ended — release would happen here if we were
            // storing full notification data. For v1, we just clear.
            batchedCount.clear()
        }
    }

    fun isBatchingEnabled(): Boolean = batchingEnabled

    fun onBatched(packageName: String) {
        batchedCount[packageName] = (batchedCount[packageName] ?: 0) + 1
    }

    /// Returns how many notifications were batched per package since the
    /// last drain — for the "N notifications held" summary in Dart.
    fun drainSummary(): Map<String, Int> {
        val copy = HashMap(batchedCount)
        batchedCount.clear()
        return copy
    }
}
