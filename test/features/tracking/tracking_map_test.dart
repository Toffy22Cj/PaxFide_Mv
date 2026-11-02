import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/tracking/data/tracking_api.dart';
import 'package:paxfide_mobile/features/tracking/domain/tracking_map.dart';

const _ctg = ZonePoint(10.3932, -75.4832);
const _baq = ZonePoint(10.9639, -74.7964);

HistoryEntry _step(String type, String zone, ZonePoint? p) => HistoryEntry(
  eventType: type,
  timestamp: '2026-10-21T10:00:00Z',
  locationZone: zone,
  custodianCategory: 'UNCATEGORIZED',
  status: 'X',
  zonePoint: p,
);

LogisticsItem _lot(String ref, {ZonePoint? point, String zone = ''}) => LogisticsItem(
  assetRef: ref,
  lifecycleStatus: 'DELIVERED',
  assetType: 'BLANKET',
  unitOfMeasure: 'UNITS',
  quantity: '6',
  locationZone: zone,
  custodianCategory: 'LAST_MILE_CARRIER',
  zonePoint: point,
);

void main() {
  group('ZonePoint.parse (ADR-052 D2): nunca un punto inventado', () {
    test('con los dos números en rango', () {
      expect(ZonePoint.parse({'latitude': 10.3932, 'longitude': -75.4832}), _ctg);
      expect(ZonePoint.parse({'latitude': 4, 'longitude': -74}), const ZonePoint(4, -74));
    });

    test('falta, incompleto, texto o fuera de rango → null', () {
      for (final v in <Object?>[
        null,
        'x',
        {'latitude': 10},
        {'latitude': '10', 'longitude': '-75'},
        {'latitude': 91, 'longitude': 0},
        {'latitude': 0, 'longitude': -181},
        {'latitude': double.nan, 'longitude': 0},
      ]) {
        expect(ZonePoint.parse(v), isNull, reason: '$v');
      }
    });
  });

  group('paradas de un lote', () {
    test('en orden, sin los pasos sin punto, y unen dos pasos seguidos en el mismo punto', () {
      final stops = stopsFor([
        _step('ASSET_REGISTERED', 'Cartagena, Bolívar', _ctg),
        _step('ASSET_DISPATCHED', '', null),
        _step('ASSET_RECEIVED', 'Barranquilla, Atlántico', _baq),
        _step('ASSET_DELIVERED', 'Barranquilla, Atlántico', _baq),
      ]);
      expect(stops.map((s) => s.zone), ['Cartagena, Bolívar', 'Barranquilla, Atlántico']);
      expect(stops.last.events, ['ASSET_RECEIVED', 'ASSET_DELIVERED']);
    });

    test('sin ningún punto → sin paradas', () {
      expect(stopsFor([_step('ASSET_DISPATCHED', '', null)]), isEmpty);
    });

    test('volver a un punto anterior es otra parada (no se reordena)', () {
      final stops = stopsFor([
        _step('ASSET_REGISTERED', 'A', _ctg),
        _step('ASSET_RECEIVED', 'B', _baq),
        _step('ASSET_DELIVERED', 'A', _ctg),
      ]);
      expect(stops.map((s) => s.zone), ['A', 'B', 'A']);
    });
  });

  group('recorridos por lote', () {
    test('con historial, sus paradas; sin él, solo el punto actual; sin puntos, el lote no aparece', () {
      final routes = routesFor(
        [_lot('L-1'), _lot('L-2', point: _baq, zone: 'Barranquilla, Atlántico'), _lot('L-3')],
        (ref) => switch (ref) {
          'L-1' => [_step('ASSET_REGISTERED', 'Cartagena, Bolívar', _ctg), _step('ASSET_RECEIVED', 'B', _baq)],
          'L-3' => [_step('ASSET_DISPATCHED', '', null)],
          _ => null,
        },
      );
      expect(routes.map((r) => r.assetRef), ['L-1', 'L-2']);
      expect(routes.first.stops, hasLength(2));
      expect(routes.first.current?.zone, 'B');
      expect(routes.last.stops.single.point, _baq);
    });
  });
}
