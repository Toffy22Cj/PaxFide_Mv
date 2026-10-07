import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/offline/outbox_status.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/asset_reconciler.dart';

import '../../support/fakes.dart';

OutboxItem ambiguousDispatch() => OutboxItem(
  commandId: 'cmd-1',
  accountId: 'acc-1',
  kind: 'DISPATCH',
  resourceRef: 'A-1',
  path: '/physical-assets/A-1/dispatch',
  payload: const {'carrierRef': 'c'},
  status: OutboxStatus.ambiguous,
  createdAt: DateTime.utc(2026, 10, 7),
);

void main() {
  late FakeApiClient api;
  late InMemoryOutboxStore store;
  late AssetReconciler reconciler;

  setUp(() {
    api = FakeApiClient();
    store = InMemoryOutboxStore([ambiguousDispatch()]);
    reconciler = AssetReconciler(apiClient: api, outboxStore: store);
  });

  test('estado observado = esperado → ACKNOWLEDGED, con un único GET', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'assetRef': 'A-1', 'lifecycleStatus': 'DISPATCHED'}));
    expect(await reconciler.reconcile(ambiguousDispatch()), ReconciliationResult.acknowledged);
    expect((await store.getAllItems()).single.status, OutboxStatus.acknowledged);
    expect(api.calls.single.method, 'GET');
    expect(api.calls.single.path, '/physical-assets/A-1');
    expect(api.calls.single.credentialMode, CredentialMode.jwt);
  });

  test('estado distinto → sigue AMBIGUOUS y nunca reenvía el comando', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'assetRef': 'A-1', 'lifecycleStatus': 'REGISTERED'}));
    expect(await reconciler.reconcile(ambiguousDispatch()), ReconciliationResult.remainsAmbiguous);
    expect((await store.getAllItems()).single.status, OutboxStatus.ambiguous);
    expect(api.calls.where((c) => c.method == 'POST'), isEmpty);
  });

  test('403/error → sigue AMBIGUOUS', () async {
    api.enqueue(const ApiResponse(statusCode: 403));
    expect(await reconciler.reconcile(ambiguousDispatch()), ReconciliationResult.remainsAmbiguous);
    expect((await store.getAllItems()).single.status, OutboxStatus.ambiguous);
  });

  test('negativa: una entrada que no es AMBIGUOUS no se consulta ni se toca', () async {
    final pending = ambiguousDispatch().copyWith(status: OutboxStatus.pending);
    expect(await reconciler.reconcile(pending), ReconciliationResult.remainsAmbiguous);
    expect(api.calls, isEmpty);
  });
}
