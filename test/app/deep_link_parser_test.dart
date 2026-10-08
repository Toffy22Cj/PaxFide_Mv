import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/app/deep_link_parser.dart';

void main() {
  final origin = Uri.parse('https://paxfide.example');
  final parser = DeepLinkParser(canonicalOrigin: origin);

  group('payloads aprobados (D9, §11)', () {
    test('activo → /assets/:assetRef, autenticada', () {
      final r = parser.parse(Uri.parse('https://paxfide.example/assets/A-77'));
      expect(r.route, '/assets/A-77');
      expect(r.parameters, {'assetRef': 'A-77'});
      expect(r.category, RouteCategory.authenticated);
    });

    test('convocatoria → /c/:publicCode, pública', () {
      final r = parser.parse(Uri.parse('https://paxfide.example/c/PUB1'));
      expect(r.route, '/c/PUB1');
      expect(r.parameters, {'publicCode': 'PUB1'});
      expect(r.category, RouteCategory.public);
    });

    test('seguimiento → /tracking SIN el código (nunca va en una URL)', () {
      final r = parser.parse(Uri.parse('https://paxfide.example/tracking/SECRETO-123'));
      expect(r.route, '/tracking');
      expect(r.parameters, isEmpty);
      expect(r.category, RouteCategory.public);
      expect(r.toString(), isNot(contains('SECRETO-123')));
    });

    test('seguimiento sin código → /tracking', () {
      expect(parser.parse(Uri.parse('https://paxfide.example/tracking')).route, '/tracking');
    });
  });

  group('R5: no aprobadas', () {
    test('host desconocido', () {
      expect(parser.parse(Uri.parse('https://otro.example/assets/A-1')).category, RouteCategory.notApproved);
    });

    test('esquema distinto del canónico', () {
      expect(parser.parse(Uri.parse('http://paxfide.example/assets/A-1')).category, RouteCategory.notApproved);
    });

    test('sin origen canónico configurado, nada se aprueba', () {
      const p = DeepLinkParser(canonicalOrigin: null);
      expect(p.parse(Uri.parse('https://paxfide.example/c/PUB1')).category, RouteCategory.notApproved);
    });

    test('ruta desconocida o fija que no es payload de QR', () {
      for (final path in ['/home', '/login', '/operator', '/operator/pending', '/campaigns', '/x/y']) {
        expect(
          parser.parse(Uri.parse('https://paxfide.example$path')).category,
          RouteCategory.notApproved,
          reason: path,
        );
      }
    });

    test('parámetro inválido', () {
      for (final path in ['/assets/', '/assets/a/b', '/c/${'x' * 300}']) {
        expect(
          parser.parse(Uri.parse('https://paxfide.example$path')).category,
          RouteCategory.notApproved,
          reason: path,
        );
      }
    });

    test('texto que no es URL', () {
      expect(parser.parseText('esto no es un enlace').category, RouteCategory.notApproved);
      expect(parser.parseText('').category, RouteCategory.notApproved);
    });
  });
}
