import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/auth/data/login_gateway.dart';
import 'package:paxfide_mobile/features/auth/data/me_gateway.dart';
import 'package:paxfide_mobile/features/auth/data/session_controller.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';
import 'package:paxfide_mobile/shared/widgets/state_views.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

/// Flujos de navegación con dobles (nivel 3 de la estrategia de tests de
/// front-fase1.md §14, sin backend real).
void main() {
  Future<SessionController> pumpApp(
    WidgetTester tester, {
    String? token,
    LoginResult loginResult = const LoginUnavailable(),
    MeResult meResult = const MeSucceeded(donor),
    String initialRoute = '/home',
    bool restore = true,
    Size size = const Size(400, 800),
  }) async {
    final h = Harness(token: token, loginResult: loginResult, meResult: meResult);
    await h.pump(tester, initialRoute: initialRoute, restore: restore, size: size);
    return h.session;
  }

  group('sesión y navegación', () {
    testWidgets('UNKNOWN: una ruta autenticada muestra la UI de espera, no el login', (tester) async {
      await pumpApp(tester, restore: false);
      expect(find.byType(SessionWaitingView), findsOneWidget);
      expect(find.byKey(const Key('login-submit')), findsNothing);
    });

    testWidgets('NEGATIVA: una ruta pública no espera sesión durante UNKNOWN', (tester) async {
      await pumpApp(tester, restore: false, initialRoute: '/tracking');
      expect(find.byType(SessionWaitingView), findsNothing);
      expect(find.byKey(const Key('tracking-code')), findsOneWidget);
    });

    testWidgets('sin token: /home → /login (Decisión B)', (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('login-submit')), findsOneWidget);
      expect(find.byKey(const Key('home-section-campaigns')), findsNothing);
    });

    testWidgets('autenticado: /login redirige a /home', (tester) async {
      await pumpApp(tester, token: 't', initialRoute: '/login');
      expect(find.byKey(const Key('home-section-campaigns')), findsOneWidget);
      expect(find.byKey(const Key('login-submit')), findsNothing);
    });

    testWidgets('NEGATIVA: /campaigns no es ruta de v1 → fallback según sesión', (tester) async {
      await pumpApp(tester, token: 't', initialRoute: '/campaigns');
      expect(find.byKey(const Key('home-section-campaigns')), findsOneWidget);
    });

    testWidgets('logout desde la home: vuelve a /login y no queda Home en la pila', (tester) async {
      final session = await pumpApp(tester, token: 't');
      await tester.tap(find.byKey(const Key('home-logout')));
      await tester.pumpAndSettle();

      expect(session.value, const SessionState.loggedOut());
      expect(find.byKey(const Key('login-submit')), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      expect(navigator.canPop(), isFalse);
    });

    testWidgets('T-1 desde cualquier pantalla autenticada lleva a /login', (tester) async {
      final session = await pumpApp(tester, token: 't');
      session.markLoggedOutByUnauthorized();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-submit')), findsOneWidget);
    });
  });

  group('login', () {
    testWidgets('NEGATIVA: no hay selector de rol en el login', (tester) async {
      await pumpApp(tester);
      expect(find.text('Soy Donante'), findsNothing);
      expect(find.text('Organización'), findsNothing);
      expect(find.textContaining('Entrar como'), findsNothing);
    });

    testWidgets('login sin contrato: mensaje explícito y la sesión no cambia', (tester) async {
      final session = await pumpApp(tester);
      await fillLogin(tester);
      expect(find.byKey(const Key('login-unavailable')), findsOneWidget);
      expect(session.value, const SessionState.loggedOut());
    });

    testWidgets('credenciales rechazadas: mensaje propio y la sesión no cambia', (tester) async {
      final session = await pumpApp(tester, loginResult: const LoginRejected());
      await fillLogin(tester);
      expect(find.byKey(const Key('login-error-credentials')), findsOneWidget);
      expect(session.value, const SessionState.loggedOut());
    });

    testWidgets('fallo de red: mensaje propio y la sesión no cambia', (tester) async {
      final session = await pumpApp(tester, loginResult: const LoginNetworkError());
      await fillLogin(tester);
      expect(find.byKey(const Key('login-error-network')), findsOneWidget);
      expect(session.value, const SessionState.loggedOut());
    });

    testWidgets('login correcto: el guard lleva a /home con el rol de /me', (tester) async {
      final session = await pumpApp(
        tester,
        loginResult: const LoginSucceeded('jwt'),
        meResult: const MeSucceeded(fieldOperator),
      );
      await fillLogin(tester);
      expect(session.value, const SessionState.authenticated(principal: fieldOperator));
      expect(find.byKey(const Key('home-section-campaigns')), findsOneWidget);
      expect(find.byKey(const Key('home-nav-operator')), findsOneWidget);
    });

    testWidgets('login correcto pero /me 401: credenciales rechazadas, sin sesión', (tester) async {
      final session = await pumpApp(
        tester,
        loginResult: const LoginSucceeded('jwt'),
        meResult: const MeUnauthorized(),
      );
      await fillLogin(tester);
      expect(session.value, const SessionState.loggedOut());
      expect(find.byKey(const Key('login-error-credentials')), findsOneWidget);
    });
  });

  group('home según el rol de /me', () {
    Future<void> expectSections(
      WidgetTester tester,
      MeResult me, {
      required bool operator,
      required bool prediction,
    }) async {
      await pumpApp(tester, token: 't', meResult: me);
      expect(find.byKey(const Key('home-nav-campaigns')), findsOneWidget);
      expect(find.byKey(const Key('home-nav-donations')), findsOneWidget);
      expect(find.byKey(const Key('home-nav-tracking')), findsOneWidget);
      expect(find.byKey(const Key('home-nav-operator')), operator ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('home-nav-prediction')), prediction ? findsOneWidget : findsNothing);
    }

    testWidgets('donante: sin operaciones ni predicción', (tester) async {
      await expectSections(tester, const MeSucceeded(donor), operator: false, prediction: false);
    });

    testWidgets('EMPLOYEE: con operaciones, sin predicción', (tester) async {
      await expectSections(tester, const MeSucceeded(fieldOperator), operator: true, prediction: false);
    });

    testWidgets('ADMINISTRATOR: con predicción, sin operaciones', (tester) async {
      await expectSections(tester, const MeSucceeded(administrator), operator: false, prediction: true);
    });

    testWidgets('varios roles: la unión', (tester) async {
      await expectSections(tester, const MeSucceeded(operatorAndAdmin), operator: true, prediction: true);
    });

    testWidgets('perfil no cargado: aviso con reintento y solo secciones comunes', (tester) async {
      await expectSections(tester, const MeNetworkError(), operator: false, prediction: false);
      expect(find.byKey(const Key('home-profile-unavailable')), findsOneWidget);
    });

    testWidgets('reintentar el perfil muestra las secciones de su rol', (tester) async {
      final h = Harness(token: 't', meResult: const MeNetworkError());
      await h.pump(tester);
      expect(find.byKey(const Key('home-nav-operator')), findsNothing);

      h.meGateway.result = const MeSucceeded(fieldOperator);
      await tester.tap(find.byKey(const Key('home-profile-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-profile-unavailable')), findsNothing);
      expect(find.byKey(const Key('home-nav-operator')), findsOneWidget);
    });

    testWidgets('escritorio: la barra lateral también depende del rol', (tester) async {
      await pumpApp(tester, token: 't', meResult: const MeSucceeded(donor), size: const Size(1280, 800));
      expect(find.text('Convocatorias'), findsWidgets);
      expect(find.byKey(const Key('home-nav-operator')), findsNothing);
    });

    testWidgets('operaciones pendientes abre /operator/pending', (tester) async {
      await pumpApp(tester, token: 't', meResult: const MeSucceeded(fieldOperator));
      await tester.tap(find.byKey(const Key('home-nav-operator')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-entry-operator-pending')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pending-empty')), findsOneWidget);
      expect(currentRoute(tester), '/operator/pending');
    });

    testWidgets('seguimiento abre /tracking sin código', (tester) async {
      await pumpApp(tester, token: 't');
      await tester.tap(find.byKey(const Key('home-nav-tracking')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-entry-tracking')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tracking-code')), findsOneWidget);
      expect(currentRoute(tester), '/tracking');
    });

    testWidgets('NEGATIVA: la home no muestra el dominio inventado ni datos escritos a mano', (tester) async {
      await pumpApp(tester, token: 't', meResult: const MeSucceeded(operatorAndAdmin));
      for (final section in ['campaigns', 'donations', 'tracking', 'operator', 'prediction']) {
        await tester.tap(find.byKey(Key('home-nav-$section')));
        await tester.pumpAndSettle();
        for (final banned in [
          'scrow',
          'fiduciari',
          'Fiduciari',
          'Retiro',
          'retiro',
          'esembolso',
          'Certificado',
          'PaxNet',
          'Aportar',
          'COP',
          'Kits Escolares',
          'San Juan',
          'Tablero',
          'Auditoría',
          'Finanzas',
          '95%',
        ]) {
          expect(find.textContaining(banned), findsNothing, reason: '"$banned" en $section');
        }
      }
    });
  });
}
