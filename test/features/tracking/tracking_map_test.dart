import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/tracking/data/tracking_api.dart';
import 'package:paxfide_mobile/features/tracking/domain/tracking_map.dart';

const _ctg = ZonePoint(10.38513, -75.49627);
const _baq = ZonePoint(10.97796, -74.81555);
final _zones = ZonePoints({'CARTAGENA DE INDIAS, BOLÍVAR': _ctg, 'BARRANQUILLA, ATLÁNTICO': _baq});

HistoryEntry _step(String type, String zone) => HistoryEntry(
  eventType: type,
  timestamp: '2026-11-03T10:00:00Z',
  locationZone: zone,
  custodianCategory: 'UNCATEGORIZED',
  status: 'X',
);

LogisticsItem _lot(String ref, {String zone = ''}) => LogisticsItem(
  assetRef: ref,
  lifecycleStatus: 'DELIVERED',
  assetType: 'BLANKET',
  unitOfMeasure: 'UNITS',
  quantity: '6',
  locationZone: zone,
  custodianCategory: 'LAST_MILE_CARRIER',
);

void main() {
  group('tabla de zonas de la app (assets/map/zonas.json)', () {
    test('la del repositorio tiene las 1122 zonas del catálogo DIVIPOLA del backend, con el texto que sella', () {
      final zones = ZonePoints.parse(File('assets/map/zonas.json').readAsStringSync());
      expect(zones.length, 1122);
      expect(zones.of('BARRANQUILLA, ATLÁNTICO'), isNotNull);
      expect(zones.of('BOGOTÁ, D.C.'), isNotNull, reason: 'Bogotá una sola vez, como SealedZone.of');
      expect(zones.of('CARTAGENA DE INDIAS, BOLÍVAR'), isNotNull);
    });

    test('sin distinguir mayúsculas ni espacios; lo que no está, vacío o inválido no tiene punto', () {
      expect(_zones.of('  Barranquilla, Atlántico '), _baq);
      expect(_zones.of('bodega-central'), isNull, reason: 'texto libre antiguo de location_reference');
      expect(_zones.of(''), isNull);
      final parsed = ZonePoints.parse('{"zones":{"A":[10,-75],"B":[91,0],"C":["10","-75"],"D":[10]}}');
      expect(parsed.length, 1);
      expect(parsed.of('A'), const ZonePoint(10, -75));
    });
  });

  group('paradas de un lote', () {
    test('en orden; el despacho con la zona del paso anterior se une; sin zona o fuera de la tabla, se omite', () {
      final stops = stopsFor([
        _step('ASSET_REGISTERED', 'CARTAGENA DE INDIAS, BOLÍVAR'),
        _step('ASSET_DISPATCHED', 'CARTAGENA DE INDIAS, BOLÍVAR'),
        _step('ASSET_SPLIT', ''),
        _step('ASSET_RECEIVED', 'BARRANQUILLA, ATLÁNTICO'),
        _step('ASSET_DELIVERED', 'BARRANQUILLA, ATLÁNTICO'),
      ], _zones);
      expect(stops.map((s) => s.zone), ['CARTAGENA DE INDIAS, BOLÍVAR', 'BARRANQUILLA, ATLÁNTICO']);
      expect(stops.first.events, ['ASSET_REGISTERED', 'ASSET_DISPATCHED']);
      expect(stops.last.events, ['ASSET_RECEIVED', 'ASSET_DELIVERED']);
    });

    test('sin ningún punto → sin paradas', () {
      expect(stopsFor([_step('ASSET_DISPATCHED', ''), _step('ASSET_RECEIVED', 'centro-1')], _zones), isEmpty);
    });

    test('volver a una zona anterior es otra parada (no se reordena)', () {
      final stops = stopsFor([
        _step('ASSET_REGISTERED', 'CARTAGENA DE INDIAS, BOLÍVAR'),
        _step('ASSET_RECEIVED', 'BARRANQUILLA, ATLÁNTICO'),
        _step('ASSET_DELIVERED', 'CARTAGENA DE INDIAS, BOLÍVAR'),
      ], _zones);
      expect(stops, hasLength(3));
    });
  });

  test('recorridos por lote: con historial, sus paradas; sin él, la zona actual; sin puntos, no aparece', () {
    final routes = routesFor(
      [_lot('L-1'), _lot('L-2', zone: 'BARRANQUILLA, ATLÁNTICO'), _lot('L-3')],
      (ref) => switch (ref) {
        'L-1' => [
          _step('ASSET_REGISTERED', 'CARTAGENA DE INDIAS, BOLÍVAR'),
          _step('ASSET_RECEIVED', 'BARRANQUILLA, ATLÁNTICO'),
        ],
        'L-3' => [_step('ASSET_DISPATCHED', '')],
        _ => null,
      },
      _zones,
    );
    expect(routes.map((r) => r.assetRef), ['L-1', 'L-2']);
    expect(routes.first.stops, hasLength(2));
    expect(routes.last.stops.single.point, _baq);
  });
}
