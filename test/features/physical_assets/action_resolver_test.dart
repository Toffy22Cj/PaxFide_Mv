import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/action_resolver.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/asset_action.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/lifecycle_status.dart';

void main() {
  const resolver = ActionResolver();

  test('REGISTERED→Dispatch, DISPATCHED→Receive, RECEIVED→Deliver, DELIVERED→solo lectura', () {
    expect(resolver.resolve(LifecycleStatus.registered), AssetAction.dispatch);
    expect(resolver.resolve(LifecycleStatus.dispatched), AssetAction.receive);
    expect(resolver.resolve(LifecycleStatus.received), AssetAction.deliver);
    expect(resolver.resolve(LifecycleStatus.delivered), AssetAction.readOnly);
  });

  test('DEPLETED (existe en el backend) → solo lectura', () {
    expect(resolver.resolve(LifecycleStatus.depleted), AssetAction.readOnly);
  });

  test('valor del backend → enum; desconocido → null y solo lectura', () {
    expect(LifecycleStatus.fromWire('DISPATCHED'), LifecycleStatus.dispatched);
    expect(LifecycleStatus.fromWire('DEPLETED'), LifecycleStatus.depleted);
    expect(LifecycleStatus.fromWire('ALGO_NUEVO'), isNull);
    expect(resolver.resolveWire('ALGO_NUEVO'), AssetAction.readOnly);
    expect(resolver.resolveWire(null), AssetAction.readOnly);
  });

  test('estado esperado tras cada acción (para reconciliar AMBIGUOUS)', () {
    expect(AssetAction.dispatch.expectedStatusAfter, LifecycleStatus.dispatched);
    expect(AssetAction.receive.expectedStatusAfter, LifecycleStatus.received);
    expect(AssetAction.deliver.expectedStatusAfter, LifecycleStatus.delivered);
    expect(AssetAction.readOnly.expectedStatusAfter, isNull);
  });
}
