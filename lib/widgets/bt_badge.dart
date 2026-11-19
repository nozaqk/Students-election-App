import 'package:flutter/material.dart';

import '../native/bluetooth_monitor.dart';

/// Bluetooth status badge in the header.
///
/// Red = phone Bluetooth off (tap to be asked to turn it on), yellow = Bluetooth on but no polling
/// device in range, green = polling-device signal in range. Hidden until the state is known.
class BtBadge extends StatelessWidget {
  const BtBadge({super.key, BluetoothMonitor? monitor}) : _monitor = monitor;

  final BluetoothMonitor? _monitor;

  static const Map<BtState, String> text = {
    BtState.off: 'Bluetooth is off. Tap to turn it on.',
    BtState.on: 'Bluetooth is on. No polling device in range.',
    BtState.node: 'Connected: polling device in range.',
  };

  @override
  Widget build(BuildContext context) {
    final monitor = _monitor ?? BluetoothMonitor.instance;
    return AnimatedBuilder(
      animation: monitor,
      builder: (context, _) {
        final st = monitor.state;
        if (st == null) return const SizedBox.shrink();
        final Color bg;
        final Color fg;
        final IconData icon;
        switch (st) {
          case BtState.off:
            bg = const Color(0xFFD93636);
            fg = Colors.white;
            icon = Icons.bluetooth_disabled;
          case BtState.on:
            bg = const Color(0xFFF2B705);
            fg = const Color(0xFF3A2A00);
            icon = Icons.bluetooth_searching;
          case BtState.node:
            bg = const Color(0xFF1FA855);
            fg = Colors.white;
            icon = Icons.bluetooth_connected;
        }
        final label = text[st]!;
        return Tooltip(
          message: label,
          child: Semantics(
            button: true,
            label: label,
            child: Material(
              color: bg,
              shape: const StadiumBorder(side: BorderSide(color: Colors.white, width: 2)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () {
                  if (st == BtState.off) {
                    monitor.ensureBluetooth();
                  } else {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(label), duration: const Duration(seconds: 2)));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Icon(icon, color: fg, size: 22),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
