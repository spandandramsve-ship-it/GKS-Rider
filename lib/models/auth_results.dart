import 'rider.dart';

/// Result of `POST /rider/auth/login`.
class LoginResult {
  final String phone;
  final String? devCode; // dev/staging only — never show in prod
  final int expiresInSeconds;

  const LoginResult({
    required this.phone,
    this.devCode,
    required this.expiresInSeconds,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      phone: json['phone'] as String? ?? '',
      devCode: json['devCode'] as String?,
      expiresInSeconds: json['expiresInSeconds'] as int? ?? 300,
    );
  }
}

/// Result of `POST /rider/auth/verify-otp`.
class VerifyOtpResult {
  final String token;
  final Rider rider;

  const VerifyOtpResult({required this.token, required this.rider});

  factory VerifyOtpResult.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResult(
      token: json['token'] as String,
      rider: Rider.fromJson(json['rider'] as Map<String, dynamic>),
    );
  }
}
