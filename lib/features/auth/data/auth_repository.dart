import '../../../core/session.dart';
import '../../../core/socket_service.dart';
import 'auth_service.dart';
import 'models/auth_results.dart';
import 'models/rider.dart';

/// Wraps [AuthService] with session persistence and socket connect/disconnect
/// — the orchestration that used to live inline in `AuthState`.
class AuthRepository {
  final AuthService _authService = AuthService();

  /// Restores a session from secure storage. Returns the rider if the
  /// stored token is still valid, or `null` if there's no session / it's
  /// no longer valid (in which case the stored session is cleared).
  Future<Rider?> restoreSession() async {
    final token = await Session.instance.token;
    if (token == null) return null;

    try {
      final rider = await _authService.me();
      await Session.instance.setRider(rider.toJson());
      SocketService.instance.connect(token);
      return rider;
    } catch (_) {
      await Session.instance.clear();
      return null;
    }
  }

  Future<LoginResult> login(String phone, String password) {
    return _authService.login(phone, password);
  }

  Future<String> resendOtp(String phone) => _authService.resendOtp(phone);

  Future<VerifyOtpResult> verifyOtp(String phone, String code) async {
    final result = await _authService.verifyOtp(phone, code);
    await Session.instance.setToken(result.token);
    await Session.instance.setRider(result.rider.toJson());
    SocketService.instance.connect(result.token);
    return result;
  }

  Future<Rider> refreshProfile() async {
    final rider = await _authService.me();
    await Session.instance.setRider(rider.toJson());
    return rider;
  }

  /// Raw `/rider/auth/offline` call — no session teardown. Shared by the
  /// dashboard feature's "go offline" toggle and [logout] below.
  Future<void> goOffline() => _authService.goOffline();

  /// Polite logout — tries to go offline first, not required to succeed.
  Future<void> logout() async {
    try {
      await goOffline();
    } catch (_) {}
    SocketService.instance.disconnect();
    await Session.instance.clear();
  }

  /// Force logout (global 401 handler) — no network call, just teardown.
  Future<void> forceLogout() async {
    SocketService.instance.disconnect();
    await Session.instance.clear();
  }
}
