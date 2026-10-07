import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/navigation_restore_state.dart';

void main() {
  NavigationRestoreState s(String route, {Map<String, String> params = const {}, int? v}) => NavigationRestoreState(
    route: route,
    allowedParams: params,
    schemaVersion: v ?? NavigationRestoreState.currentSchemaVersion,
  );

  test('ruta aprobada con la versión actual es válida', () {
    expect(s('/home').isValid(), isTrue);
    expect(s('/c/PUB1', params: {'publicCode': 'PUB1'}).isValid(), isTrue);
    expect(s('/assets/A-1', params: {'assetRef': 'A-1'}).isValid(), isTrue);
    expect(s('/tracking').isValid(), isTrue);
  });

  test('schemaVersion desconocida → inválido', () {
    expect(s('/home', v: 999).isValid(), isFalse);
  });

  test('ruta no aprobada (incluida /campaigns) → inválido', () {
    expect(s('/campaigns').isValid(), isFalse);
    expect(s('/x').isValid(), isFalse);
  });

  test('transitorias nunca se restauran', () {
    expect(s('/login').isValid(), isFalse);
    expect(s('/register').isValid(), isFalse);
  });

  test('parámetros que no corresponden a la ruta → inválido', () {
    expect(s('/home', params: {'trackingCode': 'X'}).isValid(), isFalse);
    expect(s('/c/PUB1', params: {'publicCode': 'OTRO'}).isValid(), isFalse);
  });

  test('ida y vuelta por JSON; JSON corrupto → null', () {
    final original = s('/assets/A-1', params: {'assetRef': 'A-1'});
    final back = NavigationRestoreState.tryFromJson(original.toJson());
    expect(back?.route, '/assets/A-1');
    expect(back?.allowedParams, {'assetRef': 'A-1'});
    expect(NavigationRestoreState.tryFromJson('{no es json'), isNull);
    expect(NavigationRestoreState.tryFromJson('{"route":3}'), isNull);
  });
}
