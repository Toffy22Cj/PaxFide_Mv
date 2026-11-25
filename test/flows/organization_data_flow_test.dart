// Enmienda 6 de ADR-043 (aprobada por Adonis el 2026-11-19), plan 5a de plan-tanda-2026-11-19: «Datos de la organización»
// en la app completa. ESTAS PRUEBAS NO SE HAN EJECUTADO: el entorno donde se escribieron no tiene Flutter. Las corre
// Adonis (`flutter analyze` y `flutter test`) y pega la salida literal en el PR.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/shared/charts/chart_preference_store.dart';

import '../support/app_harness.dart';

void main() {
  const fundsPath = '/organizations/org-1/funds/monthly';
  const activityPath = '/organizations/org-1/activity';

  ApiResponse fundsOk() => const ApiResponse(
    statusCode: 200,
    data: {
      'timezone': 'America/Bogota',
      'items': [
        {'month': '2026-09', 'currency': 'COP', 'clearedAmount': '0'},
        {'month': '2026-10', 'currency': 'COP', 'clearedAmount': '150000'},
        {'month': '2026-11', 'currency': 'COP', 'clearedAmount': '250050'},
      ],
    },
  );

  ApiResponse activityOk() => const ApiResponse(
    statusCode: 200,
    data: {
      'items': [
        {'type': 'ASSET_DELIVERED', 'occurredAt': '2026-11-03T12:00:00Z', 'subject': {'kind': 'ASSET', 'ref': 'a1'}},
        {'type': 'FUNDS_CLEARED', 'occurredAt': '2026-11-03T13:00:00Z', 'subject': {'kind': 'FUND', 'ref': 'f1'}},
        {'type': 'ASSET_REGISTERED', 'occurredAt': '2026-11-01T15:00:00Z', 'subject': {'kind': 'ASSET', 'ref': 'a2'}},
      ],
    },
  );

  Future<AppHarness> open(
    WidgetTester tester,
    List<String> roles, {
    String? org = 'org-1',
    String account = 'acc-1',
    bool goTo = true,
    void Function(AppHarness h)? before,
  }) async {
    final h = AppHarness();
    h.api.routes['GET $fundsPath'] = (_) => fundsOk();
    h.api.routes['GET $activityPath'] = (_) => activityOk();
    before?.call(h);
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: roles, org: org, account: account)));
    if (goTo) {
      h.services.router.go(AppRoutes.organizationData);
      await tester.pumpAndSettle();
    }
    return h;
  }

  Iterable<dynamic> reads(AppHarness h) => h.api.calls.where((c) => c.path.startsWith('/organizations/'));

  for (final role in ['ADMINISTRATOR', 'EMPLOYEE']) {
    testWidgets('$role: los dos paneles, con la sesión de la cuenta y el selector del tipo de gráfico', (tester) async {
      final h = await open(tester, [role]);
      expect(find.byKey(const Key('orgdata.funds.title')), findsOneWidget);
      expect(find.byKey(const Key('orgdata.activity.title')), findsOneWidget);
      final fundsCall = h.api.calls.firstWhere((c) => c.path == fundsPath);
      expect(fundsCall.credentialMode, CredentialMode.jwt);
      expect(h.api.getQueries[h.api.calls.indexOf(fundsCall)], {'months': '12'});
      expect(find.byKey(const Key('charts.funds.simple.select')), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('charts.activity.simple.select')), 300);
      expect(find.byKey(const Key('charts.activity.simple.select')), findsOneWidget);
      // el gráfico lleva las cifras reales de la respuesta, en la moneda y con los meses vacíos en cero
      final label = tester.getSemantics(find.byKey(const Key('funds.vbars.chart'))).label;
      expect(label, contains('sep 2026 0 COP'));
      expect(label, contains('nov 2026 2 500,50 COP'));
    });
  }

  testWidgets('REPRESENTATIVE: solo la actividad, sin selector y sin pedir los fondos (aserción negativa)', (tester) async {
    final h = await open(tester, ['REPRESENTATIVE']);
    expect(find.byKey(const Key('orgdata.activity.title')), findsOneWidget);
    expect(find.byKey(const Key('charts.activity.simple.hbars')), findsOneWidget); // el predeterminado
    expect(find.byKey(const Key('charts.activity.simple.select')), findsNothing);
    expect(find.byKey(const Key('orgdata.funds.title')), findsNothing);
    expect(find.byKey(const Key('charts.funds.simple.select')), findsNothing);
    expect(h.api.calls.where((c) => c.path == fundsPath), isEmpty);
  });

  testWidgets('REPRESENTATIVE con una elección guardada de antes: igual ve el predeterminado', (tester) async {
    final h = await open(
      tester,
      ['REPRESENTATIVE'],
      goTo: false,
      before: (h) => h.secure.values[ChartPreferenceStore.keyFor('acc-1', ChartPanelId.activity)] = '{"simple":"donut"}',
    );
    h.services.router.go(AppRoutes.organizationData);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('charts.activity.simple.donut')), findsNothing);
    expect(find.byKey(const Key('charts.activity.simple.hbars')), findsOneWidget);
  });

  testWidgets('el donante: sin tarjeta en Inicio y, por la ruta, sin pantalla ni lecturas (aserción negativa)', (tester) async {
    final h = await open(tester, const [], org: null, goTo: false);
    h.services.router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home.organizationData')), findsNothing);

    h.services.router.go(AppRoutes.organizationData);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orgdata.denied')), findsOneWidget);
    expect(find.byKey(const Key('orgdata.funds.title')), findsNothing);
    expect(reads(h), isEmpty);
  });

  for (final role in ['ADMINISTRATOR', 'EMPLOYEE', 'REPRESENTATIVE']) {
    testWidgets('$role: la tarjeta de Inicio lleva a la pantalla', (tester) async {
      final h = await open(tester, [role], goTo: false);
      h.services.router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('home.organizationData'));
      await tester.scrollUntilVisible(card, 300);
      await tester.tap(find.descendant(of: card, matching: find.byType(OutlinedButton)));
      await tester.pumpAndSettle();
      expect(h.location, AppRoutes.organizationData);
    });
  }

  testWidgets('la elección se guarda por accountId (nunca el correo) y por panel, y se conserva al reabrir', (tester) async {
    final h = await open(tester, ['ADMINISTRATOR'], account: 'acc-adm');
    await tester.tap(find.byKey(const Key('charts.funds.simple.select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Líneas').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('charts.funds.simple.line')), findsOneWidget);
    expect(h.secure.values[ChartPreferenceStore.keyFor('acc-adm', ChartPanelId.funds)], '{"simple":"line"}');
    expect(h.secure.values.keys.where((k) => k.startsWith('paxfide.charts.') && k.contains('@')), isEmpty);
    // el panel de actividad no se tocó
    expect(h.secure.values.containsKey(ChartPreferenceStore.keyFor('acc-adm', ChartPanelId.activity)), isFalse);

    // salir de la pantalla y volver: sigue la misma elección
    h.services.router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    h.services.router.go(AppRoutes.organizationData);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('charts.funds.simple.line')), findsOneWidget);
  });

  testWidgets('un almacenamiento con basura no rompe la pantalla: vale el predeterminado', (tester) async {
    final h = await open(
      tester,
      ['EMPLOYEE'],
      goTo: false,
      before: (h) {
        h.secure.values[ChartPreferenceStore.keyFor('acc-1', ChartPanelId.funds)] = '{{{ no es json';
        h.secure.values[ChartPreferenceStore.keyFor('acc-1', ChartPanelId.activity)] = '{"simple":"ya-no-existe"}';
      },
    );
    h.services.router.go(AppRoutes.organizationData);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('charts.funds.simple.vbars')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('charts.activity.simple.hbars')), 300);
    expect(find.byKey(const Key('charts.activity.simple.hbars')), findsOneWidget);
  });

  testWidgets('403 en los fondos: su propio estado, sin gráfico, y la actividad sigue', (tester) async {
    await open(tester, ['EMPLOYEE'], before: (h) => h.api.routes['GET $fundsPath'] = (_) => const ApiResponse(statusCode: 403));
    expect(find.byKey(const Key('orgdata.funds.forbidden')), findsOneWidget);
    expect(find.byKey(const Key('funds.vbars.chart')), findsNothing);
    expect(find.byKey(const Key('funds.vbars.empty')), findsNothing); // nunca «sin datos» por un 403
    expect(find.textContaining('No hay datos'), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const Key('charts.activity.simple.select')), 300);
    expect(find.byKey(const Key('orgdata.activity.forbidden')), findsNothing);
  });

  testWidgets('error del servidor: mensaje con reintento; al reintentar se dibuja', (tester) async {
    var calls = 0;
    final h = await open(
      tester,
      ['ADMINISTRATOR'],
      before: (h) => h.api.routes['GET $activityPath'] = (_) {
        calls++;
        return calls == 1 ? const ApiResponse(statusCode: 503) : activityOk();
      },
    );
    expect(find.byKey(const Key('orgdata.activity.error')), findsOneWidget);
    expect(find.byKey(const Key('charts.activity.simple.select')), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const Key('orgdata.activity.error')), 300);
    await tester.tap(find.descendant(of: find.byKey(const Key('orgdata.activity.error')), matching: find.byType(OutlinedButton)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orgdata.activity.error')), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const Key('charts.activity.simple.select')), 300);
    expect(h.api.calls.where((c) => c.path == activityPath), hasLength(2));
  });

  testWidgets('sin conexión: la última respuesta guardada, con su fecha, y dicho; nunca como si fuera de ahora', (tester) async {
    final h = await open(tester, ['ADMINISTRATOR']);
    expect(find.byKey(const Key('orgdata.funds.offline')), findsNothing);

    // se pierde la red y se vuelve a abrir la pantalla
    h.api.routes['GET $fundsPath'] = (_) => const NetworkTimeoutException();
    h.api.routes['GET $activityPath'] = (_) => const NetworkTimeoutException();
    h.services.router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    h.services.router.go(AppRoutes.organizationData);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orgdata.funds.offline')), findsOneWidget);
    expect(find.textContaining('Sin conexión: se muestra la última respuesta guardada el'), findsWidgets);
    expect(find.byKey(const Key('funds.vbars.chart')), findsOneWidget); // las cifras guardadas, no una pantalla vacía
  });

  testWidgets('sin conexión y sin nada guardado: error con reintento, no un gráfico vacío', (tester) async {
    await open(
      tester,
      ['EMPLOYEE'],
      before: (h) {
        h.api.routes['GET $fundsPath'] = (_) => const NetworkTimeoutException();
        h.api.routes['GET $activityPath'] = (_) => const NetworkTimeoutException();
      },
    );
    expect(find.byKey(const Key('orgdata.funds.error')), findsOneWidget);
    expect(find.byKey(const Key('funds.vbars.empty')), findsNothing);
    expect(find.textContaining('No hay datos'), findsNothing);
  });

  testWidgets('datos vacíos: un gráfico vacío dicho como tal, no un error', (tester) async {
    await open(
      tester,
      ['ADMINISTRATOR'],
      before: (h) {
        h.api.routes['GET $fundsPath'] = (_) => const ApiResponse(statusCode: 200, data: {'items': <Object>[]});
        h.api.routes['GET $activityPath'] = (_) => const ApiResponse(statusCode: 200, data: {'items': <Object>[]});
      },
    );
    expect(find.byKey(const Key('funds.empty')), findsOneWidget);
    expect(find.byKey(const Key('orgdata.funds.error')), findsNothing);
    expect(find.byKey(const Key('orgdata.funds.forbidden')), findsNothing);
  });

  testWidgets('el correo nunca se usa para identificar la elección: la clave lleva el accountId opaco', (tester) async {
    final h = await open(tester, ['ADMINISTRATOR'], account: 'acc-opaco-77');
    await tester.tap(find.byKey(const Key('charts.funds.simple.select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barras horizontales').last);
    await tester.pumpAndSettle();
    final keys = h.secure.values.keys.where((k) => k.startsWith('paxfide.charts.')).toList();
    expect(keys, ['paxfide.charts.v1.acc-opaco-77.funds']);
  });
}
