import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/offline/outbox_status.dart';
import 'package:paxfide_mobile/core/storage/outbox_store.dart';

import '../support/fakes.dart';

OutboxItem item(String id, {OutboxStatus status = OutboxStatus.pending, String account = 'acc-1'}) => OutboxItem(
  commandId: id,
  accountId: account,
  kind: 'DISPATCH',
  resourceRef: 'A-1',
  path: '/physical-assets/A-1/dispatch',
  payload: const {'carrierRef': 'c'},
  status: status,
  createdAt: DateTime.utc(2026, 10, 7, 12),
);

void main() {
  late InMemorySecureKeyValueStore secure;
  late SecureOutboxStore store;

  setUp(() {
    secure = InMemorySecureKeyValueStore();
    store = SecureOutboxStore(secure);
  });

  test('ida y vuelta: todos los campos, incluido el accountId', () async {
    await store.saveItem(item('1', status: OutboxStatus.failed).copyWith(rejectionStatus: 409));
    final back = (await SecureOutboxStore(secure).getAllItems()).single;
    expect(back.commandId, '1');
    expect(back.accountId, 'acc-1');
    expect(back.status, OutboxStatus.failed);
    expect(back.rejectionStatus, 409);
    expect(back.payload, {'carrierRef': 'c'});
    expect(back.createdAt, DateTime.utc(2026, 10, 7, 12));
  });

  test('JSON con campo de versión en una única clave del almacén cifrado', () async {
    await store.saveItem(item('1'));
    final doc = jsonDecode(secure.values[SecureOutboxStore.key]!) as Map;
    expect(doc['v'], SecureOutboxStore.schemaVersion);
    expect(secure.values.keys, [SecureOutboxStore.key]);
  });

  test('versión desconocida → error y NO se sobrescribe', () async {
    secure.values[SecureOutboxStore.key] = jsonEncode({'v': 99, 'items': []});
    await expectLater(store.getAllItems(), throwsA(isA<OutboxStoreUnreadableException>()));
    await expectLater(store.saveItem(item('2')), throwsA(isA<OutboxStoreUnreadableException>()));
    expect(jsonDecode(secure.values[SecureOutboxStore.key]!)['v'], 99);
  });

  test('datos dañados → error y NO se borran', () async {
    secure.values[SecureOutboxStore.key] = '{dañado';
    await expectLater(store.getAllItems(), throwsA(isA<OutboxStoreUnreadableException>()));
    await expectLater(store.deleteItem('x'), throwsA(isA<OutboxStoreUnreadableException>()));
    expect(secure.values[SecureOutboxStore.key], '{dañado');
  });

  test('escrituras seguidas no se pisan', () async {
    await Future.wait([for (var i = 0; i < 20; i++) store.saveItem(item('$i'))]);
    expect((await store.getAllItems()).length, 20);
  });
}
