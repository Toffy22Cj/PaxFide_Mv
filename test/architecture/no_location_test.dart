// ADR del mapa del recorrido (M-25), D3: «Nunca la ubicación del teléfono». El mapa dibuja la ZONA pública de cada paso
// (el centro del municipio que sella el backend), no un punto exacto, y la app no pide permiso de ubicación ni lee el
// GPS. Esta prueba lo impide por construcción: si alguien añade un paquete de ubicación, un permiso de ubicación o una
// llamada a la posición del teléfono, el build se rompe. (Escrita sin Flutter en el entorno: la ejecuta quien corra
// `flutter test`.)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _files(String dir, bool Function(String path) keep) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  return d.listSync(recursive: true).whereType<File>().where((f) => keep(f.path));
}

void main() {
  // Paquetes de ubicación y de mapas con ubicación del usuario. `flutter_map` y `latlong2` NO lo son: dibujan, no localizan.
  const forbiddenPackages = [
    'geolocator',
    'geolocator_android',
    'geolocator_apple',
    'location',
    'geocoding',
    'background_location',
    'flutter_background_geolocation',
    'permission_handler',
    'google_maps_flutter',
    'apple_maps_flutter',
    'flutter_map_location_marker',
    'flutter_location_marker',
  ];

  test('pubspec.yaml no declara ningún paquete de ubicación', () {
    final lines = File('pubspec.yaml').readAsLinesSync().where((l) => !l.trimLeft().startsWith('#'));
    final declared = <String>{
      for (final l in lines)
        if (RegExp(r'^\s{2}([a-z0-9_]+)\s*:').firstMatch(l) case final m?) m.group(1)!,
    };
    expect(declared, contains('flutter_map'), reason: 'la prueba lee de verdad las dependencias');
    expect(declared.intersection(forbiddenPackages.toSet()), isEmpty);
  });

  test('ningún AndroidManifest pide permisos de ubicación', () {
    final manifests = _files('android', (p) => p.endsWith('AndroidManifest.xml')).toList();
    expect(manifests, isNotEmpty, reason: 'la prueba encuentra los manifiestos');
    final re = RegExp(r'ACCESS_(FINE|COARSE|BACKGROUND)_LOCATION|FOREGROUND_SERVICE_LOCATION|android\.hardware\.location');
    expect([for (final f in manifests) if (re.hasMatch(f.readAsStringSync())) f.path], isEmpty);
  });

  test('ni iOS ni macOS declaran uso de ubicación', () {
    final plists = [
      ..._files('ios', (p) => p.endsWith('Info.plist')),
      ..._files('macos', (p) => p.endsWith('Info.plist')),
    ];
    expect(plists, isNotEmpty, reason: 'la prueba encuentra los Info.plist');
    final re = RegExp(r'NSLocation\w*UsageDescription|NSLocationTemporary|<string>location</string>');
    expect([for (final f in plists) if (re.hasMatch(f.readAsStringSync())) f.path], isEmpty);
    // los permisos que SÍ tiene la app son los de la cámara y la biometría (fotos de paso y entrar con huella)
    expect(plists.map((f) => f.readAsStringSync()).join(), contains('NSCameraUsageDescription'));
  });

  test('lib/ no usa ninguna API de posición', () {
    final re = RegExp(
      r"package:(geolocator|location|geocoding|permission_handler)\b|\bGeolocator\b|getCurrentPosition|"
      r'getPositionStream|LocationSettings|navigator\.geolocation|\bLocationPermission\b',
    );
    final dart = _files('lib', (p) => p.endsWith('.dart')).toList();
    expect(dart, isNotEmpty);
    final bad = [
      for (final f in dart)
        for (final (i, line) in f.readAsLinesSync().indexed)
          if (re.hasMatch(line) && !line.trimLeft().startsWith('//')) '${f.path}:${i + 1}: $line',
    ];
    expect(bad, isEmpty);
  });

  test('el mapa solo dibuja puntos de la tabla de zonas, nunca de otra fuente', () {
    // la única LatLng de la pantalla sale del punto de una parada (MapStop.point, que sale de ZonePoints)
    final view = File('lib/features/tracking/presentation/tracking_map_view.dart').readAsStringSync();
    expect(view, contains('s.point.latitude'));
    expect(RegExp(r'LatLng\(\s*-?\d').hasMatch(view), isFalse, reason: 'ninguna coordenada escrita a mano en la pantalla');
  });
}
