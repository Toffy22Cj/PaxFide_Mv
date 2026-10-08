import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';

import '../support/app_harness.dart';

/// Escaneo de QR (encargo §4.2; ADR-043 D9): todo pasa por el único DeepLinkParser.
void main() {
  Future<AppHarness> asEmployee(WidgetTester tester) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: const ['EMPLOYEE'])));
    return h;
  }

  testWidgets('QR de activo desde Operaciones → /assets/:assetRef', (tester) async {
    final h = await asEmployee(tester);
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    h.nextScan = '$testOrigin/assets/A-55';
    await tester.tap(find.byKey(const Key('operator.scan')));
    await tester.pumpAndSettle();
    expect(h.location, '/assets/A-55');
  });

  testWidgets('R3: escanear un activo nunca envía comandos ni genera Command-Id', (tester) async {
    final h = await asEmployee(tester);
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    final before = h.api.calls.length;
    h.nextScan = '$testOrigin/assets/A-55';
    await tester.tap(find.byKey(const Key('operator.scan')));
    await tester.pumpAndSettle();
    final after = h.api.calls.skip(before);
    expect(after.where((c) => c.method == 'POST'), isEmpty);
    expect(after.where((c) => c.headers.containsKey('Command-Id')), isEmpty);
  });

  testWidgets('QR de convocatoria sin sesión, desde el login → /c/:publicCode', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.nextScan = '$testOrigin/c/PUB-1';
    await tester.tap(find.byKey(const Key('login.scan')));
    await tester.pumpAndSettle();
    expect(h.location, '/c/PUB-1');
  });

  testWidgets('QR de seguimiento → /tracking sin el código', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.nextScan = '$testOrigin/tracking/CODIGO-SECRETO';
    await tester.tap(find.byKey(const Key('login.scan')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.tracking);
    expect(h.services.router.stack.join(), isNot(contains('CODIGO-SECRETO')));
    expect(h.secure.values.values.join(), isNot(contains('CODIGO-SECRETO')));
  });

  testWidgets('QR de activo sin sesión → login y PendingIntent (R2)', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.nextScan = '$testOrigin/assets/A-55';
    await tester.tap(find.byKey(const Key('login.scan')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.login);
    expect(h.services.pendingIntents.current?.route, '/assets/A-55');
  });

  testWidgets('QR ajeno → aviso y no navega', (tester) async {
    final h = await asEmployee(tester);
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    h.nextScan = 'https://otra-web.example/assets/A-1';
    await tester.tap(find.byKey(const Key('operator.scan')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.operator);
    expect(find.text('Este código QR no es un enlace de PaxFide reconocido.'), findsOneWidget);
  });

  testWidgets('Operaciones sin EMPLOYEE → estado "sin acceso operativo" (no redirect)', (tester) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: const ['ADMINISTRATOR'])));
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.operator);
    expect(find.text('Tu cuenta no tiene acceso operativo.'), findsOneWidget);
    expect(find.byKey(const Key('operator.scan')), findsNothing);
  });

  testWidgets('escribir la referencia a mano → /assets/:assetRef', (tester) async {
    final h = await asEmployee(tester);
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('operator.type')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('operator.assetRef')), 'A-77');
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(h.location, '/assets/A-77');
  });

  testWidgets('sin cámara: pegar el enlace pasa por el mismo DeepLinkParser (aprobado y no aprobado)', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.nextScan = null; // la cámara no lee nada
    await tester.tap(find.byKey(const Key('login.scan')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('scanner.paste')), '  $testOrigin/c/PUB-7  ');
    await tester.tap(find.byKey(const Key('scanner.paste.open')));
    await tester.pumpAndSettle();
    expect(h.location, '/c/PUB-7');

    h.services.router.back();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login.scan')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('scanner.paste')), 'https://otro.example/assets/A-1');
    await tester.tap(find.byKey(const Key('scanner.paste.open')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.login);
    expect(find.text('Este código QR no es un enlace de PaxFide reconocido.'), findsOneWidget);
  });
}
