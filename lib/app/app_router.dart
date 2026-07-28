import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/phone_password_screen.dart';
import '../features/dashboard/presentation/screens/home_screen.dart';
import '../features/history/presentation/bloc/history_bloc.dart';
import '../features/history/presentation/screens/history_screen.dart';
import '../features/order/presentation/screens/delivery_screen.dart';
import '../features/order/presentation/screens/payment_qr_screen.dart';
import '../features/order/presentation/screens/reached_store_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import 'splash_screen.dart';

GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const PhonePasswordScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (_, __) => const OtpScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/job/store',
        builder: (_, __) => const ReachedStoreScreen(),
      ),
      GoRoute(
        path: '/job/delivery',
        builder: (_, __) => const DeliveryScreen(),
      ),
      GoRoute(
        path: '/job/payment-qr',
        builder: (_, __) => const PaymentQrScreen(),
      ),
      GoRoute(
        path: '/history',
        // Screen-scoped bloc: tab selection and pagination are disposable
        // UI state, reset fresh each time the screen is opened — unlike
        // Auth/Online/Order, which must persist across the whole session.
        builder: (_, __) => BlocProvider(
          create: (_) => HistoryBloc(),
          child: const HistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
    ],
  );
}
