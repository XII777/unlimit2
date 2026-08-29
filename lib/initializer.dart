import 'package:mulimited/core/services/drift_db_service.dart';
import 'package:mulimited/core/services/method_channel_service.dart';
import 'package:mulimited/data/providers.dart';

/// Boot-time initializer.
///
/// Syncs persisted database state to native services on every launch.
/// Native services (AccessibilityService, NotificationListenerService,
/// VpnService) are stateless — they only know what Dart last pushed.
/// This re-pushes everything that might have changed while the app
/// was closed or the device was restarted.
class Initializer {
  /// Syncs DB state to native services. Call after [DriftDbService.init]
  /// and [MethodChannelService.init].
  static Future<void> syncToNative() async {
    final db = DriftDbService.instance.db;

    // Sync blocklist to AccessibilityService
    final blockedApps = await db.select(db.blockedApps).get();
    final enabled = blockedApps.where((a) => a.enabled).map((a) => a.packageName).toList();
    await MethodChannelService.instance.syncBlocklist(
      enabled,
      blockedApps.any((a) => a.enabled),
    );

    // Sync bedtime DND state
    final bedtime = await db.select(db.bedtimeSchedule).getSingleOrNull();
    if (bedtime != null && bedtime.dndEnabled) {
      await MethodChannelService.instance.setDndEnabled(true);
    }
  }
}
