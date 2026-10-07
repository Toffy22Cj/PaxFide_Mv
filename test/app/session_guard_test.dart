import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/app/session_guard.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';

/// Tabla normativa de front-fase1.md §10 (ADR-043 D8): 4 estados × 4 categorías.
void main() {
  const guard = SessionGuard();

  GuardDecision eval(SessionState s, RouteCategory c) => guard.evaluate(session: s, category: c);

  group('tabla de decisión §10', () {
    final waiting = [const SessionState.unknown(), const SessionState.restoring()];

    for (final s in waiting) {
      test('${s.status}: pública → permitir (no espera sesión)', () {
        expect(eval(s, RouteCategory.public).type, GuardDecisionType.allow);
      });
      test('${s.status}: /login → esperar', () {
        expect(eval(s, RouteCategory.authTransitory).type, GuardDecisionType.wait);
      });
      test('${s.status}: autenticada → esperar', () {
        expect(eval(s, RouteCategory.authenticated).type, GuardDecisionType.wait);
      });
      test('${s.status}: no aprobada → esperar (fallback al resolver)', () {
        expect(eval(s, RouteCategory.notApproved).type, GuardDecisionType.wait);
      });
    }

    test('AUTHENTICATED: pública y autenticada → permitir', () {
      const s = SessionState.authenticated();
      expect(eval(s, RouteCategory.public).type, GuardDecisionType.allow);
      expect(eval(s, RouteCategory.authenticated).type, GuardDecisionType.allow);
    });

    test('AUTHENTICATED: /login y no aprobada → /home', () {
      const s = SessionState.authenticated();
      for (final c in [RouteCategory.authTransitory, RouteCategory.notApproved]) {
        final d = eval(s, c);
        expect(d.type, GuardDecisionType.redirect);
        expect(d.redirectRoute, AppRoutes.home);
      }
    });

    test('LOGGED_OUT: pública y /login → permitir', () {
      const s = SessionState.loggedOut();
      expect(eval(s, RouteCategory.public).type, GuardDecisionType.allow);
      expect(eval(s, RouteCategory.authTransitory).type, GuardDecisionType.allow);
    });

    test('LOGGED_OUT: autenticada y no aprobada → /login', () {
      const s = SessionState.loggedOut();
      for (final c in [RouteCategory.authenticated, RouteCategory.notApproved]) {
        final d = eval(s, c);
        expect(d.type, GuardDecisionType.redirect);
        expect(d.redirectRoute, AppRoutes.login);
      }
    });
  });

  group('invariantes', () {
    test('idempotencia: el destino de un redirect siempre se permite (sin bucles)', () {
      for (final s in [const SessionState.authenticated(), const SessionState.loggedOut()]) {
        for (final c in RouteCategory.values) {
          final d = eval(s, c);
          if (d.type == GuardDecisionType.redirect) {
            final second = eval(s, AppRoutes.categorize(d.redirectRoute!));
            expect(second.type, GuardDecisionType.allow, reason: '$s → ${d.redirectRoute} debe permitirse');
          }
        }
      }
    });

    test('negativa: una ruta pública nunca espera ni se redirige', () {
      for (final s in [
        const SessionState.unknown(),
        const SessionState.restoring(),
        const SessionState.authenticated(),
        const SessionState.loggedOut(),
      ]) {
        expect(eval(s, RouteCategory.public).type, GuardDecisionType.allow);
      }
    });

    test('negativa: /campaigns nunca se permite en ningún estado de sesión', () {
      final c = AppRoutes.categorize('/campaigns');
      expect(c, RouteCategory.notApproved);
      for (final s in [
        const SessionState.unknown(),
        const SessionState.restoring(),
        const SessionState.authenticated(),
        const SessionState.loggedOut(),
      ]) {
        expect(eval(s, c).type, isNot(GuardDecisionType.allow));
      }
    });

    test('/register se comporta como /login (transitoria de auth)', () {
      expect(AppRoutes.categorize(AppRoutes.register), RouteCategory.authTransitory);
    });
  });
}
