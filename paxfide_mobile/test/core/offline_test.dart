import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/offline/outbox_recovery.dart';
import 'package:paxfide_mobile/core/offline/outbox_status.dart';
import 'package:paxfide_mobile/core/offline/sync_engine.dart';
import 'package:paxfide_mobile/features/physical_assets/data/physical_asset_api.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/asset_operations.dart';

import '../support/fakes.dart';

const account = 'acc-1';

OutboxItem item(
  String id,
  OutboxStatus status, {
  String kind = 'DISPATCH',
  String assetRef = 'AS-1',
  String accountId = account,
}) =>
    OutboxItem(
      commandId: id,
      accountId: accountId,
      kind: kind,
      resourceRef: assetRef,
      path: '/physical-assets/$assetRef/${kind.toLowerCase()}',
      payload: const {},
      status: status,
      createdAt: DateTime.utc(2026, 10, 7),
    );

void main() {
  group('OutboxRecovery — T-2', () {
    test('IN_FLIGHT persistido → AMBIGUOUS al arrancar', () async {
      final store = FakeOutboxStore([item('c1', OutboxStatus.inFlight)]);
      await OutboxRecovery(store).executeRecoveryT2();
      expect(store.items['c1']!.status, OutboxStatus.ambiguous);
    });

    test('NEGATIVA: ninguna entrada termina en PENDING tras la recuperación', () async {
      final store = FakeOutboxStore([
        item('a', OutboxStatus.inFlight),
        item('b', OutboxStatus.ambiguous),
        item('c', OutboxStatus.failed),
      ]);
      await OutboxRecovery(store).executeRecoveryT2();
      expect(store.items.values.where((i) => i.status == OutboxStatus.pending), isEmpty);
      expect(store.items['b']!.status, OutboxStatus.ambiguous);
      expect(store.items['c']!.status, OutboxStatus.failed);
    });

    test('T-2 recupera las entradas de todas las cuentas sin cambiar su dueño', () async {
      final store = FakeOutboxStore([
        item('a', OutboxStatus.inFlight),
        item('b', OutboxStatus.inFlight, accountId: 'acc-2'),
      ]);
      await OutboxRecovery(store).executeRecoveryT2();
      expect(store.items['a']!.status, OutboxStatus.ambiguous);
      expect(store.items['b']!.status, OutboxStatus.ambiguous);
      expect(store.items['b']!.accountId, 'acc-2');
    });
  });

  group('AssetOperations.verify — reconciliación por lifecycleStatus (D6)', () {
    late FakeOutboxStore store;
    late FakeApiClient api;
    late AssetOperations ops;

    setUp(() {
      store = FakeOutboxStore([item('c1', OutboxStatus.ambiguous)]);
      api = FakeApiClient();
      ops = AssetOperations(engine: SyncEngine(store: store, apiClient: api), api: PhysicalAssetApi(api));
    });

    Map<String, dynamic> asset(String status) => {'assetRef': 'AS-1', 'lifecycleStatus': status};

    test('estado observado = esperado → ACKNOWLEDGED (se retira)', () async {
      api.enqueue(ok(asset('DISPATCHED')));
      expect(await ops.verify(store.items['c1']!, accountId: account), isTrue);
      expect(store.items.containsKey('c1'), isFalse);
      expect(api.calls.single.path, '/physical-assets/AS-1');
      expect(api.calls.single.credentialMode, CredentialMode.jwt);
    });

    test('estado distinto → sigue AMBIGUOUS y NUNCA reenvía', () async {
      api.enqueue(ok(asset('REGISTERED')));
      expect(await ops.verify(store.items['c1']!, accountId: account), isFalse);
      expect(store.items['c1']!.status, OutboxStatus.ambiguous);
      expect(api.calls.where((c) => c.method == 'POST'), isEmpty);
    });

    test('sin poder leer el activo → sigue AMBIGUOUS', () async {
      api.enqueue(const NetworkTimeoutException());
      expect(await ops.verify(store.items['c1']!, accountId: account), isFalse);
      expect(store.items['c1']!.status, OutboxStatus.ambiguous);
    });

    test('NEGATIVA: no se verifica una entrada de otra cuenta y no se consulta nada', () async {
      store.items['c2'] = item('c2', OutboxStatus.ambiguous, accountId: 'acc-2');
      await expectLater(
        ops.verify(store.items['c2']!, accountId: account),
        throwsA(isA<OutboxOperationNotAllowedException>()),
      );
      expect(api.calls, isEmpty);
    });

    test('el assetRef se codifica en el path', () async {
      store.items['c3'] = item('c3', OutboxStatus.ambiguous, assetRef: 'A B');
      api.enqueue(ok({'assetRef': 'A B', 'lifecycleStatus': 'X'}));
      await ops.verify(store.items['c3']!, accountId: account);
      expect(api.calls.single.path, '/physical-assets/A%20B');
    });
  });
}
