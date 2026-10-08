import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_config.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/app/deep_link_parser.dart';
import 'package:paxfide_mobile/app/public_links.dart';

void main() {
  final origin = AppConfig.originOf('https://paxfide.example/cualquier/ruta?x=1');
  final links = PublicLinks(origin);

  test('el origen se reduce a esquema + host', () {
    expect(origin.toString(), 'https://paxfide.example');
  });

  test('activo y convocatoria con las rutas canónicas de la matriz §4b', () {
    expect(links.asset('A-1').toString(), 'https://paxfide.example/assets/A-1');
    expect(links.campaign('PUB1').toString(), 'https://paxfide.example/c/PUB1');
  });

  test('ida y vuelta: lo que genera la app lo aprueba su propio parser con la misma ruta', () {
    final parser = DeepLinkParser.forOrigin(origin);
    expect(parser.parse(links.asset('A-1')!).route, '/assets/A-1');
    expect(parser.parse(links.campaign('PUB1')!).route, '/c/PUB1');
    expect(parser.parse(links.campaign('PUB1')!).category, RouteCategory.public);
  });

  test('sin origen configurado no se genera ningún QR', () {
    const none = PublicLinks(null);
    expect(none.asset('A-1'), isNull);
    expect(none.campaign('PUB1'), isNull);
  });

  test('parámetro inválido → sin QR', () {
    expect(links.asset(''), isNull);
    expect(links.campaign('a/b'), isNull);
  });

  test('no existe generador de QR de seguimiento (el código nunca va en una URL)', () {
    final src = File('lib/app/public_links.dart').readAsStringSync();
    expect(src, isNot(contains('AppRoutes.tracking')));
    expect(src, isNot(contains("'/tracking")));
  });
}
