import 'dart:convert';

import '../errors/app_exceptions.dart';
import '../offline/outbox_item.dart';
import 'secure_key_value_store.dart';

/// Almacenamiento del Outbox (ADR-043 D5; §0 A2): `flutter_secure_storage`,
/// JSON cifrado con un campo de versión.
///
/// Ownership (A1): las entradas se guardan con su `accountId` y sobreviven al
/// logout; solo reaparecen para la misma cuenta.
abstract class OutboxStore {
  /// Todas las entradas, de cualquier cuenta. Solo para la recuperación T-2
  /// al arrancar; nunca para mostrar ni enviar.
  Future<List<OutboxItem>> getAllItems();

  /// Entradas de [accountId]. Es lo único que la UI y el envío pueden leer.
  Future<List<OutboxItem>> getItemsFor(String accountId);

  Future<void> saveItem(OutboxItem item);
  Future<void> updateStatus(String commandId, OutboxItem updatedItem);

  /// Descartar pide confirmación en la UI antes de llamar aquí.
  Future<void> deleteItem(String commandId);
}

/// El contenido guardado no se puede leer (versión desconocida o datos
/// dañados). Nunca se sobrescribe en silencio: borrar comandos pendientes
/// podría ocultar operaciones ya aceptadas por el backend (DDM-23).
class OutboxStoreUnreadableException extends AppException {
  const OutboxStoreUnreadableException() : super('No se pudo leer el almacén de operaciones pendientes');
}

class SecureOutboxStore implements OutboxStore {
  SecureOutboxStore(this._store);

  static const key = 'paxfide.outbox';
  static const int schemaVersion = 1;

  final SecureKeyValueStore _store;
  Future<void> _tail = Future.value();

  /// Serializa lecturas y escrituras para que dos operaciones seguidas no se pisen.
  Future<T> _locked<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Map<String, OutboxItem>> _read() async {
    final raw = await _store.read(key);
    if (raw == null) return {};
    try {
      final doc = jsonDecode(raw);
      if (doc is! Map || doc['v'] != schemaVersion || doc['items'] is! List) {
        throw const OutboxStoreUnreadableException();
      }
      final out = <String, OutboxItem>{};
      for (final j in doc['items'] as List) {
        final item = OutboxItem.fromJson(j);
        if (item == null) throw const OutboxStoreUnreadableException();
        out[item.commandId] = item;
      }
      return out;
    } on FormatException {
      throw const OutboxStoreUnreadableException();
    }
  }

  Future<void> _write(Map<String, OutboxItem> items) => _store.write(
        key,
        jsonEncode({
          'v': schemaVersion,
          'items': [for (final i in items.values) i.toJson()],
        }),
      );

  @override
  Future<List<OutboxItem>> getAllItems() => _locked(() async => (await _read()).values.toList());

  @override
  Future<List<OutboxItem>> getItemsFor(String accountId) => _locked(
        () async => (await _read()).values.where((i) => i.accountId == accountId).toList(),
      );

  @override
  Future<void> saveItem(OutboxItem item) => _locked(() async {
        final items = await _read();
        items[item.commandId] = item;
        await _write(items);
      });

  @override
  Future<void> updateStatus(String commandId, OutboxItem updatedItem) => _locked(() async {
        final items = await _read();
        if (!items.containsKey(commandId)) return;
        items[commandId] = updatedItem;
        await _write(items);
      });

  @override
  Future<void> deleteItem(String commandId) => _locked(() async {
        final items = await _read();
        if (items.remove(commandId) != null) await _write(items);
      });
}
