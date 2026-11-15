import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/offline/outbox_status.dart';
import 'package:paxfide_mobile/core/storage/outbox_store.dart';

import '../support/app_harness.dart';

Map<String, dynamic> a(String ref, String status) => {
  'assetRef': ref,
  'lifecycleStatus': status,
  'quantity': '1',
  'unitOfMeasure': 'u',
};

/// Empleado: barra Mi día · Escanear · Pendientes (con contador) y Mi día (E-01).
void main() {
  Future<AppHarness> start(WidgetTester tester, {List<OutboxItem> stored = const []}) async {
    final h = AppHarness();
    for (final i in stored) {
      await SecureOutboxStore(h.secure).saveItem(i);
    }
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    return h;
  }

  testWidgets('Mi día cuenta por despachar, en tránsito y entregados; tocar una tarjeta filtra', (tester) async {
    final h = await start(tester);
    h.api.routes['GET /organizations/org-1/physical-assets'] = (_) => ApiResponse(
      statusCode: 200,
      data: {
        'items': [a('A-1', 'REGISTERED'), a('A-2', 'DISPATCHED'), a('A-3', 'RECEIVED'), a('A-4', 'DELIVERED')],
      },
    );
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    expect(find.text('Mi día'), findsWidgets);
    await tester.scrollUntilVisible(find.byKey(const Key('myday.delivered')), 200);
    String count(String g) =>
        tester.widget<Text>(find.descendant(of: find.byKey(Key('myday.$g')), matching: find.byType(Text)).last).data!;
    expect(count('toDispatch'), '1');
    expect(count('inTransit'), '2');
    expect(count('delivered'), '1');

    await tester.tap(find.byKey(const Key('myday.inTransit')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('myday.asset.A-2')), 200);
    expect(find.byKey(const Key('myday.asset.A-2')), findsOneWidget);
    expect(find.byKey(const Key('myday.asset.A-1')), findsNothing);
  });

  testWidgets('sin conexión: aviso y los atajos siguen disponibles', (tester) async {
    final h = await start(tester);
    h.api.routes['GET /organizations/org-1/physical-assets'] = (_) => const ConnectionNotEstablishedException();
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    // Sin red: o el aviso de Mi día o, si ya había una lectura guardada (Enmienda 4, S2), el aviso general.
    expect(
      find.byKey(const Key('myday.offline')).evaluate().isNotEmpty ||
          find.byKey(const Key('shell.offline')).evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.byKey(const Key('operator.type')), findsOneWidget);
  });

  testWidgets('barra del empleado: Inicio, Mi día, Escanear y Cuenta; Pendientes vive en Mi día con su contador', (
    tester,
  ) async {
    final h = await start(
      tester,
      stored: [
        OutboxItem(
          commandId: 'cmd-1',
          accountId: 'acc-1',
          kind: 'DISPATCH',
          resourceRef: 'A-1',
          path: '/physical-assets/A-1/dispatch',
          payload: const {'carrierRef': 'c'},
          status: OutboxStatus.pending,
          createdAt: DateTime.utc(2026, 10, 20),
        ),
      ],
    );
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav.Mi día')), findsOneWidget);
    expect(find.byKey(const Key('nav.Escanear')), findsOneWidget);
    expect(find.byKey(const Key('nav.Pendientes')), findsNothing, reason: 'ya no es una pestaña');
    // El número de pendientes sigue a la vista: en el ícono de Mi día y en su tarjeta.
    final badge = tester.widget<Badge>(find.byKey(const Key('nav.pending.count')));
    expect(badge.isLabelVisible, isTrue);
    expect((badge.label! as Text).data, '1');
    expect(find.text('1 operación guardada en este teléfono'), findsOneWidget);

    await tester.tap(find.byKey(const Key('operator.pending')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.operatorPending);
    // Dentro de Mi día: la pestaña marcada sigue siendo Mi día y hay flecha para volver.
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    expect(find.byType(BackButton), findsOneWidget);
    h.services.router.back();
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.operator);
  });

  testWidgets('M-03: deslizar recorre las pestañas, Escanear incluida, y en la ficha vuelve atrás', (tester) async {
    final h = await start(tester);
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    await tester.fling(find.byKey(const Key('shell.swipe')), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.scan, reason: 'Escanear es una pestaña más');
    await tester.fling(find.byKey(const Key('shell.swipe')), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.account);
    await tester.fling(find.byKey(const Key('shell.swipe')), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    await tester.fling(find.byKey(const Key('shell.swipe')), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.operator);

    h.services.router.push(AppRoutes.assetPath('A-1'));
    await tester.pumpAndSettle();
    await tester.fling(find.byKey(const Key('shell.swipe')), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.operator);
  });

  testWidgets('E-08: Mis convocatorias con sus activos por estado; tocar uno abre la ficha', (tester) async {
    final h = await start(tester);
    h.api.routes['GET /me/campaigns'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'items': [
          {'campaignRef': 'CAMP-1', 'publicCode': 'PUB1', 'title': 'Abrigo', 'status': 'OPEN'},
        ],
      },
    );
    h.api.routes['GET /organizations/org-1/physical-assets'] = (_) => ApiResponse(
      statusCode: 200,
      data: {
        'items': [
          {...a('A-1', 'REGISTERED'), 'campaignRef': 'CAMP-1'},
          {...a('A-2', 'DELIVERED'), 'campaignRef': 'CAMP-1'},
          {...a('B-1', 'REGISTERED'), 'campaignRef': 'OTRA'},
        ],
      },
    );
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('operator.campaigns')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.myCampaigns);
    expect(find.text('Abierta · 2 activos'), findsOneWidget);
    await tester.tap(find.text('Abrigo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mycampaigns.asset.B-1')), findsNothing);
    await tester.tap(find.byKey(const Key('mycampaigns.asset.A-1')));
    await tester.pumpAndSettle();
    expect(h.location, '/assets/A-1');
  });

  testWidgets('la pestaña marcada es la pantalla actual; en la ficha de un activo, ninguna', (tester) async {
    final h = await start(tester);
    await tester.pumpAndSettle();
    NavigationBar bar() => tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(h.location, AppRoutes.home);
    expect(bar().selectedIndex, 0, reason: 'Inicio');
    await tester.tap(find.byKey(const Key('nav.Mi día')));
    await tester.pumpAndSettle();
    expect(bar().selectedIndex, 1, reason: 'Mi día');
    await tester.tap(find.byKey(const Key('nav.Escanear')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.scan);
    expect(bar().selectedIndex, 2, reason: 'Escanear');
    expect(find.byKey(const Key('scanner.paste')), findsOneWidget, reason: 'el escáner está en la pestaña');
    h.services.router.push(AppRoutes.assetPath('A-1'));
    await tester.pumpAndSettle();
    expect(bar().indicatorColor, Colors.transparent);
  });

  testWidgets('desde la pestaña Escanear: un lote abre su ficha y al volver se puede escanear otro', (tester) async {
    final h = await start(tester);
    h.nextScan = '$testOrigin/assets/A-1';
    await tester.tap(find.byKey(const Key('nav.Escanear')));
    await tester.pumpAndSettle();
    expect(h.location, '/assets/A-1');
    h.nextScan = null; // la cámara ya no apunta al mismo QR
    h.services.router.back();
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.scan);
    await tester.enterText(find.byKey(const Key('scanner.paste')), 'A-2');
    await tester.tap(find.byKey(const Key('scanner.paste.open')));
    await tester.pumpAndSettle();
    expect(h.location, '/assets/A-2');
  });
}
