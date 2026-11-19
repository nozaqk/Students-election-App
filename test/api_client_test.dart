import 'dart:convert';

import 'package:election_student/api/api_client.dart';
import 'package:election_student/api/api_error.dart';
import 'package:election_student/api/session.dart';
import 'package:election_student/native/beacon_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Session session;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    session = Session(storage: const FlutterSecureStorage());
  });

  ApiClient client(Future<http.Response> Function(http.Request) handler) =>
      ApiClient(client: MockClient(handler), session: session, base: 'https://api.example.test/');

  test('GET by default, POST with a body, bearer token attached', () async {
    await session.setToken('tok123');
    http.Request? seen;
    final api = client((req) async {
      seen = req;
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    await api.call('/student/overview');
    expect(seen!.method, 'GET');
    expect(seen!.url.toString(), 'https://api.example.test/student/overview');
    expect(seen!.headers['Authorization'], 'Bearer tok123');

    await api.call('/x', body: {'a': 1});
    expect(seen!.method, 'POST');
    expect(jsonDecode(seen!.body), {'a': 1});
  });

  test('backend errors become ApiError with code and message', () async {
    final api = client((_) async => http.Response(jsonEncode({'error': 'Nope', 'code': 'NODE_REJECTED'}), 409));
    try {
      await api.call('/student/elections/1/presence', body: {});
      fail('expected ApiError');
    } on ApiError catch (e) {
      expect(e.status, 409);
      expect(e.code, 'NODE_REJECTED');
      expect(e.message, 'Nope');
    }
  });

  test('401 with a token signs the student out', () async {
    await session.setToken('tok123');
    var forced = 0;
    session.onForcedSignOut.listen((_) => forced++);
    final api = client((_) async => http.Response('{}', 401));
    await expectLater(api.call('/auth/student/me'), throwsA(isA<ApiError>()));
    await Future<void>.delayed(Duration.zero);
    expect(session.token, isNull);
    expect(session.signedIn.value, isFalse);
    expect(forced, 1);
  });

  test('network failures use the friendly message', () async {
    final api = client((_) async => throw http.ClientException('boom'));
    try {
      await api.call('/student/overview');
      fail('expected ApiError');
    } on ApiError catch (e) {
      expect(e.isNetwork, isTrue);
      expect(e.status, 0);
    }
  });

  test('presence omits the claim when the election does not require it', () async {
    http.Request? seen;
    final api = client((req) async {
      seen = req;
      return http.Response(jsonEncode({'authorization': 'A', 'expiresAt': '2030-01-01T00:00:00Z'}), 200);
    });
    await api.presence('e1');
    expect(jsonDecode(seen!.body), <String, dynamic>{});

    const claim = BeaconClaim(beaconId: 7, bootNonce: 'deadbeef', counter: 3, mac: 'ff');
    final auth = await api.presence('e1', claim: claim);
    expect(jsonDecode(seen!.body), {'claim': claim.toJson()});
    expect(auth.token, 'A');
  });

  test('session restores an unexpired token and drops an expired one', () async {
    FlutterSecureStorage.setMockInitialValues({
      'election.session': jsonEncode({'token': 'live', 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch}),
    });
    final s = Session(storage: const FlutterSecureStorage());
    await s.restore();
    expect(s.token, 'live');
    expect(s.signedIn.value, isTrue);

    FlutterSecureStorage.setMockInitialValues({
      'election.session': jsonEncode({'token': 'old', 'exp': DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch}),
    });
    final s2 = Session(storage: const FlutterSecureStorage());
    await s2.restore();
    expect(s2.token, isNull);
    expect(s2.signedIn.value, isFalse);
  });
}
