import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, visibleForTesting, TargetPlatform;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'permissions.dart';

/// App-private storage for the background notification checker.
///
/// Holds the limited feed token, the API base and the last seen state of every election so the
/// student is only told about changes.
class NotifyStore {
  NotifyStore._(this._prefs);

  static const _prefix = 'notify.';

  final SharedPreferences _prefs;

  static Future<NotifyStore> load() async => NotifyStore._(await SharedPreferences.getInstance());

  String? get token => _prefs.getString('${_prefix}token');
  String? get apiBase => _prefs.getString('${_prefix}base');

  /// False until the first successful check after sign-in (which only records the current state).
  bool get seeded => _prefs.getBool('${_prefix}seeded') ?? false;

  Future<void> set(String token, String apiBase) async {
    await _prefs.setString('${_prefix}token', token);
    await _prefs.setString('${_prefix}base', apiBase);
  }

  Map<String, String> seen() {
    try {
      final raw = _prefs.getString('${_prefix}seen') ?? '{}';
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, String> seen) async {
    await _prefs.setString('${_prefix}seen', jsonEncode(seen));
    await _prefs.setBool('${_prefix}seeded', true);
  }

  Future<void> clear() async {
    for (final k in _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await _prefs.remove(k);
    }
  }
}

/// Shows election updates as normal phone notifications. Tapping one opens the app.
abstract class Notifier {
  static const String channelId = 'election_updates';
  static const String channelName = 'Election updates';
  static const String channelDescription = 'Announcements, voting opening and closing, and published results';

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> ensureChannel() async {
    if (_ready) return;
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('ic_stat_vote')),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
          ),
        );
    _ready = true;
  }

  static Future<void> show(int id, String title, String text) async {
    await ensureChannel();
    await _plugin.show(
      id,
      title,
      text,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(text),
          autoCancel: true,
        ),
      ),
    );
  }
}

/// Checks the server for election changes while the app is closed and raises a phone notification
/// for anything new. Uses a limited, server-issued token that can only read the notification feed
/// (it cannot vote or read ballots). Android runs periodic background work at most every ~15
/// minutes; the first check after login only records the current state so the student is not
/// flooded with notifications for things they already saw.
abstract class NotifyWorker {
  static const Duration _timeout = Duration(seconds: 15);

  static const Map<String, String> _headlines = {
    'SCHEDULED': 'New election announced',
    'ACTIVE': 'Voting is open',
    'PAUSED': 'Voting paused',
    'DEACTIVATED': 'Election withdrawn',
    'ENDED': 'Voting has ended',
    'PUBLISHED': 'Results published',
  };

  /// Returns true when the work is complete and false when it should be retried later.
  static Future<bool> run({http.Client? client, NotifyStore? store}) async {
    final s = store ?? await NotifyStore.load();
    final token = s.token;
    final base = s.apiBase;
    if (token == null || base == null) return true;
    final c = client ?? http.Client();
    try {
      final res = await c
          .get(Uri.parse('$base/student/notify-feed'), headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout);
      switch (res.statusCode) {
        case 200:
          await process(s, utf8.decode(res.bodyBytes));
          return true;
        case 401:
        case 403:
          await s.clear(); // session revoked or expired: stop quietly
          return true;
        default:
          return false;
      }
    } catch (_) {
      return false;
    } finally {
      if (client == null) c.close();
    }
  }

  @visibleForTesting
  static Future<void> process(NotifyStore store, String body, {Future<void> Function(int, String, String)? show}) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    final items = decoded['items'];
    if (items is! List) return;

    final seen = store.seen();
    final first = !store.seeded;
    final notify = show ?? Notifier.show;

    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final id = raw['electionId']?.toString();
      final key = raw['key']?.toString();
      final state = raw['state']?.toString() ?? '';
      if (id == null || key == null) continue;
      final title = raw['title']?.toString() ?? '';
      final old = seen[id] ?? '';
      if (!first && old != key) {
        final sameState = old.split('|').first == state;
        final head = sameState
            ? 'Election schedule updated'
            : _headlines[state] ?? raw['headline']?.toString() ?? 'Election update';
        await notify(notificationId(id), '$head: $title', raw['body']?.toString() ?? '');
      }
      seen[id] = key;
    }
    await store.save(seen);
  }

  /// Stable, non-negative 32-bit id per election so a newer update replaces the older one.
  static int notificationId(String electionId) => electionId.hashCode & 0x7fffffff;
}

/// Entry point for the background isolate started by WorkManager.
@pragma('vm:entry-point')
void notifyCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      return await NotifyWorker.run();
    } catch (_) {
      return false;
    }
  });
}

/// Schedules and cancels the background notification checks.
abstract class ElectionNotifications {
  static const String _periodic = 'election-notify';
  static const String _once = 'election-notify-once';
  static const String _task = 'electionNotifyCheck';

  static bool _initialised = false;

  static Future<void> init() async {
    if (_initialised || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _initialised = true;
    try {
      await Workmanager().initialize(notifyCallbackDispatcher);
    } catch (_) {/* background work unavailable on this device */}
  }

  /// Hands the checker a limited feed [token] for [apiBase] and starts the periodic checks.
  static Future<void> start(String token, String apiBase) async {
    final base = apiBase.replaceAll(RegExp(r'/+$'), '');
    if (token.length < 20 || token.length > 2000 || !base.startsWith('https://') || base.length >= 300) return;
    if (!_initialised) await init();

    final store = await NotifyStore.load();
    await store.set(token, base);
    await Notifier.ensureChannel();
    await AppPermissions.requestNotifications();

    final constraints = Constraints(networkType: NetworkType.connected);
    try {
      await Workmanager().registerPeriodicTask(
        _periodic,
        _task,
        frequency: const Duration(minutes: 15),
        constraints: constraints,
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      // Record the current state right away.
      await Workmanager().registerOneOffTask(
        _once,
        _task,
        constraints: constraints,
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    } catch (_) {/* background work unavailable on this device */}
  }

  static Future<void> stop() async {
    try {
      await Workmanager().cancelByUniqueName(_periodic);
      await Workmanager().cancelByUniqueName(_once);
    } catch (_) {/* never scheduled */}
    await (await NotifyStore.load()).clear();
  }
}
