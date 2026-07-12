/// Typed API error thrown when the backend returns `{success: false}` or
/// an HTTP status >= 400.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
