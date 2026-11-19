import 'dart:convert';

import 'package:election_student/native/notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _feed(List<Map<String, Object>> items) => jsonEncode({'items': items});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> shown;
  Future<void> capture(int id, String title, String body) async => shown.add('$title | $body');

  setUp(() {
    shown = [];
    SharedPreferences.setMockInitialValues({});
  });

  test('first check only records state, later checks notify on change', () async {
    final store = await NotifyStore.load();
    await store.set('x' * 32, 'https://api.example.test');

    await NotifyWorker.process(
      store,
      _feed([
        {'electionId': 'e1', 'key': 'SCHEDULED|1', 'state': 'SCHEDULED', 'title': 'SRC', 'body': 'Opens Monday'},
      ]),
      show: capture,
    );
    expect(shown, isEmpty);
    expect(store.seeded, isTrue);

    await NotifyWorker.process(
      store,
      _feed([
        {'electionId': 'e1', 'key': 'SCHEDULED|1', 'state': 'SCHEDULED', 'title': 'SRC', 'body': 'Opens Monday'},
      ]),
      show: capture,
    );
    expect(shown, isEmpty, reason: 'unchanged key');

    await NotifyWorker.process(
      store,
      _feed([
        {'electionId': 'e1', 'key': 'SCHEDULED|2', 'state': 'SCHEDULED', 'title': 'SRC', 'body': 'Opens Tuesday'},
      ]),
      show: capture,
    );
    expect(shown, ['Election schedule updated: SRC | Opens Tuesday']);

    await NotifyWorker.process(
      store,
      _feed([
        {'electionId': 'e1', 'key': 'ACTIVE|3', 'state': 'ACTIVE', 'title': 'SRC', 'body': 'Vote now'},
        {'electionId': 'e2', 'key': 'PUBLISHED|1', 'state': 'PUBLISHED', 'title': 'Hall', 'body': 'See results'},
      ]),
      show: capture,
    );
    expect(shown.skip(1), ['Voting is open: SRC | Vote now', 'Results published: Hall | See results']);
  });

  test('run() clears the store on 401 and asks for a retry on server errors', () async {
    final store = await NotifyStore.load();
    await store.set('x' * 32, 'https://api.example.test');

    expect(await NotifyWorker.run(client: MockClient((_) async => http.Response('', 500)), store: store), isFalse);
    expect(store.token, isNotNull);

    expect(await NotifyWorker.run(client: MockClient((_) async => http.Response('', 401)), store: store), isTrue);
    expect(store.token, isNull);

    // Nothing configured: nothing to do.
    expect(await NotifyWorker.run(client: MockClient((_) async => fail('must not call')), store: store), isTrue);
  });

  test('run() sends the limited token to the notify feed', () async {
    final store = await NotifyStore.load();
    await store.set('y' * 32, 'https://api.example.test');
    http.Request? seen;
    final ok = await NotifyWorker.run(
      client: MockClient((req) async {
        seen = req;
        return http.Response(_feed([]), 200);
      }),
      store: store,
    );
    expect(ok, isTrue);
    expect(seen!.url.toString(), 'https://api.example.test/student/notify-feed');
    expect(seen!.headers['Authorization'], 'Bearer ${'y' * 32}');
  });

  test('notification ids are stable and non-negative', () {
    expect(NotifyWorker.notificationId('e1'), NotifyWorker.notificationId('e1'));
    expect(NotifyWorker.notificationId('e1'), greaterThanOrEqualTo(0));
    expect(NotifyWorker.notificationId('e1'), lessThan(1 << 31));
  });
}
