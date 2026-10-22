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

  testWidgets('Google y Billetera Web3 avisan que aún no están disponibles y no llaman al backend', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    final before = h.api.calls.length;
    await tap(tester, 'login.google');
    expect(find.text('El acceso con Google aún no está disponible en PaxFide.'), findsOneWidget);
    await tap(tester, 'login.wallet');
    expect(find.text('El acceso con Billetera Web3 aún no está disponible en PaxFide.'), findsOneWidget);
    await tap(tester, 'login.forgot');
    expect(find.byKey(const Key('login.notice')), findsOneWidget);
    expect(h.api.calls.length, before);
    expect(h.location, AppRoutes.login);
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
}
