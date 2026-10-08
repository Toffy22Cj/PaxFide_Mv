import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/offline/ambiguous_reconciler.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/offline/outbox_recovery.dart';
import 'package:paxfide_mobile/core/offline/outbox_status.dart';

import '../support/fakes.dart';

OutboxItem item(String id, OutboxStatus status, {String action = 'DISPATCH', String assetRef = 'AS-1'}) =>
    OutboxItem(
      commandId: id,
      assetRef: assetRef,
      actionType: action,
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
        item('c1', OutboxStatus.inFlight),
        item('c2', OutboxStatus.inFlight),
      ]);
      await OutboxRecovery(store).executeRecoveryT2();
      for (final i in store.items.values) {
        expect(i.status, isNot(OutboxStatus.pending));
      }
    });

    test('NEGATIVA: el resto de estados no se tocan', () async {
      final store = FakeOutboxStore([
        item('p', OutboxStatus.pending),
        item('a', OutboxStatus.ambiguous),
        item('f', OutboxStatus.failed),
        item('k', OutboxStatus.acknowledged),
      ]);
      await OutboxRecovery(store).executeRecoveryT2();
      expect(store.writeCount, 0);
      expect(store.items['p']!.status, OutboxStatus.pending);
      expect(store.items['a']!.status, OutboxStatus.ambiguous);
      expect(store.items['f']!.status, OutboxStatus.failed);
      expect(store.items['k']!.status, OutboxStatus.acknowledged);
    });
  });

  group('AmbiguousReconciler', () {
    test('estado observado = esperado → ACKNOWLEDGED (mismo commandId)', () async {
      final store = FakeOutboxStore([item('c1', OutboxStatus.ambiguous, action: 'DISPATCH')]);
      final api = FakeApiClient(
        response: const ApiResponse(statusCode: 200, data: {'lifecycleStatus': 'DISPATCHED'}),
      );
      final r = AmbiguousReconciler(apiClient: api, outboxStore: store);

      final result = await r.reconcile(store.items['c1']!);

      expect(result, ReconciliationResult.acknowledged);
      expect(store.items['c1']!.status, OutboxStatus.acknowledged);
      expect(store.updatedIds, ['c1']);
      expect(api.requests.single.method, 'GET');
      expect(api.requests.single.path, '/physical-assets/AS-1');
      expect(api.requests.single.credentialMode, CredentialMode.jwt);
    });

    test('el estado esperado se deriva de actionType (RECEIVE → RECEIVED, DELIVER → DELIVERED)', () async {
      for (final pair in const [['RECEIVE', 'RECEIVED'], ['DELIVER', 'DELIVERED']]) {
        final store = FakeOutboxStore([item('c', OutboxStatus.ambiguous, action: pair[0])]);
        final api = FakeApiClient(
          response: ApiResponse(statusCode: 200, data: {'lifecycleStatus': pair[1]}),
        );
        final result = await AmbiguousReconciler(apiClient: api, outboxStore: store)
            .reconcile(store.items['c']!);
        expect(result, ReconciliationResult.acknowledged, reason: pair[0]);
      }
    });

    test('NEGATIVA: estado distinto → sigue AMBIGUOUS y NO escribe en el Outbox', () async {
      final store = FakeOutboxStore([item('c1', OutboxStatus.ambiguous, action: 'DISPATCH')]);
      final api = FakeApiClient(
        response: const ApiResponse(statusCode: 200, data: {'lifecycleStatus': 'REGISTERED'}),
      );
      final result = await AmbiguousReconciler(apiClient: api, outboxStore: store)
          .reconcile(store.items['c1']!);
      expect(result, ReconciliationResult.remainsAmbiguous);
      expect(store.writeCount, 0);
      expect(store.items['c1']!.status, OutboxStatus.ambiguous);
    });

    test('NEGATIVA: respuesta no exitosa → sigue AMBIGUOUS sin escribir', () async {
      final store = FakeOutboxStore([item('c1', OutboxStatus.ambiguous)]);
      final api = FakeApiClient(response: const ApiResponse(statusCode: 500));
      final result = await AmbiguousReconciler(apiClient: api, outboxStore: store)
          .reconcile(store.items['c1']!);
      expect(result, ReconciliationResult.remainsAmbiguous);
      expect(store.writeCount, 0);
    });

    test('NEGATIVA: fallo de transporte → propaga la excepción sin escribir', () async {
      final store = FakeOutboxStore([item('c1', OutboxStatus.ambiguous)]);
      final api = FakeApiClient(error: const NetworkTimeoutException());
      final r = AmbiguousReconciler(apiClient: api, outboxStore: store);
      await expectLater(r.reconcile(store.items['c1']!), throwsA(isA<NetworkTimeoutException>()));
      expect(store.writeCount, 0);
      expect(store.items['c1']!.status, OutboxStatus.ambiguous);
    });

    test('NEGATIVA: split/register no se reconcilian por lifecycleStatus y no consultan backend', () async {
      for (final action in const ['SPLIT', 'REGISTER']) {
        final store = FakeOutboxStore([item('c', OutboxStatus.ambiguous, action: action)]);
        final api = FakeApiClient();
        final r = AmbiguousReconciler(apiClient: api, outboxStore: store);
        await expectLater(r.reconcile(store.items['c']!),
            throwsA(isA<UnsupportedReconciliationException>()));
        expect(api.requests, isEmpty);
        expect(store.writeCount, 0);
      }
    });

    test('NEGATIVA: solo se reconcilia AMBIGUOUS', () async {
      for (final status in const [
        OutboxStatus.pending,
        OutboxStatus.inFlight,
        OutboxStatus.failed,
        OutboxStatus.acknowledged,
      ]) {
        final store = FakeOutboxStore([item('c', status)]);
        final api = FakeApiClient();
        final r = AmbiguousReconciler(apiClient: api, outboxStore: store);
        await expectLater(r.reconcile(store.items['c']!),
            throwsA(isA<ReconciliationNotApplicableException>()));
        expect(api.requests, isEmpty);
        expect(store.writeCount, 0);
      }
    });

    test('el assetRef se codifica en el path', () async {
      final store = FakeOutboxStore([item('c', OutboxStatus.ambiguous, assetRef: 'A B')]);
      final api = FakeApiClient(
        response: const ApiResponse(statusCode: 200, data: {'lifecycleStatus': 'X'}),
      );
      await AmbiguousReconciler(apiClient: api, outboxStore: store).reconcile(store.items['c']!);
      expect(api.requests.single.path, '/physical-assets/A%20B');
    });
  });
}
