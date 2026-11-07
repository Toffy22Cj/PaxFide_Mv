import 'dart:convert';

import 'secure_key_value_store.dart';

/// Un archivo que una entrada de la cola tiene que subir antes de enviarse (Enmienda 4 de ADR-043, S4: la foto de una
/// entrega hecha sin conexión).
class OutboxFile {
  const OutboxFile({required this.bytes, required this.contentType, required this.filename});
  final List<int> bytes;
  final String contentType;
  final String filename;
}

/// Los archivos de la cola, cifrados en el almacén seguro (D5/D12), uno por `commandId`. Se borran al subirse o al
/// descartarse la entrada.
class OutboxFileStore {
  const OutboxFileStore(this._store);

  static const prefix = 'paxfide.outbox.file.';

  final SecureKeyValueStore _store;

  Future<void> save(String commandId, OutboxFile file) => _store.write(
    '$prefix$commandId',
    jsonEncode({'contentType': file.contentType, 'filename': file.filename, 'bytes': base64Encode(file.bytes)}),
  );

  Future<OutboxFile?> read(String commandId) async {
    try {
      final raw = await _store.read('$prefix$commandId');
      final j = raw == null ? null : jsonDecode(raw);
      if (j is! Map || j['bytes'] is! String || j['contentType'] is! String || j['filename'] is! String) return null;
      return OutboxFile(
        bytes: base64Decode(j['bytes'] as String),
        contentType: j['contentType'] as String,
        filename: j['filename'] as String,
      );
    } on Object {
      return null;
    }
  }

  Future<void> delete(String commandId) => _store.delete('$prefix$commandId');
}
