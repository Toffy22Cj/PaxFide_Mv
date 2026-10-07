import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';
import 'package:paxfide_mobile/shared/widgets/state_views.dart';

import '../support/app_harness.dart';

/// Flujos completos de front-fase1.md §14 (nivel 3) con backend falso.
void main() {
  testWidgets('arranque sin sesión → /login (sin ruta guardada)', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    expect(h.location, AppRoutes.login);
    expect(find.byKey(const Key('login.submit')), findsOneWidget);
  });

  testWidgets('G-1: arranque en frío con ruta pública guardada → se muestra sin UI de espera', (tester) async {
    final h = AppHarness();
    h.saveNavigation('/c/PUB1', {'publicCode': 'PUB1'});
    await h.start(
      tester,
      beforeSession: () async {
        // Sesión aún sin resolver: la pública ya está y no hay espera.
        expect(h.services.session.state.status, SessionStatus.unknown);
        expect(h.location, '/c/PUB1');
        expect(find.byType(WaitingView), findsNothing);
      },
    );
    expect(h.location, '/c/PUB1');
  });

  testWidgets('ruta autenticada durante RESTORING → UI de espera (no es una ruta)', (tester) async {
    final h = AppHarness();
    h.saveToken('jwt');
    h.saveNavigation('/operator');
    await tester.pumpWidget(const SizedBox());
    await h.start(
      tester,
      beforeSession: () async {
        expect(find.byType(WaitingView), findsOneWidget);
        h.api.enqueue(meResponse());
      },
    );
    expect(h.location, '/operator');
    expect(h.services.router.stack, ['/home', '/operator']);
  });

  testWidgets('R2: deep link a /assets sin sesión → login → llega al activo (consumo único)', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    final link = h.services.deepLinkParser.parse(Uri.parse('$testOrigin/assets/A-9'));
    expect(await h.services.router.openDeepLink(link), isTrue);
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.login);
    expect(h.services.pendingIntents.current?.route, '/assets/A-9');

    // PendingIntent nunca se persiste (ni en NavigationRestoreState ni en ningún store).
    expect(h.secure.values.values.join(), isNot(contains('A-9')));

    await h.login(tester);
    expect(h.location, '/assets/A-9');
    expect(h.services.router.stack, ['/home', '/assets/A-9']);
    expect(h.services.pendingIntents.current, isNull);
  });

  testWidgets('R2: login cancelado → la intención desaparece; tras login → /home', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    // Desde una pública, para poder volver atrás desde /login.
    await h.services.router.openDeepLink(h.services.deepLinkParser.parse(Uri.parse('$testOrigin/c/PUB1')));
    await h.services.router.openDeepLink(h.services.deepLinkParser.parse(Uri.parse('$testOrigin/assets/A-9')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.login);
    h.services.router.back();
    await tester.pumpAndSettle();
    expect(h.services.pendingIntents.current, isNull);
    expect(h.location, '/c/PUB1');
  });

  testWidgets('R2: login fallido → la intención desaparece', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    await h.services.router.openDeepLink(h.services.deepLinkParser.parse(Uri.parse('$testOrigin/assets/A-9')));
    await tester.pumpAndSettle();
    h.api.enqueue(const ApiResponse(statusCode: 401));
    await tester.enterText(find.byKey(const Key('login.email')), 'x@y');
    await tester.enterText(find.byKey(const Key('login.password')), 'mal');
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Email o contraseña incorrectos.'), findsOneWidget);
    expect(h.services.pendingIntents.current, isNull);
  });

  testWidgets('T-1: 401 con JWT → LOGGED_OUT → /login; la pila autenticada desaparece', (tester) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
    expect(h.location, '/assets/A-1');

    h.api.enqueue(const ApiResponse(statusCode: 401));
    try {
      await h.services.authApi.me(); // cualquier petición con JWT que reciba 401
    } catch (_) {}
    await tester.pumpAndSettle();
    expect(h.services.session.state.status, SessionStatus.loggedOut);
    expect(h.location, AppRoutes.login);
    expect(h.services.router.stack.where((l) => AppRoutes.categorize(l) == RouteCategory.authenticated), isEmpty);
    expect(h.secure.values.containsKey('paxfide.session.jwt'), isFalse);
  });

  testWidgets('logout → atrás nunca vuelve a /assets (invariante 4)', (tester) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
    await h.services.session.logout();
    await tester.pumpAndSettle();
    expect(h.services.router.stack, [AppRoutes.login]);
    h.services.router.back();
    await tester.pumpAndSettle();
    expect(h.location, isNot('/assets/A-1'));
  });

  testWidgets('Decisión B: ruta autenticada guardada sin sesión → /login → /home (no al recurso)', (tester) async {
    final h = AppHarness();
    h.saveNavigation('/assets/A-1', {'assetRef': 'A-1'});
    await h.start(tester);
    expect(h.location, AppRoutes.login);
    await h.login(tester);
    expect(h.location, AppRoutes.home);
  });

  testWidgets('restauración de ruta autenticada con sesión válida', (tester) async {
    final h = AppHarness();
    h.saveToken('jwt');
    h.saveNavigation('/assets/A-1', {'assetRef': 'A-1'});
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    expect(h.services.router.stack, ['/home', '/assets/A-1']);
  });

  testWidgets('R4: deep link fresco + NavigationRestoreState en arranque en frío → gana el deep link', (tester) async {
    final h = AppHarness();
    h.saveToken('jwt');
    h.saveNavigation('/operator');
    await h.start(
      tester,
      beforeSession: () async {
        h.api.enqueue(meResponse());
        await h.services.router.openDeepLink(h.services.deepLinkParser.parse(Uri.parse('$testOrigin/assets/A-7')));
      },
    );
    expect(h.location, '/assets/A-7');
    expect(h.services.router.stack, isNot(contains('/operator')));
  });

  testWidgets('estado de navegación corrupto → se descarta → fallback', (tester) async {
    final h = AppHarness();
    h.secure.values['paxfide.navigation.restore'] = '{corrupto';
    await h.start(tester);
    expect(h.location, AppRoutes.login);
    expect(h.secure.values.containsKey('paxfide.navigation.restore'), isFalse);
  });

  testWidgets('deep link no aprobado → no navega', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    final ok = await h.services.router.openDeepLink(
      h.services.deepLinkParser.parse(Uri.parse('https://otro.example/assets/A-1')),
    );
    expect(ok, isFalse);
    expect(h.location, AppRoutes.login);
  });

  testWidgets('el seguimiento por QR abre /tracking sin el código; nada lo guarda', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    await h.services.router.openDeepLink(h.services.deepLinkParser.parse(Uri.parse('$testOrigin/tracking/SECRETO')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.tracking);
    expect(h.secure.values.values.join(), isNot(contains('SECRETO')));
    expect(h.services.router.stack.join(), isNot(contains('SECRETO')));
  });

  testWidgets('/register: crear cuenta no inicia sesión', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.register);
    h.api.enqueue(const ApiResponse(statusCode: 201, data: {'accountId': 'acc-9', 'status': 'ACTIVE'}));
    await tester.enterText(find.byKey(const Key('register.email')), 'nuevo@demo');
    await tester.enterText(find.byKey(const Key('register.password')), 'pw');
    await tester.tap(find.byKey(const Key('register.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Cuenta creada'), findsOneWidget);
    expect(h.services.session.state.status, SessionStatus.loggedOut);
    expect(h.api.calls.last.path, '/auth/register');
    expect(h.api.calls.last.headers.containsKey('Command-Id'), isFalse);
  });

  testWidgets('/register: email repetido → 409 con mensaje propio', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.services.router.push(AppRoutes.register);
    await tester.pumpAndSettle();
    h.api.enqueue(const ApiResponse(statusCode: 409));
    await tester.enterText(find.byKey(const Key('register.email')), 'ya@demo');
    await tester.enterText(find.byKey(const Key('register.password')), 'pw');
    await tester.tap(find.byKey(const Key('register.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Ya existe una cuenta con ese email.'), findsOneWidget);
  });

  testWidgets('inicio: Operaciones solo para EMPLOYEE; Predicción solo para ADMINISTRATOR/REPRESENTATIVE', (
    tester,
  ) async {
    final h = AppHarness();
    await h.start(tester);
    await h.login(tester, roles: const []);
    expect(find.text('Operaciones'), findsNothing);
    expect(find.text('Predicción'), findsNothing);
    await h.services.session.logout();
    await tester.pumpAndSettle();
    await h.login(tester, roles: const ['ADMINISTRATOR']);
    expect(find.text('Operaciones'), findsNothing);
    expect(find.text('Predicción'), findsWidgets);
    await h.services.session.logout();
    await tester.pumpAndSettle();
    await h.login(tester, roles: const ['EMPLOYEE']);
    expect(find.text('Operaciones'), findsWidgets);
  });
}
