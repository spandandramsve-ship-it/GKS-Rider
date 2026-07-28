import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/bloc/auth_event.dart';
import '../features/auth/presentation/bloc/auth_state.dart';
import '../features/dashboard/presentation/bloc/online_bloc.dart';
import '../features/dashboard/presentation/bloc/online_event.dart';
import '../features/order/presentation/bloc/order_bloc.dart';
import '../features/order/presentation/bloc/order_event.dart';

/// Splash screen — checks for a stored JWT, validates it via /me,
/// and routes to Home or Login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();

    // Delay slightly for the animation, then check session.
    Future.delayed(const Duration(milliseconds: 800), _checkSession);
  }

  void _checkSession() {
    if (!mounted) return;
    context.read<AuthBloc>().add(const AuthSessionRestoreRequested());
  }

  void _onSessionRestored(BuildContext context, AuthState state) {
    // Start socket listeners and fetch active order.
    final orderBloc = context.read<OrderBloc>();
    orderBloc.add(const OrderSocketListenRequested());
    orderBloc.add(const OrderActiveRequested());

    // Refresh summary.
    final onlineBloc = context.read<OnlineBloc>();
    final rider = state.rider;
    if (rider != null &&
        rider.availabilityStatus != null &&
        rider.availabilityStatus != 'offline') {
      onlineBloc.add(const OnlineStatusChanged(true));
    }
    onlineBloc.add(const OnlineSummaryRequested());

    context.go('/home');
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.sessionRestoreStatus != current.sessionRestoreStatus,
      listener: (context, state) {
        if (state.sessionRestoreStatus == SessionRestoreStatus.restored) {
          _onSessionRestored(context, state);
        } else if (state.sessionRestoreStatus ==
            SessionRestoreStatus.failed) {
          context.go('/login');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'GKS Rider',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Delivery Partner',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
