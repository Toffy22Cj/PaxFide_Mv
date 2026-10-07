import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';

import '../support/app_harness.dart';

ApiResponse asset(String status) => ApiResponse(
  statusCode: 200,
  data: {
    'assetRef': 'A-1',
    'lifecycleStatus': status,
    'currentCustodianRef': 'bodega-1',
    'currentLocation': 'bodega-1',
    'quantity': '10',
    'unitOfMeasure': 'kg',
  },
);

void main() {
  late AppHarness h;
  late String status;

  Future<void> openAsset(WidgetTester tester, {List<String> roles = const ['EMPLOYEE']}) async {
    h = AppHarness();
    status = 'REGISTERED';
    h.api.routes['GET /physical-assets/A-1'] = (_) => asset(status);
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: roles)));
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
  }

  Iterable<dynamic> posts() => h.api.calls.where((c) => c.method == 'POST');

  Future<void> fillDispatch(WidgetTester tester) async {
    await tap(tester, find.byKey(const Key('asset.action')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form.carrierRef')), 'transportista-1');
    await tester.tap(find.byKey(const Key('form.submit')));
  }

  testWidgets('muestra el activo y, a un EMPLOYEE, la acción que deriva ActionResolver', (tester) async {
    await openAsset(tester);
    expect(find.text('Registrado'), findsOneWidget);
    expect(find.text('10 kg'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Despachar'), findsOneWidget);
  });

  testWidgets('sin EMPLOYEE en /me no se muestra ninguna acción', (tester) async {
    await openAsset(tester, roles: const ['ADMINISTRATOR']);
    expect(find.text('Registrado'), findsOneWidget);
    expect(find.byKey(const Key('asset.action')), findsNothing);
  });

  testWidgets('DELIVERED → solo lectura', (tester) async {
    h = AppHarness();
    h.api.routes['GET /physical-assets/A-1'] = (_) => asset('DELIVERED');
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset.action')), findsNothing);
    expect(find.text('Este activo no tiene más acciones.'), findsOneWidget);
  });

  testWidgets('403 (también inexistente u otra organización) → estado de pantalla, sin redirect', (tester) async {
    h = AppHarness();
    h.api.routes['GET /physical-assets/A-1'] = (_) => const ApiResponse(statusCode: 403);
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
    expect(h.location, '/assets/A-1');
    expect(find.text('No tienes acceso a este activo.'), findsOneWidget);
  });

  testWidgets('despachar: POST con Command-Id, cuerpo exacto y JWT; 200 → confirmada', (tester) async {
    await openAsset(tester);
    h.api.routes['POST /physical-assets/A-1/dispatch'] = (_) {
      status = 'DISPATCHED';
      return const ApiResponse(statusCode: 200, data: {'assetRef': 'A-1', 'status': 'DISPATCHED'});
    };
    await fillDispatch(tester);
    await tester.pumpAndSettle();
    final post = posts().single;
    expect(post.path, '/physical-assets/A-1/dispatch');
    expect(post.body, {'carrierRef': 'transportista-1'});
    expect(post.credentialMode, CredentialMode.jwt);
    expect(post.headers['Command-Id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(find.text('Despachado'), findsOneWidget);
    // ACKNOWLEDGED es terminal: se retira del Outbox.
    expect(await h.services.syncEngine.entriesFor('acc-1'), isEmpty);
    expect(find.widgetWithText(FilledButton, 'Recibir'), findsOneWidget);
  });

  testWidgets('timeout → "no pudimos confirmar"; Verificar estado primero; nunca reintenta solo', (tester) async {
    await openAsset(tester);
    h.api.routes['POST /physical-assets/A-1/dispatch'] = (_) => const NetworkTimeoutException();
    await fillDispatch(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos confirmar la operación'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Verificar estado'), findsOneWidget);
    // Mientras está AMBIGUOUS no se ofrece la acción original.
    expect(find.byKey(const Key('asset.action')), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    expect(posts().length, 1, reason: 'AMBIGUOUS nunca se reintenta automáticamente');

    status = 'DISPATCHED';
    await tap(tester, find.widgetWithText(FilledButton, 'Verificar estado'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos confirmar'), findsNothing);
    expect(find.text('Despachado'), findsOneWidget);
    expect(await h.services.syncEngine.entriesFor('acc-1'), isEmpty);
    expect(posts().length, 1, reason: 'verificar es un GET, no un reenvío');
  });

  testWidgets('verificar con estado distinto → sigue AMBIGUOUS', (tester) async {
    await openAsset(tester);
    h.api.routes['POST /physical-assets/A-1/dispatch'] = (_) => const NetworkTimeoutException();
    await fillDispatch(tester);
    await tester.pumpAndSettle();
    await tap(tester, find.widgetWithText(FilledButton, 'Verificar estado'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos confirmar'), findsOneWidget);
  });

  testWidgets('reintento manual de AMBIGUOUS → mismo Command-Id', (tester) async {
    await openAsset(tester);
    var n = 0;
    h.api.routes['POST /physical-assets/A-1/dispatch'] = (_) =>
        n++ == 0 ? const NetworkTimeoutException() : const ApiResponse(statusCode: 200, data: {});
    await fillDispatch(tester);
    await tester.pumpAndSettle();
    await tap(tester, find.widgetWithText(TextButton, 'Reintentar'));
    await tester.pumpAndSettle();
    final ids = posts().map((c) => c.headers['Command-Id']).toList();
    expect(ids.length, 2);
    expect(ids[0], ids[1]);
  });

  testWidgets('409 → rechazada; "Nueva operación" usa un Command-Id nuevo', (tester) async {
    await openAsset(tester);
    h.api.routes['POST /physical-assets/A-1/dispatch'] = (_) => const ApiResponse(statusCode: 409);
    await fillDispatch(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('El servidor la rechazó'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing, reason: 'FAILED no se reintenta con el mismo Command-Id');
    await tap(tester, find.text('Nueva operación'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form.carrierRef')), 'transportista-2');
    await tester.tap(find.byKey(const Key('form.submit')));
    await tester.pumpAndSettle();
    final ids = posts().map((c) => c.headers['Command-Id']).toList();
    expect(ids.length, 2);
    expect(ids[0], isNot(ids[1]));
  });

  testWidgets('formulario con cambios + deep link: cancelar conserva el formulario y no consume el enlace', (
    tester,
  ) async {
    await openAsset(tester);
    await tap(tester, find.byKey(const Key('asset.action')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form.carrierRef')), 'a medias');
    final link = h.services.deepLinkParser.parse(Uri.parse('$testOrigin/c/PUB1'));
    final consumed = h.services.router.openDeepLink(link);
    await tester.pumpAndSettle();
    expect(find.text('¿Salir sin enviar?'), findsOneWidget);
    await tester.tap(find.text('Seguir aquí'));
    await tester.pumpAndSettle();
    expect(await consumed, isFalse);
    expect(find.text('a medias'), findsOneWidget);
    expect(h.location, '/assets/A-1');
    expect(posts(), isEmpty);
  });

  testWidgets('formulario con cambios + deep link: salir descarta el formulario y consume el enlace', (tester) async {
    await openAsset(tester);
    await tap(tester, find.byKey(const Key('asset.action')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form.carrierRef')), 'a medias');
    final consumed = h.services.router.openDeepLink(h.services.deepLinkParser.parse(Uri.parse('$testOrigin/c/PUB1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(await consumed, isTrue);
    expect(h.location, '/c/PUB1');
    expect(posts(), isEmpty);
  });

  testWidgets('DISPATCHED sin currentLocation (forma real del backend) → se muestra y ofrece Recibir', (tester) async {
    h = AppHarness();
    h.api.routes['GET /physical-assets/A-1'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'assetRef': 'A-1',
        'lifecycleStatus': 'DISPATCHED',
        'currentCustodianRef': 'transportista-1',
        'quantity': '1.0000',
        'unitOfMeasure': 'UNITS',
      },
    );
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.push('/assets/A-1');
    await tester.pumpAndSettle();
    expect(find.text('Despachado'), findsOneWidget);
    expect(find.text('Sin ubicación registrada'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Recibir'), findsOneWidget);
  });
}
