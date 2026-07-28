import 'package:equatable/equatable.dart';
import '../../../../core/failure.dart';
import '../../../../core/unset.dart';
import '../../data/models/rider.dart';

enum SessionRestoreStatus { unknown, restoring, restored, failed }

class AuthState extends Equatable {
  final bool isLoading;
  final Failure? failure;
  final Rider? rider;
  final bool isAuthenticated;
  final SessionRestoreStatus sessionRestoreStatus;

  // Login flow
  final String? pendingPhone;
  final String? devCode; // dev/staging only — never populated in prod
  final int otpExpiresIn;
  final int otpCountdown;
  final int resendCooldown;

  const AuthState({
    this.isLoading = false,
    this.failure,
    this.rider,
    this.isAuthenticated = false,
    this.sessionRestoreStatus = SessionRestoreStatus.unknown,
    this.pendingPhone,
    this.devCode,
    this.otpExpiresIn = 300,
    this.otpCountdown = 0,
    this.resendCooldown = 0,
  });

  bool get canResend => resendCooldown <= 0;

  AuthState copyWith({
    bool? isLoading,
    Object? failure = unset,
    Object? rider = unset,
    bool? isAuthenticated,
    SessionRestoreStatus? sessionRestoreStatus,
    Object? pendingPhone = unset,
    Object? devCode = unset,
    int? otpExpiresIn,
    int? otpCountdown,
    int? resendCooldown,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      failure: identical(failure, unset) ? this.failure : failure as Failure?,
      rider: identical(rider, unset) ? this.rider : rider as Rider?,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      sessionRestoreStatus: sessionRestoreStatus ?? this.sessionRestoreStatus,
      pendingPhone: identical(pendingPhone, unset)
          ? this.pendingPhone
          : pendingPhone as String?,
      devCode: identical(devCode, unset) ? this.devCode : devCode as String?,
      otpExpiresIn: otpExpiresIn ?? this.otpExpiresIn,
      otpCountdown: otpCountdown ?? this.otpCountdown,
      resendCooldown: resendCooldown ?? this.resendCooldown,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        failure,
        rider,
        isAuthenticated,
        sessionRestoreStatus,
        pendingPhone,
        devCode,
        otpExpiresIn,
        otpCountdown,
        resendCooldown,
      ];
}
