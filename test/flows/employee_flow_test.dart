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
    String count(String g) =>
        tester.widget<Text>(find.descendant(of: find.byKey(Key('myday.$g')), matching: find.byType(Text)).last).data!;
    expect(count('toDispatch'), '1');
    expect(count('inTransit'), '2');
    expect(count('delivered'), '1');

    await tester.tap(find.byKey(const Key('myday.inTransit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('myday.asset.A-2')), findsOneWidget);
    expect(find.byKey(const Key('myday.asset.A-1')), findsNothing);
  });

  testWidgets('sin conexión: aviso y los atajos siguen disponibles', (tester) async {
    final h = await start(tester);
    h.api.routes['GET /organizations/org-1/physical-assets'] = (_) => const ConnectionNotEstablishedException();
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('myday.offline')), findsOneWidget);
    expect(find.byKey(const Key('operator.scan')), findsOneWidget);
  });

  testWidgets('barra del empleado: Mi día, Escanear y Pendientes con su contador', (tester) async {
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
    expect(find.byKey(const Key('nav.Pendientes')), findsOneWidget);
    final badge = tester.widget<Badge>(find.byKey(const Key('nav.pending.count')));
    expect(badge.isLabelVisible, isTrue);
    expect((badge.label! as Text).data, '1');

    await tester.tap(find.byKey(const Key('nav.Pendientes')));
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.operatorPending);
  });

  testWidgets('M-03: deslizar cambia de pestaña (sin abrir la cámara) y en la ficha vuelve atrás', (tester) async {
    final h = await start(tester);
    h.services.router.go(AppRoutes.operator);
    await tester.pumpAndSettle();
    await tester.fling(find.byKey(const Key('shell.swipe')), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(h.location, AppRoutes.operatorPending, reason: 'Escanear se salta al deslizar');
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
}
