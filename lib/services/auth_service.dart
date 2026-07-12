import '../core/api_client.dart';
import '../models/auth_results.dart';
import '../models/rider.dart';

/// Auth-related API calls (endpoints #1–#6).
class AuthService {
  final _dio = ApiClient.instance.dio;

  /// #1 POST /rider/auth/login
  Future<LoginResult> login(String phone, String password) async {
    final res = await _dio.post(
      '/rider/auth/login',
      data: {'phone': phone, 'password': password},
    );
    return LoginResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// #2 POST /rider/auth/resend-otp
  Future<String> resendOtp(String phone) async {
    final res = await _dio.post(
      '/rider/auth/resend-otp',
      data: {'phone': phone},
    );
    // The response may contain a message; data could be null or a map.
    if (res.data is Map<String, dynamic>) {
      return (res.data as Map<String, dynamic>)['message'] as String? ??
          'OTP resent';
    }
    return 'OTP resent';
  }

  /// #3 POST /rider/auth/verify-otp
  Future<VerifyOtpResult> verifyOtp(String phone, String code) async {
    final res = await _dio.post(
      '/rider/auth/verify-otp',
      data: {'phone': phone, 'code': code},
    );
    return VerifyOtpResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// #4 GET /rider/auth/me
  Future<Rider> me() async {
    final res = await _dio.get('/rider/auth/me');
    return Rider.fromJson(res.data as Map<String, dynamic>);
  }

  /// #5 POST /rider/auth/location (go online)
  Future<void> postLocation(double lat, double lng) async {
    await _dio.post(
      '/rider/auth/location',
      data: {'lat': lat, 'lng': lng},
    );
  }

  /// #6 POST /rider/auth/offline (go offline)
  Future<void> goOffline() async {
    await _dio.post('/rider/auth/offline');
  }
}
