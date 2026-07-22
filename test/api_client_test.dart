import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:gks_rider/core/api_client.dart';
import 'package:gks_rider/core/api_exception.dart';
import 'package:gks_rider/config/env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Env configuration', () {
    test('baseUrl returns a non-empty String', () {
      expect(Env.baseUrl, isNotEmpty);
      expect(Env.socketUrl, isNotEmpty);
    });
  });

  group('ApiClient envelope & error handling', () {
    test('extractApiException extracts ApiException directly', () {
      const apiErr = ApiException('Custom error', statusCode: 400);
      expect(extractApiException(apiErr), equals(apiErr));
    });

    test('extractApiException extracts message from DioException with ApiException inside error', () {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/test'),
        error: const ApiException('Inner API error', statusCode: 403),
      );
      final extracted = extractApiException(dioErr);
      expect(extracted.message, equals('Inner API error'));
      expect(extracted.statusCode, equals(403));
    });

    test('extractApiException extracts message from response body', () {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
          data: {'message': 'Bad request payload'},
        ),
      );
      final extracted = extractApiException(dioErr);
      expect(extracted.message, equals('Bad request payload'));
      expect(extracted.statusCode, equals(400));
    });
  });
}
