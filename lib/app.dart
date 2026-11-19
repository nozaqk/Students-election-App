import 'dart:async';

import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'api/models.dart';
import 'api/session.dart';
import 'config.dart';
import 'native/bluetooth_monitor.dart';
import 'native/notifications.dart';
import 'screens/auth_screen.dart';
import 'screens/shell_screen.dart';
import 'theme/app_theme.dart';

/// Root widget: theme, and the switch between the sign-in screen and the signed-in shell.
class ElectionApp extends StatelessWidget {
  const ElectionApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const _Root(),
      );
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  final Session _session = Session.instance;
  final ApiClient _api = ApiClient.instance;
  final BluetoothMonitor _bluetooth = BluetoothMonitor.instance;

  Me? _me;
  StreamSubscription<void>? _forcedSignOut;

  @override
  void initState() {
    super.initState();
    _session.signedIn.addListener(_onSessionChanged);
    _forcedSignOut = _session.onForcedSignOut.listen((_) => _teardown());
    if (_session.signedIn.value) _onSignedIn();
  }

  @override
  void dispose() {
    _session.signedIn.removeListener(_onSessionChanged);
    _forcedSignOut?.cancel();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
    if (_session.signedIn.value) _onSignedIn();
  }

  /// After sign-in: load the profile, start the Bluetooth badge and background notifications.
  void _onSignedIn() {
    unawaited(_loadMe());
    unawaited(_bluetooth.start());
    unawaited(_startNotifications());
  }

  Future<void> _loadMe() async {
    try {
      final me = await _api.me();
      if (mounted) setState(() => _me = me);
    } catch (_) {
      // The shell shows "Loading…" for the profile; the next sign-in retries.
    }
  }

  /// Hand the background checker a limited token (it can only read the notification feed).
  Future<void> _startNotifications() async {
    try {
      final token = await _api.notifyToken();
      await ElectionNotifications.start(token, _api.base);
    } catch (_) {
      // Notifications are a convenience; voting works without them.
    }
  }

  /// Stops phone-side features when the session ends (sign-out or token rejected).
  void _teardown() {
    unawaited(ElectionNotifications.stop());
    unawaited(_bluetooth.stop());
    if (mounted) setState(() => _me = null);
  }

  Future<void> _signOut() async {
    _teardown();
    await _session.setToken(null);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _session.signedIn.value;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: signedIn
          ? ShellScreen(
              key: const ValueKey('shell'),
              me: _me,
              onMeChanged: (m) => setState(() => _me = m),
              onSignOut: _signOut,
            )
          : AuthScreen(key: const ValueKey('auth'), onDone: () {}),
    );
  }
}
