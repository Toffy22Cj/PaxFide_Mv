import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/paxfide_app.dart';
import 'package:paxfide_mobile/features/auth/data/login_gateway.dart';
import 'package:paxfide_mobile/features/auth/data/session_controller.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';
import 'package:paxfide_mobile/shared/widgets/state_views.dart';

import '../support/fakes.dart';

/// Flujos de navegación con dobles (nivel 3 de la estrategia de tests de
/// front-fase1.md §14, sin backend real).
void main() {
  Future<SessionController> pumpApp(
    WidgetTester tester, {
    String? token,
    LoginResult loginResult = const LoginUnavailable(),
    String initialRoute = '/home',
    bool restore = true,
  }) async {
    final session = SessionController(tokenStore: FakeTokenStore(token: token));
    await tester.pumpWidget(PaxFideApp(
      session: session,
      loginGateway: FakeLoginGateway(loginResult),
      initialRoute: initialRoute,
    ));
    if (restore) {
      await session.restore();
      await tester.pumpAndSettle();
    } else {
      // La UI de espera anima indefinidamente: no se puede "asentar".
      await tester.pump();
    }
    return session;
  }

  Future<void> fillLogin(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('login-email')), 'ana@correo.co');
    await tester.enterText(find.byKey(const Key('login-password')), 'secreta');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('UNKNOWN: una ruta autenticada muestra la UI de espera, no el login', (tester) async {
    await pumpApp(tester, restore: false);
    expect(find.byType(SessionWaitingView), findsOneWidget);
    expect(find.byKey(const Key('login-submit')), findsNothing);
  });

  testWidgets('NEGATIVA: una ruta pública no espera sesión durante UNKNOWN', (tester) async {
    await pumpApp(tester, restore: false, initialRoute: '/c/PUB-1');
    expect(find.byType(SessionWaitingView), findsNothing);
    // La pantalla pública aún no existe en esta build.
    expect(find.byKey(const Key('unavailable-screen')), findsOneWidget);
  });

  testWidgets('sin token: /home → /login (Decisión B)', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
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

  testWidgets('login correcto: el guard lleva a /home sin que el login navegue', (tester) async {
    final session = await pumpApp(tester, loginResult: const LoginSucceeded('jwt'));
    await fillLogin(tester);
    expect(session.value, const SessionState.authenticated());
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.byKey(const Key('home-entry-donations')), findsOneWidget);
    expect(find.byKey(const Key('home-entry-operator')), findsOneWidget);
  });

  testWidgets('NEGATIVA: la Home no ofrece donar ni muestra datos de campañas', (tester) async {
    await pumpApp(tester, token: 't');
    expect(find.textContaining('Aportar'), findsNothing);
    expect(find.textContaining('Donar'), findsNothing);
    expect(find.textContaining('fiduciari'), findsNothing);
    expect(find.textContaining('COP'), findsNothing);
  });

  testWidgets('logout: vuelve a /login y no queda Home en la pila', (tester) async {
    final session = await pumpApp(tester, token: 't');
    await tester.tap(find.byKey(const Key('home-entry-donations')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unavailable-screen')), findsOneWidget);

    await session.logout();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('T-1 desde cualquier pantalla autenticada lleva a /login', (tester) async {
    final session = await pumpApp(tester, token: 't');
    session.markLoggedOutByUnauthorized();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
  });

  testWidgets('autenticado: /login redirige a /home', (tester) async {
    await pumpApp(tester, token: 't', initialRoute: '/login');
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.byKey(const Key('login-submit')), findsNothing);
  });

  testWidgets('NEGATIVA: /campaigns no es ruta de v1 → fallback según sesión', (tester) async {
    await pumpApp(tester, token: 't', initialRoute: '/campaigns');
    expect(find.text('Inicio'), findsOneWidget);
  });
}
