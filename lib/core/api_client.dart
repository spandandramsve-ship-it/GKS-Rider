import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/env.dart';
import 'api_exception.dart';
import 'session.dart';

/// Callback invoked when a 401 is received anywhere — the app should
/// clear session and navigate to Login.
typedef OnUnauthorized = void Function();

/// Singleton Dio client with:
/// - Auth interceptor (attaches JWT Bearer header)
/// - Response envelope unwrap ({success, data, message})
/// - Global 401 handling
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio dio;
  OnUnauthorized? onUnauthorized;

  /// Must be called once at app startup.
  void init() {
    dio = Dio(
      BaseOptions(
        baseUrl: Env.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  // ── Request: attach JWT if present ────────────────────────────────────

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await Session.instance.token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    debugPrint('[API] 🚀 ${options.method} ${options.uri}');
    handler.next(options);
  }

  // ── Response: unwrap the {success, data, message} envelope ────────────

  void _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    final body = response.data;
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      if (map.containsKey('success')) {
        if (map['success'] == true) {
          debugPrint('[API] ✅ ${response.requestOptions.method} ${response.requestOptions.uri} (${response.statusCode})');
          // Replace the full envelope with just the `data` payload if the key
          // is present (even if null — e.g. "no active order"), otherwise
          // keep the full map (e.g. for endpoints returning messages only).
          if (map.containsKey('data')) {
            response.data = map['data'];
          } else {
            response.data = map;
          }
          handler.next(response);
        } else {
          // Backend explicitly returned success: false.
          final msg = map['message'] as String? ??
              map['error'] as String? ??
              'Something went wrong';
          debugPrint('[API] ❌ ${response.requestOptions.method} ${response.requestOptions.uri} (${response.statusCode}): $msg');
          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              error: ApiException(msg, statusCode: response.statusCode),
            ),
          );
        }
      } else {
        // No 'success' wrapper present — standard REST payload, pass through.
        debugPrint('[API] ✅ ${response.requestOptions.method} ${response.requestOptions.uri} (${response.statusCode})');
        response.data = map;
        handler.next(response);
      }
    } else {
      debugPrint('[API] ✅ ${response.requestOptions.method} ${response.requestOptions.uri} (${response.statusCode})');
      handler.next(response);
    }
  }

  // ── Error: convert DioException → ApiException, handle 401 ────────────

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // If we already wrapped it in _onResponse, pass through.
    if (err.error is ApiException) {
      handler.reject(err);
      return;
    }

    final statusCode = err.response?.statusCode;
    String message = 'Something went wrong';

    // Try to extract the backend message from the response body.
    final data = err.response?.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['message'] is String && (map['message'] as String).isNotEmpty) {
        message = map['message'] as String;
      } else if (map['error'] is String && (map['error'] as String).isNotEmpty) {
        message = map['error'] as String;
      }
    }

    if (message == 'Something went wrong') {
      if (err.type == DioExceptionType.connectionTimeout ||
          err.type == DioExceptionType.receiveTimeout) {
        message = 'Connection timed out. Please try again.';
      } else if (err.type == DioExceptionType.connectionError) {
        message = 'Unable to reach server at ${err.requestOptions.uri}. Check network or backend server.';
      } else if (err.message != null && err.message!.isNotEmpty) {
        message = err.message!;
      }
    }

    debugPrint('[API] ❌ ${err.requestOptions.method} ${err.requestOptions.uri} [Status ${statusCode ?? "N/A"}]: $message');

    // Global 401 handling — force logout.
    if (statusCode == 401) {
      // Don't trigger global logout for wrong-code responses: login OTP
      // verification or delivery-code completion. Those are business-logic
      // failures on the current screen, not an expired/invalid session.
      final path = err.requestOptions.path;
      final isCodeVerification =
          path.contains('verify-otp') || path.endsWith('/complete');
      if (!isCodeVerification) {
        debugPrint('[ApiClient] 401 received — triggering global logout');
        await Session.instance.clear();
        onUnauthorized?.call();
      }
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        error: ApiException(message, statusCode: statusCode),
      ),
    );
  }
}

// ── Convenience: extract ApiException from a caught error ─────────────

ApiException extractApiException(dynamic error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    if (error.error is ApiException) {
      return error.error as ApiException;
    }
    final data = error.response?.data;
    String? msg;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      msg = map['message'] as String? ?? map['error'] as String?;
    }
    msg ??= error.message;
    return ApiException(
      msg ?? 'Something went wrong',
      statusCode: error.response?.statusCode,
    );
  }
  return ApiException(error.toString());
}
