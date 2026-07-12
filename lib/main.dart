import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'core/api_client.dart';
import 'core/socket_service.dart';
import 'state/auth_state.dart';
import 'state/online_state.dart';
import 'state/active_order_state.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/phone_password_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/job/reached_store_screen.dart';
import 'screens/job/delivery_screen.dart';
import 'screens/job/payment_qr_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/profile/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize API client singleton.
  ApiClient.instance.init();

  runApp(const GksRiderApp());
}

class GksRiderApp extends StatefulWidget {
  const GksRiderApp({super.key});

  @override
  State<GksRiderApp> createState() => _GksRiderAppState();
}

class _GksRiderAppState extends State<GksRiderApp> {
  late final AuthState _authState;
  late final OnlineState _onlineState;
  late final ActiveOrderState _activeOrderState;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authState = AuthState();
    _onlineState = OnlineState();
    _activeOrderState = ActiveOrderState();

    // Wire up global 401 handler — force logout and route to login.
    ApiClient.instance.onUnauthorized = () {
      _authState.forceLogout();
      _onlineState.setOnlineStatus(false);
      _activeOrderState.clear();
      _router.go('/login');
    };

    // Wire up socket auth error → same behavior as REST 401.
    SocketService.instance.onAuthError.listen((_) {
      ApiClient.instance.onUnauthorized?.call();
    });

    _router = _buildRouter();
  }

  @override
  void dispose() {
    _authState.dispose();
    _onlineState.dispose();
    _activeOrderState.dispose();
    SocketService.instance.dispose();
    super.dispose();
  }

  GoRouter _buildRouter() {
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
          builder: (_, __) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const ProfileScreen(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authState),
        ChangeNotifierProvider.value(value: _onlineState),
        ChangeNotifierProvider.value(value: _activeOrderState),
      ],
      child: MaterialApp.router(
        title: 'GKS Rider',
        debugShowCheckedModeBanner: false,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFF6C63FF),
      scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F6FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Color(0xFF1A1A2E),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
      ),
      textTheme: const TextTheme(
        bodySmall: TextStyle(color: Color(0xFF555555)),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF6C63FF),
      scaffoldBackgroundColor: const Color(0xFF0F0C29),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F0C29),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A2E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A1A2E),
        elevation: 8,
      ),
    );
  }
}
