import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_config.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/features/auth/domain/legal_versions.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
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
    expect(find.byKey(const Key('account.google')), findsNothing);
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
    expect(find.textContaining('no está en PaxFide'), findsOneWidget);
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
    await tester.scrollUntilVisible(find.byKey(const Key('account.google')), 200, scrollable: _accountList);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account.google')));
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

  // ---------------------------------------------------------------- crear la cuenta con Google (ADR-050 Enmienda 3)

  Future<AppHarness> openRegister(WidgetTester tester, FakeGoogleIdTokenProvider google) async {
    final h = AppHarness(google: google);
    await h.start(tester);
    h.services.router.push(AppRoutes.register);
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> fillPasswordAndAccept(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('register.password')), 'doce-o-mas-chars');
    await tester.enterText(find.byKey(const Key('register.passwordRepeat')), 'doce-o-mas-chars');
    for (final k in ['register.acceptTerms', 'register.acceptDataPolicy']) {
      await tester.ensureVisible(find.byKey(Key(k)));
      await tester.pump();
      await tester.tap(find.byKey(Key(k)));
    }
    await tester.ensureVisible(find.byKey(const Key('register.submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('register.submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('sin Google configurado, «Crear cuenta» no ofrece registrarse con Google', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.services.router.push(AppRoutes.register);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('register.google')), findsNothing);
    expect(find.byKey(const Key('register.email')), findsOneWidget);
  });

  testWidgets('registrarse con Google: el correo lo pone Google, la contraseña la persona, y entra directamente', (
    tester,
  ) async {
    final google = FakeGoogleIdTokenProvider()..next = const GoogleIdTokenObtained('id-nuevo', email: 'ana@gmail.com');
    final h = await openRegister(tester, google);
    await tester.tap(find.byKey(const Key('register.google')));
    await tester.pumpAndSettle();
    expect(find.text('Te registras con ana@gmail.com'), findsOneWidget);
    expect(find.byKey(const Key('register.email')), findsNothing, reason: 'el correo no se escribe');

    h.api.enqueue(
      const ApiResponse(statusCode: 201, data: {'accountId': 'acc-9', 'status': 'ACTIVE', 'token': 'jwt-nuevo'}),
    );
    h.api.enqueue(meResponse(roles: const []));
    await fillPasswordAndAccept(tester);

    final call = h.api.calls.singleWhere((c) => c.path == '/auth/google/register');
    expect(call.credentialMode, CredentialMode.none);
    expect(call.body, {
      'idToken': 'id-nuevo',
      'password': 'doce-o-mas-chars',
      'acceptedTermsVersion': currentTermsVersion,
      'acceptedDataPolicyVersion': currentDataPolicyVersion,
    });
    expect(h.api.calls.where((c) => c.path == '/auth/register'), isEmpty);
    expect(h.services.session.state.status, SessionStatus.authenticated);
  });

  testWidgets('registrarse con Google: el correo ya tiene cuenta (409) → entrar y vincular, sin crear nada', (
    tester,
  ) async {
    final h = await openRegister(tester, FakeGoogleIdTokenProvider());
    await tester.tap(find.byKey(const Key('register.google')));
    await tester.pumpAndSettle();
    h.api.routes['POST /auth/google/register'] = (_) => _problem(409, 'DuplicateEmail');
    await fillPasswordAndAccept(tester);
    expect(find.textContaining('Ya existe una cuenta con ese correo'), findsOneWidget);
    expect(h.services.session.state.status, SessionStatus.loggedOut);
  });

  testWidgets('registrarse con Google: «Usar otro correo» vuelve al formulario con correo', (tester) async {
    await openRegister(tester, FakeGoogleIdTokenProvider());
    await tester.tap(find.byKey(const Key('register.google')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('register.googleOther')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('register.email')), findsOneWidget);
    expect(find.byKey(const Key('register.google')), findsOneWidget);
  });

  testWidgets(
    'registrarse con Google: idToken caducado (400 GoogleIdTokenInvalid) → hay que volver a elegir la cuenta',
    (tester) async {
      final h = await openRegister(tester, FakeGoogleIdTokenProvider());
      await tester.tap(find.byKey(const Key('register.google')));
      await tester.pumpAndSettle();
      h.api.routes['POST /auth/google/register'] = (_) => _problem(400, 'GoogleIdTokenInvalid');
      await fillPasswordAndAccept(tester);
      expect(find.text('Google no confirmó la cuenta. Vuelve a elegirla.'), findsOneWidget);
      expect(find.byKey(const Key('register.google')), findsOneWidget);
    },
  );
}
