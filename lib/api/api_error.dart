/// An error returned by the election backend (or raised when it cannot be reached).
///
/// [status] is the HTTP status (0 when the request never reached the server). [code] is the
/// machine-readable error code the backend attaches to failures (e.g. `ACCOUNT_EXISTS`,
/// `NODE_REJECTED`, `AUTH_EXPIRED`), and [message] is already phrased for the student.
class ApiError implements Exception {
  const ApiError(this.status, this.message, {this.code, this.details});

  /// Raised when the device is offline or the server is unreachable.
  const ApiError.network()
      : this(
          0,
          'Cannot reach the server. Check your internet connection and try again.',
          code: 'NETWORK',
        );

  final int status;
  final String message;
  final String? code;
  final Object? details;

  bool get isNetwork => code == 'NETWORK';

  @override
  String toString() => message;
}
