import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';

import '../../support/app_harness.dart';

/// Login del landing adaptado al móvil: lo que el backend todavía no tiene (Google, Billetera Web3, recuperar la
/// contraseña) avisa sin simular nada; «Recordarme» decide si la sesión se guarda en el teléfono.
void main() {
  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pump();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> submitToDialog(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('login.submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Google y Billetera Web3 no están presentes en el login', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    expect(find.byKey(const Key('login.google')), findsNothing);
    expect(find.byKey(const Key('login.wallet')), findsNothing);
    expect(find.text('o continúa con correo electrónico'), findsNothing);
    expect(find.text('Gestiona tus donaciones, sigue su recorrido y apoya convocatorias.'), findsOneWidget);
  });

  testWidgets('¿Olvidaste tu contraseña? abre hoja inferior, valida correo vacío y envía a la API', (tester) async {
    final h = AppHarness();
    await h.start(tester);

    // Escribir correo en el login para verificar que se prellena en la hoja inferior
    await tester.enterText(find.byKey(const Key('login.email')), 'usuario@demo.com');
    await tap(tester, 'login.forgot');

    // La hoja inferior está visible
    expect(find.byKey(const Key('forgot.sheet')), findsOneWidget);
    expect(find.byKey(const Key('forgot.email')), findsOneWidget);
    final forgotField = tester.widget<TextField>(find.byKey(const Key('forgot.email')));
    expect(forgotField.controller?.text, 'usuario@demo.com');

    // Con correo vacío: no envía nada y muestra el aviso de error
    final before = h.api.calls.length;
    await tester.enterText(find.byKey(const Key('forgot.email')), '');
    await tester.tap(find.byKey(const Key('forgot.submit')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe tu correo electrónico.'), findsOneWidget);
    expect(h.api.calls.length, before);

    // Con correo válido: envía POST /auth/password-reset y muestra el mensaje neutro
    h.api.enqueue(const ApiResponse(statusCode: 202));
    await tester.enterText(find.byKey(const Key('forgot.email')), 'recuperar@demo.com');
    await tester.tap(find.byKey(const Key('forgot.submit')));
    await tester.pumpAndSettle();

    expect(h.api.calls.length, before + 1);
    final call = h.api.calls.last;
    expect(call.path, '/auth/password-reset');
    expect(call.body, {'email': 'recuperar@demo.com'});
    expect(
      find.text(
        'Si existe una cuenta con ese correo, te enviamos un enlace para crear una contraseña nueva. '
        'Revisa tu bandeja y sigue el enlace desde tu navegador.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('las pestañas y «Regístrate gratis» llevan a Crear cuenta, y vuelven', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    await tap(tester, 'auth.tab.register');
    expect(h.location, AppRoutes.register);
    await tap(tester, 'auth.tab.login');
    expect(h.location, AppRoutes.login);
    await tap(tester, 'login.register');
    expect(h.location, AppRoutes.register);
    await tap(tester, 'register.login');
    expect(h.location, AppRoutes.login);
  });

  for (final remember in [true, false]) {
    testWidgets('«Recordarme en este teléfono» ${remember ? 'marcado guarda' : 'desmarcado no guarda'} la sesión', (
      tester,
    ) async {
      final h = AppHarness();
      await h.start(tester);
      if (!remember) await tap(tester, 'login.remember');
      h.api.enqueue(const ApiResponse(statusCode: 200, data: {'token': 'jwt-1'}));
      h.api.enqueue(meResponse(roles: const []));
      await tester.enterText(find.byKey(const Key('login.email')), 'donante@demo');
      await tester.enterText(find.byKey(const Key('login.password')), 'pw');
      await tap(tester, 'login.submit');
      expect(h.services.session.state.status, SessionStatus.authenticated);
      expect(h.secure.values.values.contains('jwt-1'), remember);
    });
  }

  testWidgets(
    '11. Login → 403 → diálogo → marcar → "Aceptar y entrar": la segunda llamada lleva las versiones del 403 y la sesión queda AUTHENTICATED',
    (tester) async {
      final h = AppHarness();
      await h.start(tester);
      h.api.enqueue(
        const ApiResponse(
          statusCode: 403,
          data: {
            'title': 'AcceptanceRequired',
            'pendingTermsVersion': 'v1-2026-10',
            'pendingDataPolicyVersion': 'v1-2026-10',
          },
        ),
      );
      h.api.enqueue(const ApiResponse(statusCode: 200, data: {'token': 'jwt-accepted'}));
      h.api.enqueue(meResponse(roles: const []));

      await tester.enterText(find.byKey(const Key('login.email')), 'user@demo.com');
      await tester.enterText(find.byKey(const Key('login.password')), 'password12345');
      await submitToDialog(tester);

      // Diálogo abierto
      expect(find.byKey(const Key('legal-acceptance')), findsOneWidget);
      expect(find.byKey(const Key('legal-acceptance.terms')), findsOneWidget);
      expect(find.byKey(const Key('legal-acceptance.dataPolicy')), findsOneWidget);

      // Marcar casillas
      await tester.tap(find.byKey(const Key('legal-acceptance.terms')));
      await tester.tap(find.byKey(const Key('legal-acceptance.dataPolicy')));
      await tester.pump();

      // Aceptar y entrar
      await tester.tap(find.byKey(const Key('legal-acceptance.accept')));
      await tester.pumpAndSettle();

      // Comprobar segunda llamada
      final loginCalls = h.api.calls.where((c) => c.path == '/auth/login').toList();
      expect(loginCalls, hasLength(2));
      final secondCall = loginCalls[1];
      expect(secondCall.body?['acceptedTermsVersion'], 'v1-2026-10');
      expect(secondCall.body?['acceptedDataPolicyVersion'], 'v1-2026-10');

      // Sesión autenticada
      expect(h.services.session.state.status, SessionStatus.authenticated);
    },
  );

  testWidgets('12. Pulsando "Cancelar": una sola llamada, se ve el error y la sesión sigue LOGGED_OUT', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.api.enqueue(
      const ApiResponse(statusCode: 403, data: {'title': 'AcceptanceRequired', 'pendingTermsVersion': 'v1-2026-10'}),
    );

    await tester.enterText(find.byKey(const Key('login.email')), 'user@demo.com');
    await tester.enterText(find.byKey(const Key('login.password')), 'password12345');
    await submitToDialog(tester);

    expect(find.byKey(const Key('legal-acceptance')), findsOneWidget);
    await tester.tap(find.byKey(const Key('legal-acceptance.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('legal-acceptance')), findsNothing);
    final loginCalls = h.api.calls.where((c) => c.path == '/auth/login').toList();
    expect(loginCalls, hasLength(1));
    expect(find.text('Para entrar debes aceptar las condiciones vigentes.'), findsOneWidget);
    expect(h.services.session.state.status, SessionStatus.loggedOut);
  });

  testWidgets('13. "Aceptar y entrar" está deshabilitado hasta marcar todas las casillas', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.api.enqueue(
      const ApiResponse(
        statusCode: 403,
        data: {
          'title': 'AcceptanceRequired',
          'pendingTermsVersion': 'v1-2026-10',
          'pendingDataPolicyVersion': 'v1-2026-10',
        },
      ),
    );

    await tester.enterText(find.byKey(const Key('login.email')), 'user@demo.com');
    await tester.enterText(find.byKey(const Key('login.password')), 'password12345');
    await submitToDialog(tester);

    expect(find.byKey(const Key('legal-acceptance')), findsOneWidget);

    // Ambas desmarcadas: botón deshabilitado
    FilledButton button() => tester.widget<FilledButton>(find.byKey(const Key('legal-acceptance.accept')));
    expect(button().onPressed, isNull);

    // Solo términos marcada: sigue deshabilitado
    await tester.tap(find.byKey(const Key('legal-acceptance.terms')));
    await tester.pump();
    expect(button().onPressed, isNull);

    // Ambas marcadas: habilitado
    await tester.tap(find.byKey(const Key('legal-acceptance.dataPolicy')));
    await tester.pump();
    expect(button().onPressed, isNotNull);

    // Desmarcar una: vuelve a quedar deshabilitado
    await tester.tap(find.byKey(const Key('legal-acceptance.terms')));
    await tester.pump();
    expect(button().onPressed, isNull);
  });

  testWidgets(
    '14. El reintento devuelve otra vez 403: se ve el mensaje de "cambiaron" y no se abre un segundo diálogo',
    (tester) async {
      final h = AppHarness();
      await h.start(tester);
      h.api.enqueue(
        const ApiResponse(
          statusCode: 403,
          data: {
            'title': 'AcceptanceRequired',
            'pendingTermsVersion': 'v1-2026-10',
            'pendingDataPolicyVersion': 'v1-2026-10',
          },
        ),
      );
      h.api.enqueue(
        const ApiResponse(statusCode: 403, data: {'title': 'AcceptanceRequired', 'pendingTermsVersion': 'v2-2026-11'}),
      );

      await tester.enterText(find.byKey(const Key('login.email')), 'user@demo.com');
      await tester.enterText(find.byKey(const Key('login.password')), 'password12345');
      await submitToDialog(tester);

      expect(find.byKey(const Key('legal-acceptance')), findsOneWidget);
      await tester.tap(find.byKey(const Key('legal-acceptance.terms')));
      await tester.tap(find.byKey(const Key('legal-acceptance.dataPolicy')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('legal-acceptance.accept')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('legal-acceptance')), findsNothing);
      expect(find.text('Las condiciones cambiaron mientras entrabas. Inténtalo de nuevo.'), findsOneWidget);
      expect(h.services.session.state.status, SessionStatus.loggedOut);
    },
  );
}
