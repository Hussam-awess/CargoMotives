/// A normalized, user-presentable API failure. Every network call in the
/// app should end up throwing this (never a raw DioException) so screens
/// have one consistent shape to handle — a message to show, optional
/// per-field validation errors (Laravel's `errors` object), and whatever
/// else the endpoint returned (`body`) for the few cases that need more
/// (e.g. the OTP cooldown's `seconds_remaining`).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors, this.body, this.requestId});

  final String message;
  final int? statusCode;
  final Map<String, List<String>>? fieldErrors;
  final Map<String, dynamic>? body;

  /// The X-Request-Id this call was sent with — the same id is on every
  /// server log line for it, so a support request quoting it can be traced
  /// to the exact request.
  final String? requestId;

  String? firstErrorFor(String field) {
    final errors = fieldErrors?[field];
    return (errors != null && errors.isNotEmpty) ? errors.first : null;
  }

  @override
  String toString() => message;
}
