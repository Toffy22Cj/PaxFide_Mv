import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/offline/command_outcome.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/offline/outbox_status.dart';
import 'package:paxfide_mobile/core/offline/sync_engine.dart';
import 'package:paxfide_mobile/core/storage/outbox_store.dart';

import '../support/fakes.dart';

OutboxItem pending(String id, {String account = 'acc-A'}) => OutboxItem(
  commandId: id,
  accountId: account,
  kind: 'DISPATCH',
  resourceRef: 'A-1',
  path: '/physical-assets/A-1/dispatch',
  payload: const {'carrierRef': 'c'},
  status: OutboxStatus.pending,
  createdAt: DateTime.utc(2026, 10, 7),
);

void main() {
  late SecureOutboxStore store;
  late FakeApiClient api;
  late SyncEngine engine;

  setUp(() {
    store = SecureOutboxStore(InMemorySecureKeyValueStore());
    api = FakeApiClient();
    engine = SyncEngine(store: store, apiClient: api);
  });

  Future<OutboxStatus?> statusOf(String id) async =>
      (await store.getAllItems()).where((i) => i.commandId == id).firstOrNull?.status;

  int posts() => api.calls.where((c) => c.method == 'POST').length;

  test('PENDING → IN_FLIGHT (persistido antes de la respuesta) → ACKNOWLEDGED y se retira', () async {
    await engine.enqueue(pending('1'));
    OutboxStatus? whileSending;
    api.routes['POST /physical-assets/A-1/dispatch'] = (c) {
      // El fake invoca beforeSend antes de producir la respuesta: el estado ya debe estar persistido.
      store.getAllItems().then((all) => whileSending = all.single.status);
      return const ApiResponse(statusCode: 200, data: {});
    };
    expect(await engine.send('1', 'acc-A'), CommandOutcome.acknowledged);
    await Future<void>.delayed(Duration.zero);
    expect(whileSending, OutboxStatus.inFlight);
    expect(await statusOf('1'), isNull);
    expect(api.calls.single.headers['Command-Id'], '1');
  });

  test('4xx → FAILED con el código; negativa: FAILED nunca se reintenta con el mismo commandId', () async {
    await engine.enqueue(pending('1'));
    api.enqueue(const ApiResponse(statusCode: 409));
    expect(await engine.send('1', 'acc-A'), CommandOutcome.failed);
    expect(await statusOf('1'), OutboxStatus.failed);
    expect((await store.getAllItems()).single.rejectionStatus, 409);
    await expectLater(engine.send('1', 'acc-A'), throwsA(isA<OutboxOperationNotAllowedException>()));
    expect(posts(), 1);
  });

  test('timeout → AMBIGUOUS; negativa: AMBIGUOUS nunca se reintenta automáticamente', () async {
    await engine.enqueue(pending('1'));
    api.enqueue(const NetworkTimeoutException());
    expect(await engine.send('1', 'acc-A'), CommandOutcome.ambiguous);
    expect(await statusOf('1'), OutboxStatus.ambiguous);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(posts(), 1);
  });

  test('5xx → AMBIGUOUS (nunca FAILED)', () async {
    await engine.enqueue(pending('1'));
    api.enqueue(const ApiResponse(statusCode: 500));
    expect(await engine.send('1', 'acc-A'), CommandOutcome.ambiguous);
    expect(await statusOf('1'), OutboxStatus.ambiguous);
  });

  test('reintento manual de AMBIGUOUS → mismo Command-Id', () async {
    await engine.enqueue(pending('1'));
    api.enqueue(const ConnectionInterruptedException());
    await engine.send('1', 'acc-A');
    api.enqueue(const ApiResponse(statusCode: 200, data: {}));
    expect(await engine.send('1', 'acc-A'), CommandOutcome.acknowledged);
    expect(api.calls.map((c) => c.headers['Command-Id']), ['1', '1']);
  });

  test('sin conexión: no sale, sigue PENDING y nunca pasó por IN_FLIGHT', () async {
    await engine.enqueue(pending('1'));
    final noBeforeSend = FakeApiClient()..enqueue(const ConnectionNotEstablishedException());
    final e2 = SyncEngine(store: store, apiClient: _NoBeforeSendClient(noBeforeSend));
    expect(await e2.send('1', 'acc-A'), CommandOutcome.notSent);
    expect(await statusOf('1'), OutboxStatus.pending);
  });

  test('negativa: IN_FLIGHT nunca vuelve a PENDING (fallo ambiguo tras salir)', () async {
    await engine.enqueue(pending('1'));
    api.enqueue(const NetworkTimeoutException());
    await engine.send('1', 'acc-A');
    expect(await statusOf('1'), isNot(OutboxStatus.pending));
  });

  group('H2: frontera por accountId', () {
    test('otra cuenta no ve las entradas', () async {
      await engine.enqueue(pending('1', account: 'acc-A'));
      expect(await engine.entriesFor('acc-B'), isEmpty);
      expect((await engine.entriesFor('acc-A')).single.commandId, '1');
    });

    test('negativa: una cuenta nunca envía entradas de otra', () async {
      await engine.enqueue(pending('1', account: 'acc-A'));
      await expectLater(engine.send('1', 'acc-B'), throwsA(isA<OutboxOperationNotAllowedException>()));
      expect(api.calls, isEmpty);
      expect(await statusOf('1'), OutboxStatus.pending);
    });

    test('otra cuenta tampoco verifica ni descarta', () async {
      await store.saveItem(pending('1').copyWith(status: OutboxStatus.ambiguous));
      await store.saveItem(pending('2').copyWith(status: OutboxStatus.failed));
      await expectLater(
        engine.verify('1', 'acc-B', (_) async => true),
        throwsA(isA<OutboxOperationNotAllowedException>()),
      );
      await expectLater(engine.discard('2', 'acc-B'), throwsA(isA<OutboxOperationNotAllowedException>()));
      expect((await store.getAllItems()).length, 2);
    });
  });

  test('verificar: coincide → ACKNOWLEDGED (retirada); no coincide → sigue AMBIGUOUS; nunca envía', () async {
    await store.saveItem(pending('1').copyWith(status: OutboxStatus.ambiguous));
    expect(await engine.verify('1', 'acc-A', (_) async => false), isFalse);
    expect(await statusOf('1'), OutboxStatus.ambiguous);
    expect(await engine.verify('1', 'acc-A', (_) async => true), isTrue);
    expect(await statusOf('1'), isNull);
    expect(api.calls, isEmpty);
  });

  test('verificar solo AMBIGUOUS', () async {
    await engine.enqueue(pending('1'));
    await expectLater(
      engine.verify('1', 'acc-A', (_) async => true),
      throwsA(isA<OutboxOperationNotAllowedException>()),
    );
  });

  test('descartar solo FAILED; no envía nada', () async {
    await engine.enqueue(pending('1'));
    await expectLater(engine.discard('1', 'acc-A'), throwsA(isA<OutboxOperationNotAllowedException>()));
    await store.saveItem(pending('2').copyWith(status: OutboxStatus.ambiguous));
    await expectLater(engine.discard('2', 'acc-A'), throwsA(isA<OutboxOperationNotAllowedException>()));
    await store.saveItem(pending('3').copyWith(status: OutboxStatus.failed));
    await engine.discard('3', 'acc-A');
    expect(await statusOf('3'), isNull);
    expect(api.calls, isEmpty);
  });

  test('enqueue: solo PENDING y sin commandId repetido', () async {
    await expectLater(
      engine.enqueue(pending('1').copyWith(status: OutboxStatus.ambiguous)),
      throwsA(isA<OutboxOperationNotAllowedException>()),
    );
    await engine.enqueue(pending('1'));
    await expectLater(engine.enqueue(pending('1')), throwsA(isA<OutboxOperationNotAllowedException>()));
  });

  test('dos envíos simultáneos de la misma entrada: el segundo se rechaza', () async {
    await engine.enqueue(pending('1'));
    api.enqueue(const ApiResponse(statusCode: 200, data: {}));
    final first = engine.send('1', 'acc-A');
    await expectLater(engine.send('1', 'acc-A'), throwsA(isA<OutboxOperationNotAllowedException>()));
    await first;
    expect(posts(), 1);
  });

  test('persistencia: otro SyncEngine sobre el mismo almacén ve las entradas (reinicio)', () async {
    await engine.enqueue(pending('1'));
    final again = SyncEngine(store: store, apiClient: FakeApiClient());
    expect((await again.entriesFor('acc-A')).single.status, OutboxStatus.pending);
  });

  test('almacén ilegible: no se envía nada', () async {
    final secure = InMemorySecureKeyValueStore()..values[SecureOutboxStore.key] = '{dañado';
    final e = SyncEngine(store: SecureOutboxStore(secure), apiClient: api);
    await expectLater(e.send('1', 'acc-A'), throwsA(isA<OutboxStoreUnreadableException>()));
    expect(api.calls, isEmpty);
  });
}

/// Cliente que, como el real ante "no se pudo conectar", nunca invoca beforeSend.
class _NoBeforeSendClient extends FakeApiClient {
  _NoBeforeSendClient(this.inner);
  final FakeApiClient inner;

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required credentialMode,
    Future<void> Function()? beforeSend,
  }) => inner.post(path, body: body, headers: headers, credentialMode: credentialMode);
}
