// Paradas del mapa del recorrido (ADR-052 D5). Lógica pura, sin widgets ni dependencias de mapas.
import '../data/tracking_api.dart';

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

/// Las paradas de un lote, en el orden del historial: los pasos sin punto (el despacho, una zona sin coordenadas) se
/// omiten y dos pasos seguidos en el mismo punto se unen. Nunca se inventa un punto.
List<MapStop> stopsFor(List<HistoryEntry> history) {
  final stops = <MapStop>[];
  for (final e in history) {
    final p = e.zonePoint;
    if (p == null) continue;
    if (stops.isNotEmpty && stops.last.point == p) {
      stops.last.events.add(e.eventType);
    } else {
      stops.add(MapStop(point: p, zone: e.locationZone, events: [e.eventType]));
    }
  }
  return stops;
}

/// Un recorrido por lote. Con el historial cargado, sus paradas; si no (cargando o con error), solo el punto actual
/// del lote si lo tiene. Los lotes sin ningún punto no aparecen.
List<MapRoute> routesFor(List<LogisticsItem> lots, List<HistoryEntry>? Function(String assetRef) historyOf) {
  final routes = <MapRoute>[];
  for (final lot in lots) {
    final history = historyOf(lot.assetRef);
    final stops = history != null
        ? stopsFor(history)
        : [if (lot.zonePoint case final p?) MapStop(point: p, zone: lot.locationZone, events: const [])];
    if (stops.isNotEmpty) routes.add(MapRoute(assetRef: lot.assetRef, stops: stops));
  }
  return routes;
}
