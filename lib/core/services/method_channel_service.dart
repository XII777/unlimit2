import 'package:flutter/services.dart';

/// Centralizes all native Android method channel calls.
///
/// Single point of contact for Flutter ↔ native communication.
/// New permissions or features should extend this class rather than
/// creating separate channel classes.
class MethodChannelService {
  MethodChannelService._();

  static final MethodChannelService instance = MethodChannelService._();

  static const _channel = MethodChannel('com.ulimit.app/permissions');

  /// Initializes the method channel. Call once at app startup.
  Future<void> init() async {
    // No-op for now; reserved for future stream handlers from native.
  }

  // ===========================================================================
  // PERMISSION CHECKS
  // ===========================================================================

  Future<bool> isAccessibilityEnabled() async =>
      await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  Future<bool> isDeviceAdminActive() async =>
      await _channel.invokeMethod<bool>('isDeviceAdminActive') ?? false;

  Future<bool> isNotificationListenerEnabled() async =>
      await _channel.invokeMethod<bool>('isNotificationListenerEnabled') ?? false;

  Future<bool> hasVpnPermission() async =>
      await _channel.invokeMethod<bool>('hasVpnPermission') ?? false;

  Future<bool> isPostNotificationsGranted() async =>
      await _channel.invokeMethod<bool>('isPostNotificationsGranted') ?? false;

  Future<bool> isBiometricAvailable() async =>
      await _channel.invokeMethod<bool>('isBiometricAvailable') ?? false;

  Future<bool> isDndEnabled() async =>
      await _channel.invokeMethod<bool>('isDndEnabled') ?? false;

  // ===========================================================================
  // PERMISSION REQUESTS (open system dialogs)
  // ===========================================================================

  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod('openAccessibilitySettings');

  Future<void> requestDeviceAdmin() => _channel.invokeMethod('requestDeviceAdmin');

  Future<void> openNotificationListenerSettings() =>
      _channel.invokeMethod('openNotificationListenerSettings');

  Future<void> requestVpnPermission() => _channel.invokeMethod('requestVpnPermission');

  Future<void> requestPostNotifications() =>
      _channel.invokeMethod('requestPostNotifications');

  // ===========================================================================
  // ENFORCEMENT ACTIONS
  // ===========================================================================

  /// Push the current set of blocked packages to the native service.
  /// [enabled] is the master switch — if false, the service won't block.
  Future<void> syncBlocklist(List<String> packages, bool enabled) =>
      _channel.invokeMethod('updateBlocklist', {
        'packages': packages,
        'enabled': enabled,
      });

  /// Pull any emergency unlocks that happened since the last drain.
  Future<List<dynamic>> drainEmergencyUnlocks() async {
    final result = await _channel.invokeMethod<List<dynamic>>('drainEmergencyUnlocks');
    return result ?? [];
  }

  /// Set Do Not Disturb mode on/off. Returns true if applied.
  Future<bool> setDndEnabled(bool enabled) async =>
      await _channel.invokeMethod<bool>('setDndEnabled', {'enabled': enabled}) ?? false;

  /// Enable/disable notification batching during focus/bedtime.
  Future<void> setNotificationBatching(bool enabled, {String reason = 'focus'}) =>
      _channel.invokeMethod('setNotificationBatching', {
        'enabled': enabled,
        'reason': reason,
      });

  /// Show the system biometric prompt. Returns true if authenticated.
  Future<bool> authenticateBiometric({String reason = "Verify it's you"}) async =>
      await _channel.invokeMethod<bool>('authenticateBiometric', {'reason': reason}) ?? false;
}
