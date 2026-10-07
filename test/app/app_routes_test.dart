import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';

void main() {
  group('AppRoutes.categorize (árbol D8 corregido)', () {
    test('rutas públicas exactas', () {
      expect(AppRoutes.categorize('/c/ABC123'), RouteCategory.public);
      expect(AppRoutes.categorize('/tracking'), RouteCategory.public);
    });

    test('seguimiento: el código nunca forma parte de una ruta aprobada', () {
      expect(AppRoutes.categorize('/tracking/SECRETO'), RouteCategory.notApproved);
    });

    test('transitorias de auth', () {
      expect(AppRoutes.categorize('/login'), RouteCategory.authTransitory);
      expect(AppRoutes.categorize('/register'), RouteCategory.authTransitory);
    });

    test('autenticadas', () {
      for (final r in ['/home', '/donations', '/operator', '/operator/pending', '/prediction', '/assets/A-1']) {
        expect(AppRoutes.categorize(r), RouteCategory.authenticated, reason: r);
      }
    });

    test('parámetros estructuralmente inválidos → no aprobada', () {
      for (final r in ['/c/', '/c/a/b', '/assets/', '/assets/a/b', '/c/${'x' * 257}', '/assets/%20']) {
        expect(AppRoutes.categorize(r), RouteCategory.notApproved, reason: r);
      }
    });

    test('desconocidas y diferidas → no aprobada', () {
      for (final r in ['', '/', '/campaigns', '/boot', '/home/x', '/donations/1']) {
        expect(AppRoutes.categorize(r), RouteCategory.notApproved, reason: r);
      }
    });
  });
}
