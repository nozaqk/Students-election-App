import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';

/// Holds the student's sign-in token.
///
/// The token is persisted in encrypted, app-private storage together with an expiry so a stale
/// token is never sent. [signedIn] lets the UI switch between the sign-in screen and the app, and
/// [onForcedSignOut] fires when the server rejects the token (HTTP 401) so background work stops.
class Session {
  Session({FlutterSecureStorage? storage, DateTime Function()? clock})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _clock = clock ?? DateTime.now;

  static final Session instance = Session();

  static const _key = 'election.session';

  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  final StreamController<void> _forced = StreamController<void>.broadcast();

  String? _token;
  DateTime? _exp;

  /// True while a valid token is held.
  final ValueNotifier<bool> signedIn = ValueNotifier<bool>(false);

  /// Emits when the server invalidated the session (expired or revoked token).
  Stream<void> get onForcedSignOut => _forced.stream;

  /// Loads a previously saved token, if it has not expired.
  Future<void> restore() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final exp = DateTime.fromMillisecondsSinceEpoch(m['exp'] as int);
        if (exp.isAfter(_clock())) {
          _token = m['token'] as String;
          _exp = exp;
        } else {
          await _storage.delete(key: _key);
        }
      }
    } catch (_) {
      // Storage unavailable or corrupt: start signed out.
    }
    signedIn.value = token != null;
  }

  /// The current token, or null when signed out or expired.
  String? get token {
    final exp = _exp;
    if (exp != null && !exp.isAfter(_clock())) {
      _token = null;
      _exp = null;
      signedIn.value = false;
    }
    return _token;
  }

  /// Stores a fresh token (or clears the session when [value] is null).
  Future<void> setToken(String? value) async {
    if (value == null) {
      _token = null;
      _exp = null;
      signedIn.value = false;
      try {
        await _storage.delete(key: _key);
      } catch (_) {/* storage unavailable */}
      return;
    }
    _token = value;
    _exp = _clock().add(AppConfig.sessionLifetime);
    signedIn.value = true;
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({'token': value, 'exp': _exp!.millisecondsSinceEpoch}),
      );
    } catch (_) {/* storage unavailable: the session lasts until the app closes */}
  }

  /// Called when the backend answers 401 to an authenticated request.
  void forceSignOut() {
    unawaited(setToken(null));
    _forced.add(null);
  }
}
