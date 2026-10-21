import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/shared/theme/pax_tokens.dart';
import 'package:paxfide_mobile/shared/theme/theme_controller.dart';

import '../support/app_harness.dart';

/// Modo claro y oscuro en toda la app: el selector está en el login, en el registro y en las pantallas de la sesión.
void main() {
  Brightness brightnessAt(WidgetTester tester, Finder f) => Theme.of(tester.element(f)).brightness;

  Future<void> choose(WidgetTester tester, ThemeMode mode) async {
    await tester.tap(find.byKey(const Key('theme.menu')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('theme.${mode.name}')).last);
    await tester.pumpAndSettle();
  }

  testWidgets('login: pasa a modo oscuro (fondo casi negro), vuelve a claro con la paleta oficial y lo recuerda', (
    tester,
  ) async {
    final h = AppHarness();
    await h.start(tester);
    expect(h.location, AppRoutes.login);
    final submit = find.byKey(const Key('login.submit'));

    await choose(tester, ThemeMode.dark);
    expect(brightnessAt(tester, submit), Brightness.dark);
    expect(Theme.of(tester.element(submit)).scaffoldBackgroundColor, PaxDarkTokens.background);
    expect(h.secure.values[ThemeController.storageKey], 'dark');

    await choose(tester, ThemeMode.light);
    expect(brightnessAt(tester, submit), Brightness.light);
    expect(Theme.of(tester.element(submit)).colorScheme.primary, PaxTokens.brandGreen800);
  });

  testWidgets('el modo guardado se aplica al abrir la app', (tester) async {
    final h = AppHarness();
    h.secure.values[ThemeController.storageKey] = 'dark';
    await h.start(tester);
    expect(brightnessAt(tester, find.byKey(const Key('login.submit'))), Brightness.dark);
  });

  testWidgets('registro también tiene el selector', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.services.router.go(AppRoutes.register);
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.register);
    expect(find.byKey(const Key('theme.menu')), findsOneWidget);
  });

  testWidgets('con la sesión iniciada el selector está en la barra y cambia toda la app', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    await h.login(tester);
    expect(h.location, isNot(AppRoutes.login));
    expect(find.byKey(const Key('theme.menu')), findsOneWidget);

    await choose(tester, ThemeMode.dark);
    expect(brightnessAt(tester, find.byType(AppBar).first), Brightness.dark);
  });
}
