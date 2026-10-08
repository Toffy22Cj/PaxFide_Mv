import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/app/session_guard.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';

/// Tabla normativa de front-fase1.md §10 / ADR-043 D8, celda por celda.
void main() {
  const guard = SessionGuard();

  GuardDecision eval(SessionState s, RouteCategory c) =>
      guard.evaluate(session: s, category: c);

  void expectAllow(GuardDecision d) {
    expect(d.type, GuardDecisionType.allow);
    expect(d.redirectRoute, isNull);
  }

  void expectWait(GuardDecision d) {
    expect(d.type, GuardDecisionType.wait);
    expect(d.redirectRoute, isNull);
  }

  void expectRedirect(GuardDecision d, String to) {
    expect(d.type, GuardDecisionType.redirect);
    expect(d.redirectRoute, to);
  }

  for (final waiting in const [SessionState.unknown(), SessionState.restoring()]) {
    group('${waiting.status}', () {
      test('pública → permitir (las públicas no esperan sesión)', () {
        expectAllow(eval(waiting, RouteCategory.public));
      });
      test('/login → esperar', () {
        expectWait(eval(waiting, RouteCategory.authTransitory));
      });
      test('autenticada → esperar', () {
        expectWait(eval(waiting, RouteCategory.authenticated));
      });
      test('no aprobada → esperar (fallback al resolver sesión)', () {
        expectWait(eval(waiting, RouteCategory.notApproved));
      });
    });
  }

  group('AUTHENTICATED', () {
    const s = SessionState.authenticated();
    test('pública → permitir', () => expectAllow(eval(s, RouteCategory.public)));
    test('/login → /home', () => expectRedirect(eval(s, RouteCategory.authTransitory), AppRoutes.home));
    test('autenticada → permitir', () => expectAllow(eval(s, RouteCategory.authenticated)));
    test('no aprobada → /home', () => expectRedirect(eval(s, RouteCategory.notApproved), AppRoutes.home));
  });

  group('LOGGED_OUT', () {
    const s = SessionState.loggedOut();
    test('pública → permitir', () => expectAllow(eval(s, RouteCategory.public)));
    test('/login → permitir', () => expectAllow(eval(s, RouteCategory.authTransitory)));
    test('autenticada → /login (Decisión B)', () => expectRedirect(eval(s, RouteCategory.authenticated), AppRoutes.login));
    test('no aprobada → /login', () => expectRedirect(eval(s, RouteCategory.notApproved), AppRoutes.login));
  });

  group('invariantes', () {
    const all = [
      SessionState.unknown(),
      SessionState.restoring(),
      SessionState.authenticated(),
      SessionState.loggedOut(),
    ];

    test('NEGATIVA: una ruta pública nunca espera ni redirige, en ningún estado', () {
      for (final s in all) {
        expectAllow(eval(s, RouteCategory.public));
      }
    });

    test('idempotencia sin bucles: el destino de cada redirect está permitido', () {
      for (final s in all) {
        for (final c in RouteCategory.values) {
          final d = eval(s, c);
          if (d.type != GuardDecisionType.redirect) continue;
          final target = AppRoutes.categorize(d.redirectRoute!);
          expect(eval(s, target).type, GuardDecisionType.allow,
              reason: '$s + $c → ${d.redirectRoute} debe ser destino permitido');
        }
      }
    });
  });
}
