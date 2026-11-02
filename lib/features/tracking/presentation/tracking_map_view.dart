import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/tracking_map.dart';
import '../domain/tracking_story.dart';

/// Identificador de la app en las peticiones de teselas (política de uso de las teselas de OpenStreetMap, ADR-052 D5).
const mapUserAgentPackage = 'com.paxfide.mobile';

/// Mapa del recorrido (M-25, ADR-052 D5): las paradas de cada lote sobre la zona pública de cada paso, unidas por una
/// línea, con la última parada resaltada. Nunca la ubicación del teléfono (D3). No sustituye a la línea de tiempo,
/// que sigue siendo la fuente de la verdad; sin conexión, las paradas y la línea se ven igual, con un aviso.
class TrackingMapView extends StatefulWidget {
  const TrackingMapView({super.key, required this.routes, required this.tileUrl, this.tileProvider});

  /// Solo recorridos con al menos una parada (`routesFor`).
  final List<MapRoute> routes;

  /// Plantilla de las teselas (`AppConfig.mapTileUrl`).
  final String tileUrl;

  /// Por defecto, la red; en las pruebas, teselas en memoria.
  final TileProvider? tileProvider;

  @override
  State<TrackingMapView> createState() => _TrackingMapViewState();
}

class _TrackingMapViewState extends State<TrackingMapView> {
  bool _tilesFailed = false;

  void _onTileError() {
    if (_tilesFailed) return;
    // El aviso se pone después del fotograma: la capa de teselas lo informa mientras pinta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _tilesFailed = true);
    });
  }

  static LatLng _latLng(MapStop s) => LatLng(s.point.latitude, s.point.longitude);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final points = [
      for (final r in widget.routes)
        for (final s in r.stops) _latLng(s),
    ];
    final distinct = points.toSet();
    final summary = [
      for (final r in widget.routes) r.stops.map((s) => s.zone.isEmpty ? 'sin zona' : s.zone).join(' → '),
    ].join('; ');
    return Column(
      key: const Key('tracking.map'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Mapa del recorrido: $summary',
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: RepaintBoundary(
              child: SizedBox(
                height: 240,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: points.first,
                    initialZoom: 11,
                    // Con más de un punto, el encuadre los abarca a todos; nunca más cerca que el nivel de una ciudad.
                    initialCameraFit: distinct.length > 1
                        ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(36), maxZoom: 12)
                        : null,
                    maxZoom: 14,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: widget.tileUrl,
                      userAgentPackageName: mapUserAgentPackage,
                      tileProvider: widget.tileProvider,
                      errorTileCallback: (_, _, _) => _onTileError(),
                    ),
                    PolylineLayer(
                      polylines: [
                        for (final r in widget.routes)
                          if (r.stops.length > 1)
                            Polyline(points: r.stops.map(_latLng).toList(), strokeWidth: 4, color: scheme.primary),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        for (final r in widget.routes)
                          for (final (i, s) in r.stops.indexed)
                            Marker(
                              point: _latLng(s),
                              width: 34,
                              height: 34,
                              child: _StopMarker(number: i + 1, current: i == r.stops.length - 1),
                            ),
                      ],
                    ),
                    // Atribución siempre visible (política de OSM). Propia: la de la librería se desborda con el
                    // texto grande (M-04).
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        key: const Key('tracking.map.attribution'),
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        constraints: const BoxConstraints(maxWidth: 220),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '© OpenStreetMap contributors',
                            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurface),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_tilesFailed) ...[
          const SizedBox(height: 6),
          Text(
            'No se pudo cargar el mapa de fondo (¿sin conexión?). Las paradas se ven igual.',
            key: const Key('tracking.map.offline'),
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 8),
        for (final (ri, r) in widget.routes.indexed) ...[
          if (widget.routes.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text('Lote ${ri + 1}', style: theme.textTheme.labelMedium),
            ),
          for (final (i, s) in r.stops.indexed)
            _StopRow(number: i + 1, stop: s, current: i == r.stops.length - 1, key: Key('tracking.map.stop.$ri.$i')),
        ],
        const SizedBox(height: 4),
        Text(
          'El mapa marca la zona pública de cada paso, nunca el lugar exacto ni a quién se entregó.',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _StopMarker extends StatelessWidget {
  const _StopMarker({required this.number, required this.current});
  final int number;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = current ? scheme.primary : scheme.surface;
    final fg = current ? scheme.onPrimary : scheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.primary, width: 2.5),
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({super.key, required this.number, required this.stop, required this.current});
  final int number;
  final MapStop stop;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final what = stop.events.map(eventLabel).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text('$number', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: stop.zone.isEmpty ? noPublicZone : stop.zone,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (what.isNotEmpty) TextSpan(text: ' · $what'),
                  if (current) const TextSpan(text: ' · última parada'),
                ],
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
