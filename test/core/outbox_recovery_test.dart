import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/offline/outbox_recovery.dart';
import 'package:paxfide_mobile/core/offline/outbox_status.dart';

import '../support/fakes.dart';

OutboxItem item(String id, OutboxStatus status, {String account = 'acc-1'}) => OutboxItem(
  commandId: id,
  accountId: account,
  kind: 'DISPATCH',
  resourceRef: 'A-1',
  path: '/physical-assets/A-1/dispatch',
  payload: const {'carrierRef': 'c'},
  status: status,
  createdAt: DateTime.utc(2026, 10, 7),
);

void main() {
  test('T-2: IN_FLIGHT persistido pasa a AMBIGUOUS al arrancar', () async {
    final store = InMemoryOutboxStore([item('1', OutboxStatus.inFlight)]);
    await OutboxRecovery(store).executeRecoveryT2();
    expect((await store.getAllItems()).single.status, OutboxStatus.ambiguous);
  });

  test('negativa: IN_FLIGHT nunca vuelve a PENDING al arrancar', () async {
    final store = InMemoryOutboxStore([item('1', OutboxStatus.inFlight)]);
    await OutboxRecovery(store).executeRecoveryT2();
    expect((await store.getAllItems()).single.status, isNot(OutboxStatus.pending));
  });

  test('T-2 no toca otros estados', () async {
    final others = [OutboxStatus.pending, OutboxStatus.ambiguous, OutboxStatus.failed, OutboxStatus.acknowledged];
    final store = InMemoryOutboxStore([for (final s in others) item(s.name, s)]);
    await OutboxRecovery(store).executeRecoveryT2();
    final after = {for (final i in await store.getAllItems()) i.commandId: i.status};
    for (final s in others) {
      expect(after[s.name], s);
    }
  });

  test('T-2 aplica a las entradas de todas las cuentas (sin enviarlas)', () async {
    final store = InMemoryOutboxStore([
      item('1', OutboxStatus.inFlight, account: 'acc-1'),
      item('2', OutboxStatus.inFlight, account: 'acc-2'),
    ]);
    await OutboxRecovery(store).executeRecoveryT2();
    expect((await store.getAllItems()).map((i) => i.status), everyElement(OutboxStatus.ambiguous));
  });

  test('OutboxItem guarda el accountId que lo creó (H2)', () {
    expect(item('1', OutboxStatus.pending, account: 'acc-9').accountId, 'acc-9');
  });
}
