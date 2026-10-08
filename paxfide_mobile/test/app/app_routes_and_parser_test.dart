import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/app/deep_link_parser.dart';
import 'package:paxfide_mobile/app/navigation_restore_state.dart';

void main() {
  group('AppRoutes.match — árbol v1', () {
    final cases = <String, RouteCategory>{
      '/c/PUB-1': RouteCategory.public,
      '/tracking/TRK-1': RouteCategory.public,
      '/login': RouteCategory.authTransitory,
      '/home': RouteCategory.authenticated,
      '/donations': RouteCategory.authenticated,
      '/operator': RouteCategory.authenticated,
      '/operator/pending': RouteCategory.authenticated,
      '/assets/AS-1': RouteCategory.authenticated,
    };
    cases.forEach((path, category) {
      test('$path → $category', () {
        final m = AppRoutes.match(path);
        expect(m.category, category);
        expect(m.path, path);
      });
    });

    test('extrae parámetros', () {
      expect(AppRoutes.match('/assets/AS-1').params, {'assetRef': 'AS-1'});
      expect(AppRoutes.match('/c/PUB-1').params, {'publicCode': 'PUB-1'});
      expect(AppRoutes.match('/tracking/TRK-1').params, {'trackingCode': 'TRK-1'});
    });

    const notApproved = [
      '/campaigns', // diferida fuera de v1
      '/',
      '',
      '/c',
      '/c/',
      '/assets',
      '/assets/a/b',
      '/home/extra',
      '/operator/other',
      '/tracking/a/b',
      '/boot', // no existe ruta de arranque (G-1 a)
      '/ambiguous/AS-1', // AMBIGUOUS no es ruta
      '/assets/AS-1/deliver', // las acciones no son rutas
      'https://example.org/home', // con host no es path interno
    ];
    for (final path in notApproved) {
      test('NEGATIVA: "$path" → No aprobada', () {
        expect(AppRoutes.match(path).category, RouteCategory.notApproved);
      });
    }

    test('NEGATIVA: parámetro más largo que el máximo defensivo → No aprobada', () {
      final long = 'x' * (AppRoutes.maxParamLength + 1);
      expect(AppRoutes.match('/assets/$long').category, RouteCategory.notApproved);
      final ok = 'x' * AppRoutes.maxParamLength;
      expect(AppRoutes.match('/assets/$ok').category, RouteCategory.authenticated);
    });

    test('NEGATIVA: un / codificado en el parámetro → No aprobada', () {
      expect(AppRoutes.match('/assets/a%2Fb').category, RouteCategory.notApproved);
    });
  });

  group('DeepLinkParser', () {
    test('path interno (escáner) se clasifica sin host', () {
      final p = const DeepLinkParser().parse(Uri.parse('/assets/AS-9'));
      expect(p.category, RouteCategory.authenticated);
      expect(p.route, '/assets/AS-9');
      expect(p.parameters, {'assetRef': 'AS-9'});
    });

    test('NEGATIVA: con lista vacía (por defecto) todo host externo se rechaza', () {
      final p = const DeepLinkParser().parse(Uri.parse('https://paxfide.example/c/PUB-1'));
      expect(p.isApproved, isFalse);
    });

    test('host permitido + https → se acepta', () {
      final parser = const DeepLinkParser(allowedHosts: {'paxfide.example'});
      final p = parser.parse(Uri.parse('https://PAXFIDE.example/c/PUB-1'));
      expect(p.category, RouteCategory.public);
      expect(p.parameters, {'publicCode': 'PUB-1'});
    });

    test('NEGATIVA: host no permitido → No aprobada', () {
      final parser = const DeepLinkParser(allowedHosts: {'paxfide.example'});
      expect(parser.parse(Uri.parse('https://evil.example/assets/AS-1')).isApproved, isFalse);
    });

    test('NEGATIVA: esquema distinto de https → No aprobada', () {
      final parser = const DeepLinkParser(allowedHosts: {'paxfide.example'});
      expect(parser.parse(Uri.parse('http://paxfide.example/c/PUB-1')).isApproved, isFalse);
      expect(parser.parse(Uri.parse('paxfide://paxfide.example/c/PUB-1')).isApproved, isFalse);
    });

    test('NEGATIVA: /campaigns no es aprobada aunque el host sea válido', () {
      final parser = const DeepLinkParser(allowedHosts: {'paxfide.example'});
      expect(parser.parse(Uri.parse('https://paxfide.example/campaigns')).isApproved, isFalse);
    });
  });

  group('NavigationRestoreState.isValid', () {
    NavigationRestoreState s(String route, {Map<String, String> params = const {}, int? version}) =>
        NavigationRestoreState(
          route: route,
          allowedParams: params,
          schemaVersion: version ?? NavigationRestoreState.currentSchemaVersion,
        );

    test('ruta aprobada, versión actual → válida', () {
      expect(s('/home').isValid(), isTrue);
      expect(s('/assets/AS-1', params: {'assetRef': 'AS-1'}).isValid(), isTrue);
      expect(s('/c/PUB-1').isValid(), isTrue);
    });

    test('NEGATIVA: schemaVersion desconocida → inválida', () {
      expect(s('/home', version: 99).isValid(), isFalse);
    });

    test('NEGATIVA: /login es transitoria → nunca restaurable', () {
      expect(s('/login').isValid(), isFalse);
    });

    test('NEGATIVA: ruta fuera del árbol → inválida', () {
      expect(s('/campaigns').isValid(), isFalse);
      expect(s('/desconocida').isValid(), isFalse);
    });

    test('NEGATIVA: parámetros que no coinciden con la ruta → inválida', () {
      expect(s('/assets/AS-1', params: {'assetRef': 'AS-2'}).isValid(), isFalse);
      expect(s('/home', params: {'assetRef': 'AS-1'}).isValid(), isFalse);
    });
  });
}
