import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/action_resolver.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/asset_action.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/lifecycle_status.dart';

void main() {
  group('LifecycleStatus.fromApi', () {
    test('acepta los cinco valores del backend', () {
      expect(LifecycleStatus.fromApi('REGISTERED'), LifecycleStatus.registered);
      expect(LifecycleStatus.fromApi('DISPATCHED'), LifecycleStatus.dispatched);
      expect(LifecycleStatus.fromApi('RECEIVED'), LifecycleStatus.received);
      expect(LifecycleStatus.fromApi('DELIVERED'), LifecycleStatus.delivered);
      expect(LifecycleStatus.fromApi('DEPLETED'), LifecycleStatus.depleted);
    });

    test('NEGATIVA: un valor desconocido lanza excepción nombrada, sin valor por defecto', () {
      expect(() => LifecycleStatus.fromApi('SPLIT'),
          throwsA(isA<UnknownLifecycleStatusException>()));
      expect(() => LifecycleStatus.fromApi('delivered'),
          throwsA(isA<UnknownLifecycleStatusException>()));
    });
  });

  group('ActionResolver', () {
    const resolver = ActionResolver();

    test('cada estado muestra su siguiente acción', () {
      expect(resolver.resolve(LifecycleStatus.registered), AssetAction.dispatch);
      expect(resolver.resolve(LifecycleStatus.dispatched), AssetAction.receive);
      expect(resolver.resolve(LifecycleStatus.received), AssetAction.deliver);
    });

    test('DELIVERED y DEPLETED son solo lectura', () {
      expect(resolver.resolve(LifecycleStatus.delivered), AssetAction.readOnly);
      expect(resolver.resolve(LifecycleStatus.depleted), AssetAction.readOnly);
    });
  });
}
