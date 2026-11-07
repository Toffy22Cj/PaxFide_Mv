// Paradas del mapa del recorrido (M-25). Lógica pura, sin widgets ni dependencias de mapas.
//
// El backend da la zona pública de cada paso como texto sellado, «MUNICIPIO, DEPARTAMENTO» tal cual el catálogo
// DIVIPOLA (enmienda 2 de ADR-029); la app la traduce a un punto con su tabla de zonas (ZonePoints). Nunca la
// ubicación del teléfono.
import 'dart:convert';

import '../data/tracking_api.dart';

/// El punto representativo de una zona pública (WGS84): el centro del municipio, nunca un lugar exacto.
class ZonePoint {
  const ZonePoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) => other is ZonePoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'ZonePoint($latitude, $longitude)';
}

/// La tabla de zonas de la app (`assets/map/zonas.json`, generada con `scripts/generar_zonas_mapa.py` desde el
/// catálogo DIVIPOLA del backend y las coordenadas del DANE). Busca por el texto de la zona sin distinguir mayúsculas
/// ni espacios de los extremos; una zona que no está no tiene punto (nunca se inventa uno).
class ZonePoints {
  ZonePoints(Map<String, ZonePoint> byZone) : _byZone = {for (final e in byZone.entries) _key(e.key): e.value};

  final Map<String, ZonePoint> _byZone;

  static String _key(String zone) => zone.trim().toUpperCase();

  ZonePoint? of(String zone) => zone.trim().isEmpty ? null : _byZone[_key(zone)];

  int get length => _byZone.length;

  /// Lee el JSON de la tabla; las entradas que no son dos números en rango se descartan.
  static ZonePoints parse(String json) {
    final doc = jsonDecode(json);
    final zones = doc is Map ? doc['zones'] : null;
    final out = <String, ZonePoint>{};
    if (zones is Map) {
      for (final e in zones.entries) {
        final v = e.value;
        if (e.key is! String || v is! List || v.length != 2 || v[0] is! num || v[1] is! num) continue;
        final lat = (v[0] as num).toDouble(), lon = (v[1] as num).toDouble();
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;
        out[e.key as String] = ZonePoint(lat, lon);
      }
    }
    return ZonePoints(out);
  }
}

/// Una parada de un lote sobre el mapa: el punto de su zona pública y lo que pasó allí.
class MapStop {
  const MapStop({required this.point, required this.zone, required this.events});
  final ZonePoint point;
  final String zone;

  /// Los `eventType` de los pasos que caen en esta parada, en orden (dos pasos seguidos en el mismo punto son una
  /// sola parada).
  final List<String> events;
}

/// El recorrido de un lote sobre el mapa.
class MapRoute {
  const MapRoute({required this.assetRef, required this.stops});
  final String assetRef;
  final List<MapStop> stops;

  /// La última parada: dónde está ahora (o dónde se entregó).
  MapStop? get current => stops.isEmpty ? null : stops.last;
}

/// Las paradas de un lote, en el orden del historial: los pasos sin zona o con una zona que no está en la tabla se
/// omiten y dos pasos seguidos en el mismo punto se unen. Nunca se inventa un punto.
List<MapStop> stopsFor(List<HistoryEntry> history, ZonePoints zones) {
  final stops = <MapStop>[];
  for (final e in history) {
    final p = zones.of(e.locationZone);
    if (p == null) continue;
    if (stops.isNotEmpty && stops.last.point == p) {
      stops.last.events.add(e.eventType);
    } else {
      stops.add(MapStop(point: p, zone: e.locationZone, events: [e.eventType]));
    }
  }
  return stops;
}

/// Un recorrido por lote. Con el historial cargado, sus paradas; si no (cargando o con error), solo la zona actual del
/// lote si tiene punto. Los lotes sin ningún punto no aparecen.
List<MapRoute> routesFor(
  List<LogisticsItem> lots,
  List<HistoryEntry>? Function(String assetRef) historyOf,
  ZonePoints zones,
) {
  final routes = <MapRoute>[];
  for (final lot in lots) {
    final history = historyOf(lot.assetRef);
    final current = zones.of(lot.locationZone);
    final stops = history != null
        ? stopsFor(history, zones)
        : [if (current != null) MapStop(point: current, zone: lot.locationZone, events: const [])];
    if (stops.isNotEmpty) routes.add(MapRoute(assetRef: lot.assetRef, stops: stops));
  }
  return routes;
}
