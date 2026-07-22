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
    handler.next(options);
  }

  // ── Response: unwrap the {success, data, message} envelope ────────────

  void _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      if (body['success'] == true) {
        // Replace the full envelope with just the `data` payload.
        response.data = body['data'];
        handler.next(response);
      } else {
        // Backend explicitly returned success: false.
        final msg = body['message'] as String? ?? 'Something went wrong';
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            error: ApiException(msg, statusCode: response.statusCode),
          ),
        );
      }
    } else {
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
    if (data is Map<String, dynamic> && data.containsKey('message')) {
      message = data['message'] as String;
    } else if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timed out. Please try again.';
    } else if (err.type == DioExceptionType.connectionError) {
      message = 'Unable to reach the server. Check your connection.';
    }

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
  if (error is DioException && error.error is ApiException) {
    return error.error as ApiException;
  }
  if (error is DioException) {
    return ApiException(
      error.message ?? 'Something went wrong',
      statusCode: error.response?.statusCode,
    );
  }
  return ApiException(error.toString());
}
