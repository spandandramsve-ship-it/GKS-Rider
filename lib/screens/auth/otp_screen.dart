import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../config/env.dart';
import '../../state/auth_state.dart';
import '../../state/active_order_state.dart';
import '../../state/online_state.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_overlay.dart';

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
        final devCode = context.read<AuthState>().devCode;
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

  Future<void> _verify() async {
    final code = _code;
    if (code.length != 6) {
      showErrorSnackBar(context, 'Enter the full 6-digit code');
      return;
    }

    final authState = context.read<AuthState>();
    final success = await authState.verifyOtp(code);

    if (!mounted) return;

    if (success) {
      // Initialize order state and socket listeners.
      final orderState = context.read<ActiveOrderState>();
      orderState.listenToSocket();
      await orderState.fetchActiveOrder();

      // Check rider's online status.
      final rider = authState.rider;
      if (rider != null &&
          rider.availabilityStatus != null &&
          rider.availabilityStatus != 'offline') {
        if (mounted) {
          context.read<OnlineState>().setOnlineStatus(true);
        }
      }

      if (mounted) {
        context.read<OnlineState>().fetchSummary();
        context.go('/home');
      }
    } else if (authState.error != null) {
      showErrorSnackBar(context, authState.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, auth, _) {
        return Scaffold(
          body: LoadingOverlay(
            isLoading: auth.isLoading,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F0C29),
                    Color(0xFF302B63),
                    Color(0xFF24243E),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
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
                              color: Colors.white70,
                              size: 20,
                            ),
                            onPressed: () => context.go('/login'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Icon(
                          Icons.mail_outline_rounded,
                          color: Color(0xFF6C63FF),
                          size: 48,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Verify OTP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the 6-digit code sent to your email',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
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
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Resend
                        TextButton(
                          onPressed: auth.canResend && !auth.isLoading
                              ? () async {
                                  final ok = await auth.resendOtp();
                                  if (context.mounted && ok) {
                                    showSuccessSnackBar(
                                      context,
                                      'OTP resent!',
                                    );
                                  }
                                }
                              : null,
                          child: Text(
                            auth.canResend
                                ? 'Resend Code'
                                : 'Resend in ${auth.resendCooldown}s',
                            style: TextStyle(
                              color: auth.canResend
                                  ? const Color(0xFF6C63FF)
                                  : Colors.white30,
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
                              backgroundColor: const Color(0xFF6C63FF),
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
                                color: Colors.amber,
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
          ),
        );
      },
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
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.15),
            ),
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
