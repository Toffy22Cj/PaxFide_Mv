import 'package:flutter/material.dart';

import '../features/auth/data/login_gateway.dart';
import '../features/auth/data/session_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';
import 'app_router.dart';
import 'app_routes.dart';

/// Raíz de la app. Recibe sus dependencias para poder probarla con dobles.
class PaxFideApp extends StatefulWidget {
  final SessionController session;
  final LoginGateway loginGateway;

  /// Ruta de arranque. Sin deep link ni estado restaurado, `/home`: el guard
  /// la deja esperar durante RESTORING y la manda a `/login` si no hay sesión.
  final String initialRoute;

  const PaxFideApp({
    super.key,
    required this.session,
    required this.loginGateway,
    this.initialRoute = AppRoutes.home,
  });

  @override
  State<PaxFideApp> createState() => _PaxFideAppState();
}

class _PaxFideAppState extends State<PaxFideApp> {
  late final AppRouter _router = AppRouter(
    session: widget.session,
    screens: {
      AppRoutes.login: (context, match) => LoginScreen(
            loginGateway: widget.loginGateway,
            session: widget.session,
          ),
      AppRoutes.home: (context, match) => HomeScreen(session: widget.session),
    },
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaxFide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
      ),
      initialRoute: widget.initialRoute,
      onGenerateInitialRoutes: _router.onGenerateInitialRoutes,
      onGenerateRoute: _router.onGenerateRoute,
    );
  }
}