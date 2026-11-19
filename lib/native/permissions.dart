import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Runtime permissions needed for the phone features.
///
/// Android 12+ (API 31) uses the "Nearby devices" permissions (`BLUETOOTH_SCAN`, declared with
/// `neverForLocation`, and `BLUETOOTH_CONNECT` for the "turn on Bluetooth" prompt). Older Android
/// versions can only scan with the fine-location permission and Location services switched on.
/// Android 13+ additionally needs permission to post notifications.
abstract class AppPermissions {
  static int? _sdkInt;

  static Future<int> androidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    return _sdkInt ??= (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  }

  static Future<bool> get _modernBluetooth async => Platform.isAndroid && await androidSdkInt() >= 31;

  /// Whether the app may scan for beacons right now (no prompt).
  static Future<bool> hasScan() async {
    if (!Platform.isAndroid) return true;
    final p = await _modernBluetooth ? ph.Permission.bluetoothScan : ph.Permission.locationWhenInUse;
    return (await p.status).isGranted;
  }

  /// Asks for the scan permission, returning whether it was granted.
  static Future<bool> requestScan() async {
    if (!Platform.isAndroid) return true;
    final p = await _modernBluetooth ? ph.Permission.bluetoothScan : ph.Permission.locationWhenInUse;
    return (await p.request()).isGranted;
  }

  /// Android 12+: needed to show the system "turn on Bluetooth" prompt.
  static Future<bool> requestConnect() async {
    if (!await _modernBluetooth) return true;
    return (await ph.Permission.bluetoothConnect.request()).isGranted;
  }

  /// On Android 11 and below, BLE scanning silently returns nothing while Location is off.
  static Future<bool> locationServiceOn() async {
    if (!Platform.isAndroid || await _modernBluetooth) return true;
    return await ph.Permission.locationWhenInUse.serviceStatus == ph.ServiceStatus.enabled;
  }

  /// Android 13+: permission to post election update notifications.
  static Future<bool> requestNotifications() async {
    if (!Platform.isAndroid || await androidSdkInt() < 33) return true;
    return (await ph.Permission.notification.request()).isGranted;
  }

  /// Opens this app's page in the phone's Settings.
  static Future<void> openAppSettings() => ph.openAppSettings();
}
