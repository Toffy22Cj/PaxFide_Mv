import 'package:flutter/material.dart';

import '../features/auth/data/session_controller.dart';
import '../features/auth/domain/session_state.dart';
import '../shared/widgets/state_views.dart';
import 'app_routes.dart';
import 'session_guard.dart';

/// Construye la pantalla de una ruta aprobada a partir de su match.
typedef ScreenBuilder = Widget Function(BuildContext context, RouteMatch match);

/// Router de la app (ADR-043 D8).
///
/// Toda navegación por nombre pasa por aquí:
///   nombre → [AppRoutes.match] → [RouteGate] → [SessionGuard] → pantalla.
/// Las pantallas no navegan entre login y home por su cuenta: cambian la
/// sesión y el guard decide (invariante 6: el guard reacciona solo a
/// cambios de [SessionState]).
class AppRouter {
  final SessionController session;
  final SessionGuard guard;

  /// Pantallas implementadas, por patrón del árbol (p. ej. `/assets/:assetRef`).
  /// Una ruta aprobada sin entrada aquí muestra [UnavailableScreenView].
  final Map<String, ScreenBuilder> screens;

  const AppRouter({
    required this.session,
    required this.screens,
    this.guard = const SessionGuard(),
  });

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? AppRoutes.home;
    final match = AppRoutes.match(name);
    return MaterialPageRoute<void>(
      settings: RouteSettings(
        name: match.isApproved ? match.path : name,
        arguments: settings.arguments,
      ),
      builder: (_) => RouteGate(router: this, match: match),
    );
  }

  /// Arranque: una sola ruta inicial, sin apilar '/' debajo.
  List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) =>
      [onGenerateRoute(RouteSettings(name: initialRoute))];
}

/// Aplica la decisión del guard a una ruta concreta y la reevalúa en cada
/// emisión de [SessionState].
class RouteGate extends StatefulWidget {
  final AppRouter router;
  final RouteMatch match;

  const RouteGate({super.key, required this.router, required this.match});

  @override
  State<RouteGate> createState() => _RouteGateState();
}

class _RouteGateState extends State<RouteGate> {
  String? _scheduledRedirect;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionState>(
      valueListenable: widget.router.session,
      builder: (context, session, _) {
        final decision = widget.router.guard.evaluate(
          session: session,
          category: widget.match.category,
        );

        switch (decision.type) {
          case GuardDecisionType.allow:
            _scheduledRedirect = null;
            final builder = widget.router.screens[widget.match.pattern];
            if (builder == null) {
              return UnavailableScreenView(path: widget.match.path);
            }
            return builder(context, widget.match);
          case GuardDecisionType.wait:
            _scheduledRedirect = null;
            return const SessionWaitingView();
          case GuardDecisionType.redirect:
            _scheduleRedirect(context, decision.redirectRoute ?? AppRoutes.home);
            return const SessionWaitingView();
        }
      },
    );
  }

  /// Redirige una sola vez por decisión, y solo si esta ruta es la visible.
  /// Limpia toda la pila: al pasar a LOGGED_OUT ninguna ruta autenticada
  /// queda debajo (invariante 4). No toca el Outbox (A1).
  void _scheduleRedirect(BuildContext context, String target) {
    if (_scheduledRedirect == target) return;
    _scheduledRedirect = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) {
        _scheduledRedirect = null;
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(target, (_) => false);
    });
  }
}
