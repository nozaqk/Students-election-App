/// A failure in a phone capability (Bluetooth, permissions) rather than in the backend.
///
/// Codes: `UNSUPPORTED`, `BLUETOOTH_OFF`, `LOCATION_OFF`, `PERMISSION_DENIED`, `SCAN_FAILED`,
/// `TIMEOUT`. [needsSettings] is true when the student has to change something in the phone's
/// settings before trying again.
class NativeError implements Exception {
  const NativeError(this.code, this.message);

  const NativeError.timeout()
      : this('TIMEOUT', 'No polling device found. Move closer to the polling device and try again.');

  const NativeError.bluetoothOff() : this('BLUETOOTH_OFF', 'Turn on Bluetooth and try again.');

  const NativeError.permissionDenied()
      : this('PERMISSION_DENIED', 'Bluetooth permission is required to verify you are at the polling location.');

  const NativeError.locationOff()
      : this(
          'LOCATION_OFF',
          'On this Android version, Bluetooth scanning needs Location turned on. Turn on Location and try again.',
        );

  const NativeError.unsupported()
      : this('UNSUPPORTED', 'This phone does not support Bluetooth Low Energy, which is needed to verify your location.');

  final String code;
  final String message;

  bool get needsSettings => code == 'PERMISSION_DENIED' || code == 'BLUETOOTH_OFF' || code == 'LOCATION_OFF';

  @override
  String toString() => message;
}
