import 'dart:async';

import 'package:flutter/widgets.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../api/models.dart';
import '../config.dart';

/// One shared live feed of the student's elections.
///
/// Polls the backend every 10 seconds while the app is in the foreground and refreshes
/// immediately when the app comes back to the front, so election status is never stale.
/// [skew] is the difference between the server clock and the phone clock, used by countdowns.
class OverviewController extends ChangeNotifier with WidgetsBindingObserver {
  OverviewController({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Overview? _data;
  String? _error;
  Duration _skew = Duration.zero;
  Timer? _timer;
  bool _loading = false;
  bool _disposed = false;

  Overview? get data => _data;
  String? get error => _error;
  Duration get skew => _skew;
  bool get isLoading => _data == null && _error == null;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.overviewRefresh, (_) => refresh());
  }

  Future<void> refresh() async {
    if (_loading || _disposed) return;
    _loading = true;
    try {
      final o = await _api.overview();
      if (_disposed) return;
      _skew = o.serverTime.difference(DateTime.now());
      _data = o;
      _error = null;
    } on ApiError catch (e) {
      if (_disposed) return;
      _error = e.message;
    } catch (_) {
      if (_disposed) return;
      _error = 'Something went wrong.';
    } finally {
      _loading = false;
    }
    notifyListeners();
  }

  /// Poll only while the app is in front; refresh at once when it comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh());
      _startTimer();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
