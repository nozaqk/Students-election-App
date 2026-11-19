/// Build-time configuration.
///
/// Override the backend with a dart-define, e.g.
/// `flutter build apk --dart-define=API_URL=https://students-election-system.onrender.com`.
abstract class AppConfig {
  /// Public base URL of the election backend (no trailing slash).
  static const String _apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://students-election-system.onrender.com',
  );

  static String get apiBase => _apiUrl.replaceAll(RegExp(r'/+$'), '');

  static const String appName = 'Student Election';

  /// A sign-in token is kept for this long before the app asks the student to sign in again.
  static const Duration sessionLifetime = Duration(hours: 11);

  /// How often live election data is refreshed while a list screen is open.
  static const Duration overviewRefresh = Duration(seconds: 10);
}
