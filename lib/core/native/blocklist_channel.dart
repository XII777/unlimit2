import '../services/method_channel_service.dart';

/// Bridges the blocked-apps list from Drift to the native
/// AccessibilityService. The service reads the cached set on every
/// foreground-app transition, so this must be called whenever the
/// blocklist changes (toggle, add, remove).
class NativeBlocklist {
  NativeBlocklist._();

  /// Push the current set of blocked packages to the native service.
  /// [enabled] is the master switch — if false, the service won't block
  /// even if packages is non-empty.
  static Future<void> syncBlocklist(List<String> packages, bool enabled) =>
      MethodChannelService.instance.syncBlocklist(packages, enabled);

  /// Pull any emergency unlocks that happened since the last drain, so
  /// they can be written to the Drift DB.
  static Future<List<dynamic>> drainEmergencyUnlocks() async {
    return MethodChannelService.instance.drainEmergencyUnlocks();
  }
}
