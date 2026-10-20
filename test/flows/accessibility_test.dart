import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';

import '../support/app_harness.dart';

/// M-04: la app aguanta el texto grande del teléfono y los botones de solo ícono tienen descripción.
void main() {
  testWidgets('texto al 200 %: login, Mi día y su barra sin desbordes', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = AppHarness();
    await h.start(tester);
    expect(find.byKey(const Key('login.submit')), findsOneWidget);
    await h.login(tester);
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('los botones de solo ícono de la barra superior tienen descripción', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    await h.login(tester);
    for (final b in tester.widgetList<IconButton>(find.byType(IconButton))) {
      expect(b.tooltip, isNotNull);
    }
  });
}
