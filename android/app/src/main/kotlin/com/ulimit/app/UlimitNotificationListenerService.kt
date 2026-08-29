package com.ulimit.app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/// Listens for notifications and batches them during focus sessions or
/// bedtime. When batching is active, non-priority notifications are
/// cancelled (not shown) and stored for later release.
///
/// Batching state is controlled by Dart via NotificationBatchingBridge —
/// the service doesn't need to read Drift directly.
class UlimitNotificationListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        if (!NotificationBatchingBridge.isBatchingEnabled()) return

        // Let through priority notifications (calls, messages from
        // starred contacts) even during batching — the user probably
        // doesn't want to miss those.
        if (isPriority(sbn)) return

        // Cancel the notification so it doesn't disturb the user. It
        // will be released when batching ends.
        cancelNotification(sbn.key)
        NotificationBatchingBridge.onBatched(sbn.packageName)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Intentionally empty — we only care about new notifications.
    }

    private fun isPriority(sbn: StatusBarNotification): Boolean {
        // Calls and alarms always come through.
        val pkg = sbn.packageName
        if (pkg == "com.android.dialer" || pkg == "com.google.android.dialer") return true
        if (pkg == "com.android.deskclock" || pkg == "com.google.android.deskclock") return true
        // Category == msg indicates a direct message — let it through.
        return sbn.notification.category == "msg"
    }
}
