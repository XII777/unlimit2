import '../services/method_channel_service.dart';

/// Thin wrapper around the native MethodChannel. Every method here maps
/// 1:1 to a `when` branch in MainActivity.kt's onMethodCall — keep them
/// in sync if you add a new permission.
///
/// Android does not let an app silently grant Accessibility Service or
/// Notification Listener access — those two always require the user to
/// flip a toggle in system Settings, so their "request" methods open
/// Settings rather than showing an in-app dialog. Device Admin, VPN, and
/// POST_NOTIFICATIONS *do* support an in-app system dialog, so those
/// request methods trigger one directly.
class NativePermissions {
  NativePermissions._();

  static Future<bool> isAccessibilityEnabled() async =>
      MethodChannelService.instance.isAccessibilityEnabled();

  static Future<void> openAccessibilitySettings() =>
      MethodChannelService.instance.openAccessibilitySettings();

  static Future<bool> isDeviceAdminActive() async =>
      MethodChannelService.instance.isDeviceAdminActive();

  static Future<void> requestDeviceAdmin() =>
      MethodChannelService.instance.requestDeviceAdmin();

  static Future<bool> isNotificationListenerEnabled() async =>
      MethodChannelService.instance.isNotificationListenerEnabled();

  static Future<void> openNotificationListenerSettings() =>
      MethodChannelService.instance.openNotificationListenerSettings();

  static Future<bool> hasVpnPermission() async =>
      MethodChannelService.instance.hasVpnPermission();

  static Future<void> requestVpnPermission() =>
      MethodChannelService.instance.requestVpnPermission();

  static Future<bool> isPostNotificationsGranted() async =>
      MethodChannelService.instance.isPostNotificationsGranted();

  static Future<void> requestPostNotifications() =>
      MethodChannelService.instance.requestPostNotifications();

  static Future<bool> isBiometricAvailable() async =>
      MethodChannelService.instance.isBiometricAvailable();

  static Future<bool> isDndEnabled() async =>
      MethodChannelService.instance.isDndEnabled();

  static Future<bool> setDndEnabled(bool enabled) async =>
      MethodChannelService.instance.setDndEnabled(enabled);

  static Future<bool> authenticateBiometric({String reason = "Verify it's you"}) async =>
      MethodChannelService.instance.authenticateBiometric(reason: reason);

  static Future<void> setNotificationBatching(bool enabled, {String reason = 'focus'}) =>
      MethodChannelService.instance.setNotificationBatching(enabled, reason: reason);
}
