import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_scanner.dart';
import 'permissions.dart';

/// Bluetooth badge state: red = phone Bluetooth off, yellow = Bluetooth on, green = a
/// polling-node signal is in range.
enum BtState { off, on, node }

/// Follows the phone's Bluetooth state and periodically listens for polling-node beacons so the
/// header badge can show whether the student is near a polling device. The badge is informational:
/// real presence verification happens server-side when voting.
class BluetoothMonitor extends ChangeNotifier with WidgetsBindingObserver {
  BluetoothMonitor({BleScanner? scanner}) : _scanner = scanner ?? BleScanner.instance;

  static final BluetoothMonitor instance = BluetoothMonitor();

  static const Duration probeEvery = Duration(seconds: 10);
  static const Duration probeFor = Duration(seconds: 5);

  /// A node counts as "in range" if it was heard within this window.
  static const Duration nodeFresh = Duration(seconds: 25);

  final BleScanner _scanner;

  BtState? _state;
  bool _supported = false;
  bool _started = false;
  bool _foreground = true;
  DateTime? _lastNodeSeen;
  Timer? _probeTimer;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  /// Null until the phone's Bluetooth support is known (or when it has no BLE at all).
  BtState? get state => _state;

  bool get isOn => FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;

  bool get nodeNear {
    final t = _lastNodeSeen;
    return isOn && t != null && DateTime.now().difference(t) < nodeFresh;
  }

  /// Begins watching. Called once after sign-in; safe to call again.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      _supported = await FlutterBluePlus.isSupported;
    } catch (_) {
      _supported = false;
    }
    if (!_supported) return;
    _adapterSub = FlutterBluePlus.adapterState.listen((_) {
      if (!isOn) _lastNodeSeen = null;
      _publish();
    });
    _publish();
    await ensureBluetooth();
    _scheduleProbes();
  }

  /// Stops watching (sign-out).
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _probeTimer?.cancel();
    _probeTimer = null;
    await _adapterSub?.cancel();
    _adapterSub = null;
    WidgetsBinding.instance.removeObserver(this);
    _state = null;
    notifyListeners();
  }

  /// If Bluetooth is off, shows the system "Allow Student Election to turn on Bluetooth?" prompt
  /// (apps cannot switch Bluetooth on silently). Then asks for the scan permission once so the
  /// badge can tell whether a polling node is in range.
  Future<void> ensureBluetooth() async {
    if (!_supported) return;
    try {
      if (!isOn && await AppPermissions.requestConnect()) {
        await FlutterBluePlus.turnOn();
      }
    } catch (_) {/* the student declined */}
    if (!await AppPermissions.hasScan()) await AppPermissions.requestScan();
    _publish();
    unawaited(probeNow());
  }

  /// Called by the vote flow after a successful beacon scan.
  void markNodeSeen() {
    _lastNodeSeen = DateTime.now();
    _publish();
  }

  /// Looks briefly for a node beacon and updates the badge.
  Future<void> probeNow() async {
    if (!_started || !_foreground || !isOn || _scanner.isScanning) {
      if (!isOn) _lastNodeSeen = null;
      _publish();
      return;
    }
    if (await _scanner.probe(timeout: probeFor)) _lastNodeSeen = DateTime.now();
    _publish();
  }

  void _scheduleProbes() {
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(probeEvery, (_) => probeNow());
    Future<void>.delayed(const Duration(seconds: 2), probeNow);
  }

  void _publish() {
    final next = !isOn
        ? BtState.off
        : nodeNear
            ? BtState.node
            : BtState.on;
    if (next != _state) {
      _state = next;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_started) return;
    if (_foreground) {
      _publish();
      _scheduleProbes();
    } else {
      _probeTimer?.cancel();
      _probeTimer = null;
    }
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
