import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Formats a remaining duration as `Xd HH:MM:SS` (the day part only when non-zero).
String formatCountdown(Duration remaining) {
  final s = remaining.isNegative ? 0 : remaining.inSeconds;
  final d = s ~/ 86400;
  final h = (s % 86400) ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d > 0 ? '${d}d ' : ''}${p(h)}:${p(m)}:${p(sec)}';
}

/// Big ticking timer until [to], corrected by the server/phone clock [skew].
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.to, required this.skew});

  final DateTime to;
  final Duration skew;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().add(widget.skew);
    return Semantics(
      label: 'Time remaining',
      child: Text(
        formatCountdown(widget.to.difference(now)),
        style: TextStyle(
          color: context.palette.green2,
          fontSize: 25.6,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          height: 1.3,
        ),
      ),
    );
  }
}
