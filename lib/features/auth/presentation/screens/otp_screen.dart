import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/env.dart';
import '../../../../widgets/error_banner.dart';
import '../../../../widgets/loading_overlay.dart';
import '../../../dashboard/presentation/bloc/online_bloc.dart';
import '../../../dashboard/presentation/bloc/online_event.dart';
import '../../../order/presentation/bloc/order_bloc.dart';
import '../../../order/presentation/bloc/order_event.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

const _cardGrey = Color(0xFFD9D9D9);

/// OTP verification screen — 6-digit code entry with countdown and resend.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    // Auto-fill devCode in dev builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Env.isDev) {
        final devCode = context.read<AuthBloc>().state.devCode;
        if (devCode != null && devCode.length == 6) {
          for (int i = 0; i < 6; i++) {
            _controllers[i].text = devCode[i];
          }
        }
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _verify() {
    final code = _code;
    if (code.length != 6) {
      showErrorSnackBar(context, 'Enter the full 6-digit code');
      return;
    }
    context.read<AuthBloc>().add(AuthOtpVerified(code));
  }

  void _onVerifySucceeded(BuildContext context, AuthState state) {
    // Initialize order state and socket listeners.
    final orderBloc = context.read<OrderBloc>();
    orderBloc.add(const OrderSocketListenRequested());
    orderBloc.add(const OrderActiveRequested());

    // Check rider's online status.
    final rider = state.rider;
    final onlineBloc = context.read<OnlineBloc>();
    if (rider != null &&
        rider.availabilityStatus != null &&
        rider.availabilityStatus != 'offline') {
      onlineBloc.add(const OnlineStatusChanged(true));
    }
    onlineBloc.add(const OnlineSummaryRequested());

    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.isLoading && !current.isLoading,
      listener: (context, state) {
        if (state.failure != null) {
          showErrorSnackBar(context, state.failure!.message);
        } else if (state.isAuthenticated) {
          _onVerifySucceeded(context, state);
        }
      },
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            current.resendCooldown > previous.resendCooldown,
        listener: (context, state) {
          showSuccessSnackBar(context, 'OTP resent!');
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, auth) {
            return Scaffold(
              backgroundColor: Colors.white,
              body: LoadingOverlay(
                isLoading: auth.isLoading,
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Back button
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.black,
                                size: 20,
                              ),
                              onPressed: () => context.go('/login'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.mail_outline_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Verify OTP',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter the 6-digit code sent to your email',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // OTP fields
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (i) => _otpBox(i)),
                          ),
                          const SizedBox(height: 24),

                          // Countdown
                          if (auth.otpCountdown > 0)
                            Text(
                              'Code expires in ${_formatTime(auth.otpCountdown)}',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(height: 12),

                          // Resend
                          TextButton(
                            onPressed: auth.canResend && !auth.isLoading
                                ? () => context
                                    .read<AuthBloc>()
                                    .add(const AuthResendOtpRequested())
                                : null,
                            child: Text(
                              auth.canResend
                                  ? 'Resend Code'
                                  : 'Resend in ${auth.resendCooldown}s',
                              style: TextStyle(
                                color: auth.canResend
                                    ? Colors.black
                                    : Colors.black26,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Verify button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _verify,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Verify',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          // Dev-only devCode hint
                          if (Env.isDev && auth.devCode != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                'DEV CODE: ${auth.devCode}',
                                style: const TextStyle(
                                  color: Color(0xFF9A7000),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return Container(
      width: 44,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: _cardGrey.withValues(alpha: 0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _cardGrey),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          // Auto-verify when all 6 digits are entered.
          if (_code.length == 6) {
            _verify();
          }
        },
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
