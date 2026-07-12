import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/env.dart';
import '../core/api_client.dart';
import '../core/session.dart';
import '../core/socket_service.dart';

import '../models/rider.dart';
import '../services/auth_service.dart';

/// Manages authentication state: login flow, OTP, session, rider profile.
class AuthState extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // ── State ──────────────────────────────────────────────────────────

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Rider? _rider;
  Rider? get rider => _rider;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  // Login flow
  String? _pendingPhone;
  String? get pendingPhone => _pendingPhone;

  String? _devCode;
  String? get devCode => Env.isDev ? _devCode : null;

  int _otpExpiresIn = 300;
  int get otpExpiresIn => _otpExpiresIn;

  Timer? _otpTimer;
  int _otpCountdown = 0;
  int get otpCountdown => _otpCountdown;

  // Resend cooldown (30 seconds)
  Timer? _resendTimer;
  int _resendCooldown = 0;
  int get resendCooldown => _resendCooldown;
  bool get canResend => _resendCooldown <= 0;

  // ── Session Restore ───────────────────────────────────────────────

  /// Try to restore session from secure storage. Returns `true` if valid.
  Future<bool> tryRestoreSession() async {
    final token = await Session.instance.token;
    if (token == null) return false;

    try {
      _rider = await _authService.me();
      await Session.instance.setRider(_rider!.toJson());
      _isAuthenticated = true;

      // Connect socket with existing token.
      SocketService.instance.connect(token);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AuthState] Session restore failed: $e');
      await Session.instance.clear();
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  // ── Login ──────────────────────────────────────────────────────────

  Future<bool> login(String phone, String password) async {
    _setLoading(true);
    _error = null;

    try {
      final result = await _authService.login(phone, password);
      _pendingPhone = result.phone.isNotEmpty ? result.phone : phone;
      _devCode = result.devCode;
      _otpExpiresIn = result.expiresInSeconds;
      _startOtpCountdown(result.expiresInSeconds);
      _startResendCooldown(30);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = extractApiException(e).message;
      _setLoading(false);
      return false;
    }
  }

  // ── Resend OTP ─────────────────────────────────────────────────────

  Future<bool> resendOtp() async {
    if (!canResend || _pendingPhone == null) return false;
    _setLoading(true);
    _error = null;

    try {
      await _authService.resendOtp(_pendingPhone!);
      _startResendCooldown(30);
      _startOtpCountdown(_otpExpiresIn);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = extractApiException(e).message;
      _setLoading(false);
      return false;
    }
  }

  // ── Verify OTP ─────────────────────────────────────────────────────

  Future<bool> verifyOtp(String code) async {
    if (_pendingPhone == null) return false;
    _setLoading(true);
    _error = null;

    try {
      final result = await _authService.verifyOtp(_pendingPhone!, code);

      // Persist token and rider.
      await Session.instance.setToken(result.token);
      await Session.instance.setRider(result.rider.toJson());
      _rider = result.rider;
      _isAuthenticated = true;

      // Connect socket immediately (before going online).
      SocketService.instance.connect(result.token);

      _cancelTimers();
      _setLoading(false);
      return true;
    } catch (e) {
      final apiErr = extractApiException(e);
      // Special 403 handling for disabled accounts.
      if (apiErr.statusCode == 403) {
        _error = 'Your account is disabled — contact the admin.';
      } else {
        _error = apiErr.message;
      }
      _setLoading(false);
      return false;
    }
  }

  // ── Refresh profile ────────────────────────────────────────────────

  Future<void> refreshProfile() async {
    try {
      _rider = await _authService.me();
      await Session.instance.setRider(_rider!.toJson());
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthState] Profile refresh failed: $e');
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────

  Future<void> logout() async {
    // Try to go offline first (polite, not required).
    try {
      await _authService.goOffline();
    } catch (_) {}

    SocketService.instance.disconnect();
    await Session.instance.clear();

    _rider = null;
    _isAuthenticated = false;
    _pendingPhone = null;
    _devCode = null;
    _error = null;
    _cancelTimers();
    notifyListeners();
  }

  /// Force logout (called by global 401 handler).
  Future<void> forceLogout() async {
    SocketService.instance.disconnect();
    await Session.instance.clear();
    _rider = null;
    _isAuthenticated = false;
    _cancelTimers();
    notifyListeners();
  }

  // ── OTP countdown timer ────────────────────────────────────────────

  void _startOtpCountdown(int seconds) {
    _otpTimer?.cancel();
    _otpCountdown = seconds;
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _otpCountdown--;
      if (_otpCountdown <= 0) {
        t.cancel();
      }
      notifyListeners();
    });
  }

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    _resendCooldown = seconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _resendCooldown--;
      if (_resendCooldown <= 0) {
        t.cancel();
      }
      notifyListeners();
    });
  }

  void _cancelTimers() {
    _otpTimer?.cancel();
    _resendTimer?.cancel();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
