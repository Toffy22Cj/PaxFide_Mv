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

  testWidgets('M-04: elegir el tamaño del texto en la app lo agranda, se suma al del teléfono y se recuerda', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = AppHarness();
    await h.start(tester);
    double scale() => MediaQuery.textScalerOf(tester.element(find.byKey(const Key('login.submit')))).scale(1);
    expect(scale(), 1.5);

    await tester.tap(find.byKey(const Key('textSize.menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('textSize.extraLarge')));
    await tester.pumpAndSettle();
    expect(scale(), closeTo(2.1, 0.001));
    expect(h.secure.values['paxfide.ui.textSize'], 'extraLarge');
    expect(tester.takeException(), isNull);

    await h.login(tester);
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Mi día sin desbordes con el texto muy grande');
  });

  testWidgets('M-04: el tamaño guardado se aplica al abrir la app', (tester) async {
    final h = AppHarness();
    h.secure.values['paxfide.ui.textSize'] = 'large';
    await h.start(tester);
    expect(MediaQuery.textScalerOf(tester.element(find.byKey(const Key('login.submit')))).scale(1), 1.2);
  });
}
