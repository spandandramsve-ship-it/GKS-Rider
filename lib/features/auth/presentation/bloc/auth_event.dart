import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Try to restore a session from secure storage — fired once at app start.
class AuthSessionRestoreRequested extends AuthEvent {
  const AuthSessionRestoreRequested();
}

class AuthLoginRequested extends AuthEvent {
  final String phone;
  final String password;

  const AuthLoginRequested(this.phone, this.password);

  @override
  List<Object?> get props => [phone, password];
}

class AuthResendOtpRequested extends AuthEvent {
  const AuthResendOtpRequested();
}

class AuthOtpVerified extends AuthEvent {
  final String code;

  const AuthOtpVerified(this.code);

  @override
  List<Object?> get props => [code];
}

class AuthProfileRefreshRequested extends AuthEvent {
  const AuthProfileRefreshRequested();
}

/// User-initiated logout (Profile screen).
class AuthLoggedOut extends AuthEvent {
  const AuthLoggedOut();
}

/// Global 401 handler — force logout without an API call.
class AuthForceLoggedOut extends AuthEvent {
  const AuthForceLoggedOut();
}

class AuthErrorCleared extends AuthEvent {
  const AuthErrorCleared();
}

/// Internal — one OTP-expiry countdown tick.
class AuthOtpCountdownTicked extends AuthEvent {
  const AuthOtpCountdownTicked();
}

/// Internal — one resend-cooldown tick.
class AuthResendCooldownTicked extends AuthEvent {
  const AuthResendCooldownTicked();
}
