import 'package:dio/dio.dart';

import '../auth/session_store.dart';
import '../config/app_config.dart';
import 'api_exception.dart';

/// Thin wrapper around Dio, shared by every feature's repository. Centralizes
/// the three things that matter for a mobile client on patchy connections
/// (per the brief's reliability requirements):
///  1. Timeouts — a hung request must fail visibly, not spin forever.
///  2. Auth — the current session's token is attached automatically, so
///     repositories never touch SessionStore themselves.
///  3. Error normalization — every failure surfaces as an ApiException with
///     a presentable message, never a raw DioException leaking into UI code.
class ApiClient {
  ApiClient({SessionStore? sessionStore, Dio? dio})
    : _sessionStore = sessionStore ?? SessionStore(),
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
          final token = await _sessionStore.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final SessionStore _sessionStore;

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
    try {
      final response = await _dio.get(path);
      return _asMap(response.data);
    } on DioException catch (e) {
      throw _mapError(e);
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

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  ApiException _mapError(DioException e) {
    final response = e.response;

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
      );
    }

    final body = _asMap(response.data);
    final message = body['message'] is String
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
    );
  }
}
