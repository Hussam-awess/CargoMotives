import 'dart:math';

import 'package:dio/dio.dart';

import '../auth/session_store.dart';
import '../config/app_config.dart';
import 'api_exception.dart';

/// Thin wrapper around Dio, shared by every feature's repository. Centralizes
/// what matters for a mobile client on patchy connections (per the brief's
/// reliability requirements):
///  1. Timeouts — a hung request must fail visibly, not spin forever.
///  2. Retries — a read (GET) that fails on a dropped connection, a timeout,
///     or a momentary 502/503/504 is retried a couple of times with backoff
///     before giving up. Writes are never retried automatically: repeating a
///     POST (a bid, a payment) could do it twice.
///  3. Auth — the current session's token is attached automatically, so
///     repositories never touch SessionStore themselves.
///  4. Tracing — every request carries a fresh X-Request-Id, which the
///     backend puts on every log line for that request; a server error
///     shown to the user includes it as a reference.
///  5. Error normalization — every failure surfaces as an ApiException with
///     a presentable message, never a raw DioException leaking into UI code.
class ApiClient {
  ApiClient({SessionStore? sessionStore, Dio? dio, Duration Function(int attempt)? retryDelay})
    : _sessionStore = sessionStore ?? SessionStore(),
      _retryDelay = retryDelay ?? _defaultRetryDelay,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: '${AppConfig.apiBaseUrl}/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Accept': 'application/json'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers[_requestIdHeader] = _newRequestId();
          final token = await _sessionStore.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static const _requestIdHeader = 'X-Request-Id';
  static const _maxGetRetries = 2;
  static final _random = Random.secure();

  final Dio _dio;
  final SessionStore _sessionStore;
  final Duration Function(int attempt) _retryDelay;

  static Duration _defaultRetryDelay(int attempt) => Duration(milliseconds: 400 * (1 << attempt));

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(path, data: data);
      return _asMap(response.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _dio.get(path);
        return _asMap(response.data);
      } on DioException catch (e) {
        if (attempt < _maxGetRetries && _isTransient(e)) {
          await Future<void>.delayed(_retryDelay(attempt));
          continue;
        }
        throw _mapError(e);
      }
    }
  }

  Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.delete(path, data: data);
      return _asMap(response.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// For multipart submissions (file uploads) — everything else about
  /// error handling/auth is identical to [post], just a different Dio
  /// payload type so it sends `multipart/form-data` instead of JSON.
  Future<Map<String, dynamic>> postForm(String path, FormData data) async {
    try {
      final response = await _dio.post(path, data: data);
      return _asMap(response.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// A failure worth retrying for a read: the request never got a real
  /// answer (network dropped, timed out) or a gateway/load balancer
  /// reported the server momentarily unavailable. Never a 4xx (retrying
  /// won't change the answer) and never 429 (retrying makes it worse).
  static bool _isTransient(DioException e) {
    final status = e.response?.statusCode;
    if (status != null) return status == 502 || status == 503 || status == 504;
    return const {
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
    }.contains(e.type);
  }

  static String _newRequestId() =>
      'm-${List.generate(12, (_) => _random.nextInt(16).toRadixString(16)).join()}';

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  ApiException _mapError(DioException e) {
    final response = e.response;
    final requestId = e.requestOptions.headers[_requestIdHeader] as String?;

    if (response == null) {
      final timedOut = {
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      }.contains(e.type);

      return ApiException(
        timedOut
            ? 'The request timed out. Check your connection and try again.'
            : 'Could not reach the server. Check your connection and try again.',
        requestId: requestId,
      );
    }

    final body = _asMap(response.data);
    final statusCode = response.statusCode ?? 0;

    // A 5xx body is never a message written for the user ("Server Error"),
    // so show a plain one with the reference that finds it in the logs.
    final message = statusCode >= 500
        ? 'Something went wrong on our side. Please try again in a moment.'
              '${requestId != null ? ' (Ref: $requestId)' : ''}'
        : body['message'] is String
        ? body['message'] as String
        : 'Something went wrong. Please try again.';

    Map<String, List<String>>? fieldErrors;
    final errors = body['errors'];
    if (errors is Map) {
      fieldErrors = errors.map(
        (key, value) => MapEntry(
          key.toString(),
          value is List ? value.map((v) => v.toString()).toList() : <String>[],
        ),
      );
    }

    return ApiException(
      message,
      statusCode: response.statusCode,
      fieldErrors: fieldErrors,
      body: body,
      requestId: requestId,
    );
  }
}
