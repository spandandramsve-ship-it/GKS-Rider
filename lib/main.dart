import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'app/app_router.dart';
import 'app/app_theme.dart';
import 'core/api_client.dart';
import 'core/socket_service.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/dashboard/presentation/bloc/online_bloc.dart';
import 'features/dashboard/presentation/bloc/online_event.dart';
import 'features/order/presentation/bloc/order_bloc.dart';
import 'features/order/presentation/bloc/order_event.dart';

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
  late final AuthBloc _authBloc;
  late final OnlineBloc _onlineBloc;
  late final OrderBloc _orderBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc();
    _onlineBloc = OnlineBloc();
    _orderBloc = OrderBloc();

    // Wire up global 401 handler — force logout and route to login.
    ApiClient.instance.onUnauthorized = () {
      _authBloc.add(const AuthForceLoggedOut());
      _onlineBloc.add(const OnlineStatusChanged(false));
      _orderBloc.add(const OrderCleared());
      _router.go('/login');
    };

    // Wire up socket auth error → same behavior as REST 401.
    SocketService.instance.onAuthError.listen((_) {
      ApiClient.instance.onUnauthorized?.call();
    });

    _router = buildAppRouter();
  }

  @override
  void dispose() {
    _authBloc.close();
    _onlineBloc.close();
    _orderBloc.close();
    SocketService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider.value(value: _onlineBloc),
        BlocProvider.value(value: _orderBloc),
      ],
      child: MaterialApp.router(
        title: 'GKS Rider',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
