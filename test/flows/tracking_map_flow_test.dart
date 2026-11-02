import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';

import '../support/app_harness.dart';

/// M-25, mapa del recorrido (ADR-052): el punto de la zona pública de cada paso, bajo el árbol del seguimiento.
const _ctg = {'latitude': 10.3932, 'longitude': -75.4832};
const _baq = {'latitude': 10.9639, 'longitude': -74.7964};

ApiResponse _summary({bool withPoint = true}) => ApiResponse(
  statusCode: 200,
  data: {
    'financialSnapshot': {
      'currency': 'COP',
      'originalAmount': 6000000,
      'clearedAmount': 6000000,
      'pendingAllocationAmount': 0,
      'confirmedAllocationAmount': 5000000,
      'refundedAmount': 0,
    },
    'logistics': [
      {
        'assetRef': 'A-1',
        'lifecycleStatus': 'DELIVERED',
        'assetType': 'BLANKET',
        'unitOfMeasure': 'UNITS',
        'quantity': '6',
        'locationZone': 'Barranquilla, Atlántico',
        'custodianCategory': 'LAST_MILE_CARRIER',
        'zonePoint': ?(withPoint ? _baq : null),
      },
    ],
    'status': 'EN_PROCESO',
  },
);

Map<String, Object?> _step(String type, String status, String? zone, Map<String, double>? point) => {
  'eventType': type,
  'timestamp': '2026-10-21T10:00:00Z',
  'locationZone': ?zone,
  'custodianCategory': 'UNCATEGORIZED',
  'status': status,
  'anchorStatus': 'PENDING',
  'zonePoint': ?point,
};

ApiResponse _history({bool withPoints = true}) => ApiResponse(
  statusCode: 200,
  data: {
    'history': [
      _step('ASSET_REGISTERED', 'REGISTERED', 'Cartagena, Bolívar', withPoints ? _ctg : null),
      _step('ASSET_DISPATCHED', 'DISPATCHED', null, null),
      _step('ASSET_RECEIVED', 'RECEIVED', 'Barranquilla, Atlántico', withPoints ? _baq : null),
      _step('ASSET_DELIVERED', 'DELIVERED', 'Barranquilla, Atlántico', withPoints ? _baq : null),
    ],
  },
);

void main() {
  Future<AppHarness> follow(
    WidgetTester tester, {
    bool map = true,
    bool failingTiles = false,
    bool points = true,
  }) async {
    final h = AppHarness(map: map, failingTiles: failingTiles);
    await h.start(tester);
    h.services.router.push(AppRoutes.tracking);
    await tester.pumpAndSettle();
    h.api.routes['GET /donations/tracking'] = (_) => _summary(withPoint: points);
    h.api.routes['GET /donations/tracking/assets/A-1/history'] = (_) => _history(withPoints: points);
    h.api.routes['GET /donations/tracking/narrative'] = (_) =>
        const ApiResponse(statusCode: 200, data: {'status': 'PENDING'});
    h.api.routes['GET /donations/tracking/integrity'] = (_) =>
        const ApiResponse(statusCode: 200, data: {'batches': [], 'unanchoredEvents': 0, 'checkedAt': ''});
    await tester.enterText(find.byKey(const Key('tracking.code')), 'CODIGO-MAPA');
    await tester.tap(find.byKey(const Key('tracking.submit')));
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> toMap(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('tracking.map')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dibuja las paradas del lote en orden, sin el despacho, con línea y la atribución de OSM', (
    tester,
  ) async {
    final h = await follow(tester);
    await toMap(tester);
    expect(find.byType(FlutterMap), findsOneWidget);
    // Cartagena (registro) y Barranquilla (recepción y entrega unidas): dos paradas, dos marcadores, una línea
    expect(find.byKey(const Key('tracking.map.stop.0.0')), findsOneWidget);
    expect(find.byKey(const Key('tracking.map.stop.0.1')), findsOneWidget);
    expect(find.byKey(const Key('tracking.map.stop.0.2')), findsNothing);
    expect(find.textContaining('Cartagena, Bolívar'), findsWidgets);
    expect(find.textContaining('Recibido · Entregado · última parada'), findsOneWidget);
    expect(tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines.single.points, hasLength(2));
    expect(tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers, hasLength(2));
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    // Las teselas llevan el identificador de la app y nada del seguimiento
    final tiles = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(tiles.urlTemplate, isNot(contains('CODIGO-MAPA')));
    expect(h.services.router.stack.join(), isNot(contains('CODIGO-MAPA')));
  });

  testWidgets('sin teselas configuradas no hay mapa (ADR-052 D5)', (tester) async {
    await follow(tester, map: false);
    expect(find.byKey(const Key('tracking.map'), skipOffstage: false), findsNothing);
    expect(find.byType(FlutterMap, skipOffstage: false), findsNothing);
  });

  testWidgets('sin ningún punto en el recorrido no hay mapa: la línea de tiempo sigue igual', (tester) async {
    await follow(tester, points: false);
    expect(find.byKey(const Key('tracking.map'), skipOffstage: false), findsNothing);
    expect(find.text('Historia de tu donación'), findsOneWidget);
  });

  testWidgets('sin conexión para las teselas: aviso, y las paradas se ven igual', (tester) async {
    await follow(tester, failingTiles: true);
    await toMap(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tracking.map.offline')), findsOneWidget);
    expect(find.byKey(const Key('tracking.map.stop.0.1')), findsOneWidget);
  });
}
