import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../native/beacon_parser.dart';
import 'api_error.dart';
import 'models.dart';
import 'session.dart';

/// Thin JSON client for the election backend.
///
/// Every call attaches the student's bearer token when one is held. A 401 answer clears the
/// session so the app returns to the sign-in screen; any other failure surfaces as an [ApiError]
/// carrying the backend's message and code.
class ApiClient {
  ApiClient({http.Client? client, Session? session, String? base})
      : _client = client ?? http.Client(),
        _session = session ?? Session.instance,
        _base = (base ?? AppConfig.apiBase).replaceAll(RegExp(r'/+$'), '');

  static final ApiClient instance = ApiClient();

  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _client;
  final Session _session;
  final String _base;

  String get base => _base;

  /// Performs a request and returns the decoded JSON object.
  ///
  /// [method] defaults to POST when a [body] is given and GET otherwise, matching the web client.
  Future<Map<String, dynamic>> call(String path, {String? method, Object? body}) async {
    final token = _session.token;
    final request = http.Request(method ?? (body != null ? 'POST' : 'GET'), Uri.parse('$_base$path'))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(request).timeout(_timeout));
    } catch (_) {
      throw const ApiError.network();
    }

    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {/* non-JSON body */}

    if (res.statusCode == 401 && token != null) _session.forceSignOut();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(
        res.statusCode,
        data['error']?.toString() ?? 'Something went wrong.',
        code: data['code']?.toString(),
        details: data['details'],
      );
    }
    return data;
  }

  // ── Authentication ──────────────────────────────────────────────────────────

  Future<String> login({required String indexNumber, required String password}) async {
    final r = await call('/auth/student/login', body: {'indexNumber': indexNumber, 'password': password});
    return r['token'] as String;
  }

  /// Step 1 of account creation: returns the masked email the verification code was sent to.
  Future<String> registerStart({required String fullName, required String indexNumber, required String email}) async {
    final r = await call(
      '/auth/student/register/start',
      body: {'fullName': fullName, 'indexNumber': indexNumber, 'email': email},
    );
    return r['maskedEmail']?.toString() ?? email;
  }

  /// Step 2 of account creation: verifies the emailed code and returns a sign-in token.
  Future<String> registerFinish({required String indexNumber, required String code, required String password}) async {
    final r = await call(
      '/auth/student/register',
      body: {'indexNumber': indexNumber, 'code': code, 'password': password},
    );
    return r['token'] as String;
  }

  Future<void> recoverStart({required String indexNumber, required String email}) =>
      call('/auth/student/recover/start', body: {'indexNumber': indexNumber, 'email': email});

  Future<void> recoverFinish({required String indexNumber, required String code, required String newPassword}) =>
      call('/auth/student/recover', body: {'indexNumber': indexNumber, 'code': code, 'newPassword': newPassword});

  Future<Me> me() async => Me.fromJson(await call('/auth/student/me'));

  Future<Me> updateProfile({required String fullName, required int level, required int semester}) async =>
      Me.fromJson(
        await call(
          '/auth/student/profile',
          method: 'PATCH',
          body: {'fullName': fullName, 'level': level, 'semester': semester},
        ),
      );

  // ── Elections ───────────────────────────────────────────────────────────────

  Future<Overview> overview() async => Overview.fromJson(await call('/student/overview'));

  Future<ElectionDetail> election(String id) async => ElectionDetail.fromJson(await call('/student/elections/$id'));

  Future<Results> results(String id) async => Results.fromJson(await call('/student/elections/$id/results'));

  /// Asks the server for a single-use voting authorisation. [claim] is the polling-node beacon
  /// seen by the phone (omitted when the election does not require presence).
  Future<VoteAuthorization> presence(String electionId, {BeaconClaim? claim}) async => VoteAuthorization.fromJson(
        await call(
          '/student/elections/$electionId/presence',
          body: {if (claim != null) 'claim': claim.toJson()},
        ),
      );

  /// Casts the ballot and returns the receipt id.
  Future<String> vote(String electionId, {required String authorization, required List<Map<String, dynamic>> choices}) async {
    final r = await call(
      '/student/elections/$electionId/vote',
      body: {'authorization': authorization, 'choices': choices},
    );
    return r['receiptId']?.toString() ?? '';
  }

  // ── Notifications ───────────────────────────────────────────────────────────

  /// A limited token that can only read the notification feed; handed to the background checker.
  Future<String> notifyToken() async {
    final r = await call('/student/notify-token', method: 'POST');
    return r['token'] as String;
  }
}
