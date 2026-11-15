import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_config.dart';

void main() {
  group('PAXFIDE_MAP_TILE_URL (ADR del mapa, D4): sin una plantilla válida, no hay mapa', () {
    test('https u http con host y las tres variables', () {
      expect(
        AppConfig.tileTemplate(' https://tile.openstreetmap.org/{z}/{x}/{y}.png '),
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      expect(AppConfig.tileTemplate('http://192.168.1.20:8081/{z}/{x}/{y}.png'), isNotNull);
    });

    test('vacía, sin alguna variable, sin host o con otro esquema → null', () {
      for (final raw in [
        '',
        'https://tile.openstreetmap.org/{z}/{x}.png',
        'tile.openstreetmap.org/{z}/{x}/{y}.png',
        'ftp://tiles.example/{z}/{x}/{y}.png',
        'https:///{z}/{x}/{y}.png',
      ]) {
        expect(AppConfig.tileTemplate(raw), isNull, reason: raw);
      }
    });
  });
}
