import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../state/active_order_state.dart';
import '../../widgets/error_banner.dart';

/// Payment QR screen — full-screen UPI QR from POST #14, with
/// countdown to expiry and polling GET #15 until canCompleteDelivery.
class PaymentQrScreen extends StatefulWidget {
  const PaymentQrScreen({super.key});

  @override
  State<PaymentQrScreen> createState() => _PaymentQrScreenState();
}

class _PaymentQrScreenState extends State<PaymentQrScreen> {
  Timer? _countdownTimer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQr();
    });
  }

  Future<void> _loadQr() async {
    final orderState = context.read<ActiveOrderState>();
    final ok = await orderState.fetchPaymentQr();
    if (!ok && mounted && orderState.error != null) {
      showErrorSnackBar(context, orderState.error!);
      // If QR unavailable (422), go back.
      if (orderState.error!.contains('unavailable')) {
        if (mounted) context.pop();
      }
      return;
    }

    if (mounted && orderState.paymentQr != null) {
      _startCountdown(orderState.paymentQr!.secondsRemaining);
    }
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    _secondsLeft = seconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveOrderState>(
      builder: (context, orderState, _) {
        // If payment completed, go back to delivery.
        if (orderState.canCompleteDelivery) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              showSuccessSnackBar(context, 'Payment received!');
              context.pop();
            }
          });
        }

        final qr = orderState.paymentQr;

        return Scaffold(
          backgroundColor: const Color(0xFF0F0C29),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              'UPI Payment',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
          ),
          body: Center(
            child: qr == null
                ? const CircularProgressIndicator(color: Colors.white)
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Amount
                        Text(
                          '₹${qr.amountRupees.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Scan to pay via UPI',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // QR Image
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: qr.imageUrl,
                            width: 260,
                            height: 260,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const SizedBox(
                              width: 260,
                              height: 260,
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (_, __, ___) => const SizedBox(
                              width: 260,
                              height: 260,
                              child: Center(
                                child: Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Countdown
                        if (_secondsLeft > 0)
                          Text(
                            'Expires in ${_formatTime(_secondsLeft)}',
                            style: TextStyle(
                              color: _secondsLeft < 60
                                  ? const Color(0xFFE74C3C)
                                  : Colors.white.withValues(alpha: 0.7),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (_secondsLeft <= 0)
                          const Text(
                            'QR expired',
                            style: TextStyle(
                              color: Color(0xFFE74C3C),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Regenerate button
                        OutlinedButton.icon(
                          onPressed: orderState.isLoading
                              ? null
                              : () async {
                                  await orderState.fetchPaymentQr();
                                  if (mounted && orderState.paymentQr != null) {
                                    _startCountdown(
                                      orderState.paymentQr!.secondsRemaining,
                                    );
                                  }
                                },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Regenerate QR'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Polling indicator
                        if (orderState.isPollingPayment)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white54,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Waiting for payment…',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
