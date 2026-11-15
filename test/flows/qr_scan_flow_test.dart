import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    await tester.tap(find.byKey(const Key('nav.Escanear')));
    await tester.pumpAndSettle();
    expect(h.location, '/assets/A-55');
  });

  testWidgets('R3: escanear un activo nunca envía comandos ni genera Command-Id', (tester) async {
    final h = await asEmployee(tester);
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    final before = h.api.calls.length;
    h.nextScan = '$testOrigin/assets/A-55';
    await tester.tap(find.byKey(const Key('nav.Escanear')));
    await tester.pumpAndSettle();
    final after = h.api.calls.skip(before);
    expect(after.where((c) => c.method == 'POST'), isEmpty);
    expect(after.where((c) => c.headers.containsKey('Command-Id')), isEmpty);
  });

  testWidgets('QR de convocatoria sin sesión, desde el login → /c/:publicCode', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.nextScan = '$testOrigin/c/PUB-1';
    await tester.ensureVisible(find.byKey(const Key('login.scan')));
    await tester.tap(find.byKey(const Key('login.scan')));
    await tester.pumpAndSettle();
    expect(h.location, '/c/PUB-1');
  });

  testWidgets('QR de seguimiento → /tracking sin el código', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.nextScan = '$testOrigin/tracking/CODIGO-SECRETO';
    await tester.ensureVisible(find.byKey(const Key('login.scan')));
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
    await tester.ensureVisible(find.byKey(const Key('login.scan')));
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
    await tester.tap(find.byKey(const Key('nav.Escanear')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.scan, reason: 'se queda en la pestaña Escanear, sin abrir nada');
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
    expect(find.byKey(const Key('nav.Escanear')), findsNothing);
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
    await tester.ensureVisible(find.byKey(const Key('login.scan')));
    await tester.tap(find.byKey(const Key('login.scan')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('scanner.paste')), '  $testOrigin/c/PUB-7  ');
    await tester.ensureVisible(find.byKey(const Key('scanner.paste.open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scanner.paste.open')));
    await tester.pumpAndSettle();
    expect(h.location, '/c/PUB-7');

    h.services.router.back();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('login.scan')));
    await tester.tap(find.byKey(const Key('login.scan')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('scanner.paste')), 'https://otro.example/assets/A-1');
    await tester.ensureVisible(find.byKey(const Key('scanner.paste.open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scanner.paste.open')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.login);
    expect(find.text('Este código QR no es un enlace de PaxFide reconocido.'), findsOneWidget);
  });

  testWidgets('M-31/M-19: marco de encuadre y "Pegar" desde el portapapeles; una referencia escrita abre la ficha', (
    tester,
  ) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.nextScan = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': '  A-9  '};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byIcon(Icons.qr_code_scanner).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scanner.frame')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scanner.paste.clipboard')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('scanner.paste.open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scanner.paste.open')));
    await tester.pumpAndSettle();
    expect(h.location, '/assets/A-9');
  });

  // ── Escáner según el perfil (correcciones 5 y 6). El permiso real lo decide el backend (P7). ──

  Future<AppHarness> asDonor(WidgetTester tester) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: const [], org: null)));
    return h;
  }

  Future<void> openDonorScanner(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('home.scan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home.scan')));
    await tester.pumpAndSettle();
  }

  testWidgets('el escáner del donante habla de convocatorias, nunca de activos ni lotes', (tester) async {
    final h = await asDonor(tester);
    h.nextScan = null;
    await openDonorScanner(tester);
    expect(find.text('Convocatoria'), findsOneWidget);
    expect(find.textContaining('ctivo'), findsNothing);
    expect(find.textContaining('lote'), findsNothing);
    expect(find.text('O pega el enlace de la convocatoria'), findsOneWidget);
  });

  testWidgets('el escáner del empleado lee lotes y deja escribir la referencia (E-02)', (tester) async {
    final h = await asEmployee(tester);
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    h.nextScan = null;
    await tester.tap(find.byKey(const Key('nav.Escanear')));
    await tester.pumpAndSettle();
    expect(find.text('Lote o convocatoria'), findsOneWidget);
    expect(find.text('Pegar o escribir la referencia'), findsOneWidget);
  });

  testWidgets('el donante que escanea el QR de un lote: aviso claro, no se abre la ficha ni se pide nada', (
    tester,
  ) async {
    final h = await asDonor(tester);
    final before = h.api.calls.length;
    h.nextScan = '$testOrigin/assets/A-55';
    await openDonorScanner(tester);
    expect(h.location, AppRoutes.home);
    expect(find.text('Este QR es de un lote de una organización: solo lo abren sus empleados.'), findsOneWidget);
    expect(h.api.calls.skip(before).where((c) => c.path.startsWith('/physical-assets')), isEmpty);
  });

  testWidgets('6. un código de seguimiento pegado en el escáner del donante nunca abre /assets ni se guarda', (
    tester,
  ) async {
    final h = await asDonor(tester);
    const code = 'NWEwNjViM2QtZjRlYi00ZWU2LWI0NmYtYjc1MGQ2MGUyYTQx.bIPYP_oZmBqH9pBT49MhzAHWU1-fBioIFzXGlN43In4';
    final before = h.api.calls.length;
    h.nextScan = code;
    await openDonorScanner(tester);
    expect(h.location, AppRoutes.home);
    expect(h.services.router.stack.join(), isNot(contains(code)));
    expect(h.secure.values.values.join(), isNot(contains(code)));
    expect(h.api.calls.skip(before).where((c) => c.path.contains(code)), isEmpty);
    // Sin callejón sin salida: el aviso lleva a Seguir una donación
    final action = find.descendant(of: find.byType(SnackBar), matching: find.text('Seguir una donación'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.tracking);
    expect(h.services.router.stack.join(), isNot(contains(code)));
  });

  testWidgets('6. sin sesión, un texto suelto en el escáner tampoco abre /assets', (tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.nextScan = 'A-9';
    await tester.ensureVisible(find.byKey(const Key('login.scan')));
    await tester.tap(find.byKey(const Key('login.scan')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.login);
    expect(h.services.pendingIntents.current, isNull);
    expect(find.descendant(of: find.byType(SnackBar), matching: find.text('Seguir una donación')), findsOneWidget);
  });
}
