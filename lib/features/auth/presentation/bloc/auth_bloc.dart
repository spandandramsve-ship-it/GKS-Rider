import 'dart:async';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/env.dart';
import '../../../../core/api_client.dart';
import '../../../../core/failure.dart';
import '../../data/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;

  Timer? _otpTimer;
  Timer? _resendTimer;

  AuthBloc({AuthRepository? repository})
      : _repository = repository ?? AuthRepository(),
        super(const AuthState()) {
    on<AuthSessionRestoreRequested>(_onSessionRestoreRequested);
    on<AuthLoginRequested>(_onLoginRequested, transformer: droppable());
    on<AuthResendOtpRequested>(_onResendOtpRequested, transformer: droppable());
    on<AuthOtpVerified>(_onOtpVerified, transformer: droppable());
    on<AuthProfileRefreshRequested>(_onProfileRefreshRequested);
    on<AuthLoggedOut>(_onLoggedOut, transformer: droppable());
    on<AuthForceLoggedOut>(_onForceLoggedOut, transformer: droppable());
    on<AuthErrorCleared>((event, emit) => emit(state.copyWith(failure: null)));
    on<AuthOtpCountdownTicked>(_onOtpCountdownTicked);
    on<AuthResendCooldownTicked>(_onResendCooldownTicked);
  }

  Future<void> _onSessionRestoreRequested(
    AuthSessionRestoreRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(sessionRestoreStatus: SessionRestoreStatus.restoring));
    final rider = await _repository.restoreSession();
    if (rider != null) {
      emit(state.copyWith(
        rider: rider,
        isAuthenticated: true,
        sessionRestoreStatus: SessionRestoreStatus.restored,
      ));
    } else {
      emit(state.copyWith(
        isAuthenticated: false,
        sessionRestoreStatus: SessionRestoreStatus.failed,
      ));
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, failure: null));
    try {
      final result = await _repository.login(event.phone, event.password);
      emit(state.copyWith(
        isLoading: false,
        pendingPhone: result.phone.isNotEmpty ? result.phone : event.phone,
        devCode: Env.isDev ? result.devCode : null,
        otpExpiresIn: result.expiresInSeconds,
        otpCountdown: result.expiresInSeconds,
        resendCooldown: 30,
      ));
      _startOtpCountdown();
      _startResendCooldown();
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        failure: Failure(extractApiException(e).message),
      ));
    }
  }

  Future<void> _onResendOtpRequested(
    AuthResendOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!state.canResend || state.pendingPhone == null) return;
    emit(state.copyWith(isLoading: true, failure: null));
    try {
      await _repository.resendOtp(state.pendingPhone!);
      emit(state.copyWith(
        isLoading: false,
        resendCooldown: 30,
        otpCountdown: state.otpExpiresIn,
      ));
      _startResendCooldown();
      _startOtpCountdown();
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        failure: Failure(extractApiException(e).message),
      ));
    }
  }

  Future<void> _onOtpVerified(
    AuthOtpVerified event,
    Emitter<AuthState> emit,
  ) async {
    if (state.pendingPhone == null) return;
    emit(state.copyWith(isLoading: true, failure: null));
    try {
      final result =
          await _repository.verifyOtp(state.pendingPhone!, event.code);
      _cancelTimers();
      emit(state.copyWith(
        isLoading: false,
        rider: result.rider,
        isAuthenticated: true,
      ));
    } catch (e) {
      final apiErr = extractApiException(e);
      final message = apiErr.statusCode == 403
          ? 'Your account is disabled — contact the admin.'
          : apiErr.message;
      emit(state.copyWith(isLoading: false, failure: Failure(message)));
    }
  }

  Future<void> _onProfileRefreshRequested(
    AuthProfileRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final rider = await _repository.refreshProfile();
      emit(state.copyWith(rider: rider));
    } catch (_) {
      // Silent — a stale cached profile is fine; the next successful
      // refresh will correct it.
    }
  }

  Future<void> _onLoggedOut(
    AuthLoggedOut event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    _cancelTimers();
    emit(const AuthState());
  }

  Future<void> _onForceLoggedOut(
    AuthForceLoggedOut event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.forceLogout();
    _cancelTimers();
    emit(const AuthState());
  }

  void _onOtpCountdownTicked(
    AuthOtpCountdownTicked event,
    Emitter<AuthState> emit,
  ) {
    final next = state.otpCountdown - 1;
    if (next <= 0) _otpTimer?.cancel();
    emit(state.copyWith(otpCountdown: next < 0 ? 0 : next));
  }

  void _onResendCooldownTicked(
    AuthResendCooldownTicked event,
    Emitter<AuthState> emit,
  ) {
    final next = state.resendCooldown - 1;
    if (next <= 0) _resendTimer?.cancel();
    emit(state.copyWith(resendCooldown: next < 0 ? 0 : next));
  }

  void _startOtpCountdown() {
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) add(const AuthOtpCountdownTicked());
    });
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) add(const AuthResendCooldownTicked());
    });
  }

  void _cancelTimers() {
    _otpTimer?.cancel();
    _resendTimer?.cancel();
  }

  @override
  Future<void> close() {
    _cancelTimers();
    return super.close();
  }
}
