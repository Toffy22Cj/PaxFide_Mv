import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_config.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';
import 'package:paxfide_mobile/features/auth/google/google_id_token_provider.dart';

import '../support/app_harness.dart';

/// ADR-050 D9: entrar con Google y vincularlo o desvincularlo en Cuenta.
final _accountList = find.byType(Scrollable).first;

ApiResponse _problem(int status, String title) =>
    ApiResponse(statusCode: status, data: {'title': title, 'status': status});

void main() {
  Future<void> tapGoogle(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('login.google')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('login.google')));
    await tester.pumpAndSettle();
  }

  test('el ID de cliente web se acepta solo con su forma; si no, no hay Google', () {
    expect(AppConfig.googleClientId(' 123-abc9.apps.googleusercontent.com '), '123-abc9.apps.googleusercontent.com');
    expect(AppConfig.googleClientId(''), isNull);
    expect(AppConfig.googleClientId('mi-cliente'), isNull);
  });

  testWidgets('sin Google configurado no aparece el botón ni las opciones de Cuenta', (tester) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.go(AppRoutes.account);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account.google.link')), findsNothing);
    expect(find.byKey(const Key('account.google.unlink')), findsNothing);
  });

  testWidgets('entrar con Google cambia el idToken por la sesión', (tester) async {
    final google = FakeGoogleIdTokenProvider();
    final h = AppHarness(google: google);
    await h.start(tester);
    h.api.enqueue(const ApiResponse(statusCode: 200, data: {'token': 'jwt-google'}));
    h.api.enqueue(meResponse(roles: const []));
    await tapGoogle(tester);
    expect(google.calls, 1);
    final call = h.api.calls.singleWhere((c) => c.path == '/auth/google');
    expect(call.body, {'idToken': 'google-id-token'});
    expect(h.services.session.state.status, SessionStatus.authenticated);
  });

  testWidgets('cerrar la ventana de Google no hace nada ni llama al backend', (tester) async {
    final google = FakeGoogleIdTokenProvider()..next = const GoogleIdTokenCanceled();
    final h = AppHarness(google: google);
    await h.start(tester);
    await tapGoogle(tester);
    expect(h.api.calls.where((c) => c.path == '/auth/google'), isEmpty);
    expect(find.byKey(const Key('login.error')), findsNothing);
  });

  testWidgets('cuenta de Google no vinculada (401): explica cómo vincularla', (tester) async {
    final h = AppHarness(google: FakeGoogleIdTokenProvider());
    await h.start(tester);
    h.api.routes['POST /auth/google'] = (_) => const ApiResponse(statusCode: 401);
    await tapGoogle(tester);
    expect(find.textContaining('no está vinculada a PaxFide'), findsOneWidget);
    expect(h.services.session.state.status, SessionStatus.loggedOut);
  });

  testWidgets('Google no responde (503): ofrece la contraseña', (tester) async {
    final h = AppHarness(google: FakeGoogleIdTokenProvider());
    await h.start(tester);
    h.api.routes['POST /auth/google'] = (_) => _problem(503, 'GoogleSignInUnavailable');
    await tapGoogle(tester);
    expect(find.textContaining('Google no responde ahora'), findsOneWidget);
  });

  testWidgets('condiciones pendientes: se aceptan y se repite con el mismo idToken', (tester) async {
    final google = FakeGoogleIdTokenProvider();
    final h = AppHarness(google: google);
    await h.start(tester);
    h.api.enqueue(
      const ApiResponse(
        statusCode: 403,
        data: {'title': 'AcceptanceRequired', 'pendingTermsVersion': 't2', 'pendingDataPolicyVersion': 'd2'},
      ),
    );
    h.api.enqueue(const ApiResponse(statusCode: 200, data: {'token': 'jwt-google'}));
    h.api.enqueue(meResponse(roles: const []));
    await tester.ensureVisible(find.byKey(const Key('login.google')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('login.google')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('legal-acceptance.terms')));
    await tester.tap(find.byKey(const Key('legal-acceptance.dataPolicy')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('legal-acceptance.accept')));
    await tester.pumpAndSettle();
    final calls = h.api.calls.where((c) => c.path == '/auth/google').toList();
    expect(calls, hasLength(2));
    expect(calls[1].body, {
      'idToken': 'google-id-token',
      'acceptedTermsVersion': 't2',
      'acceptedDataPolicyVersion': 'd2',
    });
    expect(google.calls, 1);
    expect(h.services.session.state.status, SessionStatus.authenticated);
  });

  Future<AppHarness> account(WidgetTester tester, FakeGoogleIdTokenProvider google) async {
    final h = AppHarness(google: google);
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.go(AppRoutes.account);
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> open(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(find.byKey(Key(key)), 200, scrollable: _accountList);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('vincular Google: pide la contraseña, luego Google, y explica los conflictos', (tester) async {
    final google = FakeGoogleIdTokenProvider();
    final h = await account(tester, google);
    await open(tester, 'account.google.link');

    await tester.tap(find.byKey(const Key('account.google.confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Escribe tu contraseña para confirmar.'), findsOneWidget);
    expect(google.calls, 0);

    h.api.routes['POST /account/google/link'] = (_) => _problem(409, 'GoogleAccountAlreadyLinked');
    await tester.enterText(find.byKey(const Key('account.google.password')), 'actual-12345');
    await tester.tap(find.byKey(const Key('account.google.confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ya está vinculada a otra cuenta'), findsOneWidget);

    h.api.routes['POST /account/google/link'] = (_) => _problem(400, 'CurrentPasswordIncorrect');
    await tester.tap(find.byKey(const Key('account.google.confirm')));
    await tester.pumpAndSettle();
    expect(find.text('La contraseña no es correcta.'), findsOneWidget);

    h.api.routes['POST /account/google/link'] = (_) => const ApiResponse(statusCode: 204);
    await tester.tap(find.byKey(const Key('account.google.confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account.google.dialog')), findsNothing);
    expect(find.byKey(const Key('account.google.done')), findsOneWidget);
    expect(h.api.calls.lastWhere((c) => c.path == '/account/google/link').body, {
      'idToken': 'google-id-token',
      'currentPassword': 'actual-12345',
    });
  });

  testWidgets('desvincular Google: DELETE con la contraseña, sin pasar por Google', (tester) async {
    final google = FakeGoogleIdTokenProvider();
    final h = await account(tester, google);
    h.api.routes['DELETE /account/google/link'] = (_) => const ApiResponse(statusCode: 204);
    await open(tester, 'account.google.unlink');
    await tester.enterText(find.byKey(const Key('account.google.password')), 'actual-12345');
    await tester.tap(find.byKey(const Key('account.google.confirm')));
    await tester.pumpAndSettle();
    final call = h.api.calls.singleWhere((c) => c.path == '/account/google/link');
    expect(call.method, 'DELETE');
    expect(call.body, {'currentPassword': 'actual-12345'});
    expect(google.calls, 0);
    expect(find.byKey(const Key('account.google.done')), findsOneWidget);
    expect(h.location, AppRoutes.account);
  });
}
