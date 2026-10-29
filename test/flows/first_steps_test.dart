import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';

import '../support/app_harness.dart';

void main() {
  Future<AppHarness> registerAndLogin(WidgetTester tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.services.router.push(AppRoutes.register);
    await tester.pumpAndSettle();
    h.api.enqueue(const ApiResponse(statusCode: 201, data: {}));
    await tester.enterText(find.byKey(const Key('register.email')), 'nueva@demo');
    await tester.enterText(find.byKey(const Key('register.password')), 'doce-o-mas-chars');
    for (final k in ['register.acceptTerms', 'register.acceptDataPolicy']) {
      await tester.ensureVisible(find.byKey(Key(k)));
      await tester.pump();
      await tester.tap(find.byKey(Key(k)));
    }
    await tester.ensureVisible(find.byKey(const Key('register.submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('register.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Cuenta creada'), findsOneWidget);
    await tester.tap(find.text('Ir a entrar'));
    await tester.pumpAndSettle();
    await h.login(tester, roles: const []);
    return h;
  }

  testWidgets('tras crear la cuenta y entrar: bienvenida, «¿Cómo te llamamos?» y saludo con el nombre', (tester) async {
    final h = await registerAndLogin(tester);
    expect(find.byKey(const Key('firstSteps.welcome')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('firstSteps.continue')));
    await tester.tap(find.byKey(const Key('firstSteps.continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('firstSteps.name')), findsOneWidget);
    // Sin nada escrito pide al menos el nombre.
    await tester.ensureVisible(find.byKey(const Key('firstSteps.save')));
    await tester.tap(find.byKey(const Key('firstSteps.save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Escribe al menos tu nombre'), findsOneWidget);
    h.api.routes['PUT /account/profile'] = (call) => ApiResponse(
      statusCode: 200,
      data: {'email': 'nueva@demo', 'givenName': call.body?['givenName'], 'familyName': call.body?['familyName']},
    );
    h.api.routes['GET /account/profile'] = (_) =>
        const ApiResponse(statusCode: 200, data: {'email': 'nueva@demo', 'givenName': 'Ana'});
    await tester.enterText(find.byKey(const Key('firstSteps.given')), ' Ana ');
    await tester.ensureVisible(find.byKey(const Key('firstSteps.save')));
    await tester.tap(find.byKey(const Key('firstSteps.save')));
    await tester.pumpAndSettle();
    final put = h.api.calls.firstWhere((c) => c.method == 'PUT');
    expect(put.body, {'givenName': 'Ana', 'familyName': null});
    expect(h.location, AppRoutes.home);
    expect(find.textContaining(', Ana'), findsOneWidget);
  });

  testWidgets('«Más tarde» no guarda nada; y la bienvenida no se repite', (tester) async {
    final h = await registerAndLogin(tester);
    await tester.tap(find.byKey(const Key('firstSteps.continue')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('firstSteps.later')));
    await tester.tap(find.byKey(const Key('firstSteps.later')));
    await tester.pumpAndSettle();
    expect(h.api.calls.where((c) => c.method == 'PUT'), isEmpty);
    expect(find.byKey(const Key('firstSteps.welcome')), findsNothing);
    await h.services.session.logout();
    await tester.pumpAndSettle();
    if (h.location != AppRoutes.login) {
      h.services.router.push(AppRoutes.login);
      await tester.pumpAndSettle();
    }
    await h.login(tester, roles: const []);
    expect(find.byKey(const Key('firstSteps.welcome')), findsNothing);
  });

  testWidgets('entrar con una cuenta que ya existía no muestra los primeros pasos', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    await h.login(tester, roles: const []);
    expect(find.byKey(const Key('firstSteps.welcome')), findsNothing);
  });
}
