import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'beacon_parser.dart';
import 'native_error.dart';
import 'permissions.dart';

class _Seen {
  _Seen(this.claim, this.rssi);
  BeaconClaim claim;
  int rssi;
}

/// Bluetooth Low Energy scanning for polling-node beacons.
///
/// [scan] is the vote-time scan: it returns up to [maxClaims] distinct beacons, strongest signal
/// first, so a rogue advertiser cannot hide the real node — the server decides which one is
/// authorised. [probe] is a short, cheap look used only for the status badge; it relays nothing.
class BleScanner {
  BleScanner._();

  static final BleScanner instance = BleScanner._();

  /// After the first beacon is heard, wait briefly for other nodes in range before finishing.
  static const Duration settle = Duration(milliseconds: 1200);
  static const int maxClaims = 3;

  /// Only advertisements that carry our company id and payload version are delivered.
  static final List<MsdFilter> _filter = [
    MsdFilter(BeaconParser.companyId, data: const [BeaconParser.version], mask: const [0xFF]),
  ];

  bool _voteScan = false;
  Completer<void>? _probeStop;

  /// True while a vote-time scan is running (badge probes must not start over it).
  bool get isScanning => _voteScan;

  /// Checks that the phone can scan right now, prompting for permissions when needed.
  Future<void> _preflight() async {
    if (!await FlutterBluePlus.isSupported) throw const NativeError.unsupported();
    if (!await AppPermissions.hasScan() && !await AppPermissions.requestScan()) {
      throw const NativeError.permissionDenied();
    }
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) throw const NativeError.bluetoothOff();
    if (!await AppPermissions.locationServiceOn()) throw const NativeError.locationOff();
  }

  /// One-shot scan for polling nodes. Resolves with the strongest beacons seen (freshest claim per
  /// node) or throws a [NativeError].
  Future<List<BeaconClaim>> scan({Duration timeout = const Duration(seconds: 15)}) async {
    await _stopProbe();
    await _preflight();
    _voteScan = true;

    final seen = <int, _Seen>{};
    final done = Completer<List<BeaconClaim>>();
    Timer? settleTimer;
    var accepting = false; // scanResults replays the previous scan's results on listen; skip those

    void finish() {
      if (done.isCompleted) return;
      final ordered = seen.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
      done.complete(ordered.take(maxClaims).map((s) => s.claim).toList());
    }

    void fail(NativeError e) {
      if (!done.isCompleted) done.completeError(e);
    }

    final sub = FlutterBluePlus.scanResults.listen(
      (results) {
        if (!accepting) return;
        for (final r in results) {
          final claim = BeaconParser.parse(r.advertisementData.manufacturerData[BeaconParser.companyId]);
          if (claim == null) continue;
          final prev = seen[claim.beaconId];
          if (prev == null) {
            seen[claim.beaconId] = _Seen(claim, r.rssi);
          } else {
            prev.rssi = math.max(prev.rssi, r.rssi);
            if (claim.counter >= prev.claim.counter) prev.claim = claim; // keep the freshest beacon
          }
          settleTimer ??= Timer(settle, finish);
        }
      },
      onError: (Object _) => fail(const NativeError('SCAN_FAILED', 'Bluetooth scan failed. Try again.')),
    );
    final timeoutTimer = Timer(timeout, finish);

    try {
      if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(
        withMsd: _filter,
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: false,
        continuousUpdates: true,
      );
      accepting = true;
    } catch (e) {
      fail(_mapStartFailure(e));
    }

    try {
      final claims = await done.future;
      if (claims.isEmpty) throw const NativeError.timeout();
      return claims;
    } finally {
      timeoutTimer.cancel();
      settleTimer?.cancel();
      await sub.cancel();
      await _safeStop();
      _voteScan = false;
    }
  }

  /// Brief background look for ANY polling-node beacon. Returns true as soon as one is heard,
  /// false at [timeout] or when scanning is not possible. Never throws.
  Future<bool> probe({Duration timeout = const Duration(seconds: 5)}) async {
    if (_voteScan || _probeStop != null) return false;
    try {
      if (!await FlutterBluePlus.isSupported) return false;
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) return false;
      if (!await AppPermissions.hasScan()) return false;
    } catch (_) {
      return false;
    }

    final stop = Completer<void>();
    _probeStop = stop;
    final found = Completer<bool>();
    var accepting = false;
    void finish(bool value) {
      if (!found.isCompleted) found.complete(value);
    }

    final sub = FlutterBluePlus.scanResults.listen(
      (results) {
        if (!accepting) return;
        for (final r in results) {
          if (BeaconParser.parse(r.advertisementData.manufacturerData[BeaconParser.companyId]) != null) {
            finish(true);
            return;
          }
        }
      },
      onError: (Object _) => finish(false),
    );
    final timer = Timer(timeout, () => finish(false));
    unawaited(stop.future.then((_) => finish(false)));

    try {
      if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(
        withMsd: _filter,
        androidScanMode: AndroidScanMode.balanced,
        androidUsesFineLocation: false,
      );
      accepting = true;
      return await found.future;
    } catch (_) {
      return false;
    } finally {
      timer.cancel();
      await sub.cancel();
      await _safeStop();
      if (identical(_probeStop, stop)) _probeStop = null;
    }
  }

  Future<void> _stopProbe() async {
    final p = _probeStop;
    if (p != null && !p.isCompleted) p.complete();
    // Give the probe a moment to release the radio before the vote scan starts.
    if (p != null) await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _safeStop() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {/* already stopped */}
  }

  NativeError _mapStartFailure(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('permission')) return const NativeError.permissionDenied();
    if (text.contains('bluetooth') && (text.contains('off') || text.contains('disabled'))) {
      return const NativeError.bluetoothOff();
    }
    return NativeError('SCAN_FAILED', 'Bluetooth scan failed. Try again. ($e)');
  }
}
