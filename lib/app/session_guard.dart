import '../features/auth/domain/session_state.dart';
import 'app_routes.dart';

/// Resultado de la evaluación del guard de sesión (ADR-043 D8).
enum GuardDecisionType {
  allow,
  redirect,
  wait,
}

class GuardDecision {
  final GuardDecisionType type;
  final String? redirectRoute;

  const GuardDecision.allow()
      : type = GuardDecisionType.allow,
        redirectRoute = null;

  const GuardDecision.redirect(this.redirectRoute)
      : type = GuardDecisionType.redirect;

  const GuardDecision.wait()
      : type = GuardDecisionType.wait,
        redirectRoute = null;
}

/// Guard de sesión estricto (ADR-043 D8, front-fase1.md §10).
/// 
/// Solo conoce SessionState y RouteCategory.
/// Invariante: Nunca consulta roles, Outbox, ni peticiones HTTP.
class SessionGuard {
  const SessionGuard();

  GuardDecision evaluate({
    required SessionState session,
    required RouteCategory category,
  }) {
    switch (session.status) {
      // Fila 1: UNKNOWN / RESTORING
      case SessionStatus.unknown:
      case SessionStatus.restoring:
        switch (category) {
          case RouteCategory.public:
            return const GuardDecision.allow(); // Invariante: públicas no esperan
          case RouteCategory.authTransitory:
          case RouteCategory.authenticated:
          case RouteCategory.notApproved:
            return const GuardDecision.wait();
        }

      // Fila 2: AUTHENTICATED
      case SessionStatus.authenticated:
        switch (category) {
          case RouteCategory.public:
          case RouteCategory.authenticated:
            return const GuardDecision.allow();
          case RouteCategory.authTransitory:
          case RouteCategory.notApproved:
            return const GuardDecision.redirect(AppRoutes.home);
        }

      // Fila 3: LOGGED_OUT
      case SessionStatus.loggedOut:
        switch (category) {
          case RouteCategory.public:
          case RouteCategory.authTransitory:
            return const GuardDecision.allow();
          case RouteCategory.authenticated:
          case RouteCategory.notApproved:
            // Decisión B: descarta destino y manda a login
            return const GuardDecision.redirect(AppRoutes.login);
        }
    }
  }
}