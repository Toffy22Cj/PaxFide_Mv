import 'package:flutter/foundation.dart';

import '../errors/app_exceptions.dart';
import '../network/api_client.dart';
import '../network/credential_mode.dart';
import '../network/api_response.dart';
import '../storage/outbox_file_store.dart';
import '../storage/outbox_store.dart';
import 'command_outcome.dart';
import 'outbox_item.dart';
import 'outbox_status.dart';

/// Operación del Outbox no permitida por la máquina de estados o por H2.
class OutboxOperationNotAllowedException extends AppException {
  const OutboxOperationNotAllowedException(super.message);
}

/// `SyncEngine` + Outbox (ADR-043 D6 con H2 de la §0).
///
/// | Estado | Salidas |
/// |---|---|
/// | `PENDING` | → `IN_FLIGHT` cuando la petición sale (acción explícita del operador) |
/// | `IN_FLIGHT` | → `ACKNOWLEDGED` / `FAILED` (4xx) / `AMBIGUOUS` (timeout, corte, 5xx); al arrancar → `AMBIGUOUS` (T-2) |
/// | `AMBIGUOUS` | → `ACKNOWLEDGED` vía "Verificar estado" / reintento **manual** con el **mismo** `commandId` |
/// | `FAILED` | → Descartar (con confirmación en la UI) / Nueva operación (otra entrada, otro `commandId`) |
/// | `ACKNOWLEDGED` | terminal: se retira |
///
/// Invariantes:
/// - Solo [send] envía. [sendAll] lo llama el envío automático (`AutoSync`, Enmienda 4 de ADR-043, S3) cuando hay
///   red, con el mismo `commandId` de cada entrada.
/// - `IN_FLIGHT` nunca vuelve a `PENDING`. Si la conexión no llega a abrirse, la entrada no pasa por `IN_FLIGHT`.
/// - H2: cada operación recibe el `accountId` de la sesión y solo actúa sobre entradas de esa cuenta; las demás
///   ni se ven ni se envían. Un logout no borra nada.
/// - El `commandId` lo genera la feature; este motor no crea ninguno.
class SyncEngine extends ChangeNotifier {
  SyncEngine({required this.store, required this.apiClient, this.files});

  final OutboxStore store;
  final ApiClient apiClient;

  /// Archivos que algunas entradas suben antes de enviarse (S4). Sin él, esas entradas no salen.
  final OutboxFileStore? files;
  final Set<String> _sending = {};

  /// Entradas visibles para [accountId], de la más reciente a la más antigua. Las `ACKNOWLEDGED` no se listan.
  Future<List<OutboxItem>> entriesFor(String accountId) async {
    final all = await store.getAllItems();
    return all.where((i) => i.accountId == accountId && i.status != OutboxStatus.acknowledged).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<OutboxItem> _own(String commandId, String accountId) async {
    final all = await store.getAllItems();
    final item = all.where((i) => i.commandId == commandId).firstOrNull;
    // Una entrada de otra cuenta se trata igual que una inexistente (H2: ni se ve).
    if (item == null || item.accountId != accountId) {
      throw const OutboxOperationNotAllowedException('La operación no existe para esta cuenta');
    }
    return item;
  }

  /// Guarda una operación nueva en `PENDING` (antes de enviarla: si la app muere, no se pierde).
  Future<void> enqueue(OutboxItem item) async {
    if (item.status != OutboxStatus.pending) {
      throw const OutboxOperationNotAllowedException('Una operación nueva empieza en PENDING');
    }
    final all = await store.getAllItems();
    if (all.any((i) => i.commandId == item.commandId)) {
      throw const OutboxOperationNotAllowedException('commandId repetido');
    }
    await store.saveItem(item);
    notifyListeners();
  }

  /// Envío explícito: `PENDING` o reintento manual de `AMBIGUOUS` con el **mismo** `commandId`.
  /// `FAILED`, `IN_FLIGHT` y `ACKNOWLEDGED` no se envían.
  Future<CommandOutcome> send(String commandId, String accountId) async {
    final first = await _own(commandId, accountId);
    if (first.status != OutboxStatus.pending && first.status != OutboxStatus.ambiguous) {
      throw OutboxOperationNotAllowedException('No se puede enviar una operación en ${first.status.name}');
    }
    if (!_sending.add(commandId)) {
      throw const OutboxOperationNotAllowedException('La operación ya se está enviando');
    }
    try {
      // S4: primero el archivo (la foto de una entrega hecha sin conexión). Subirlo otra vez es seguro: los mismos
      // bytes dan el mismo resultado (ADR-051 F9). Sin red, o sin archivo legible, la entrada no sale.
      var item = first;
      if (item.fileUploadPath != null) {
        final uploaded = await _uploadFile(item, accountId);
        if (uploaded == null) {
          return (await store.getAllItems()).any((i) => i.commandId == commandId && i.status == OutboxStatus.failed)
              ? CommandOutcome.failed
              : CommandOutcome.notSent;
        }
        item = uploaded;
      }
      CommandOutcome outcome;
      int? status;
      try {
        final r = await apiClient.post(
          item.path,
          body: item.payload,
          headers: {'Command-Id': item.commandId},
          credentialMode: CredentialMode.jwt,
          beforeSend: () async {
            // La conexión está abierta: a partir de aquí el resultado puede ser desconocido.
            await store.updateStatus(commandId, item.copyWith(status: OutboxStatus.inFlight));
            notifyListeners();
          },
        );
        outcome = classifyResponse(r);
        status = r.statusCode;
      } on TransportException catch (e) {
        outcome = classifyTransport(e);
      }

      switch (outcome) {
        case CommandOutcome.acknowledged:
          await store.deleteItem(commandId); // terminal: se retira
        case CommandOutcome.failed:
          await store.updateStatus(commandId, item.copyWith(status: OutboxStatus.failed, rejectionStatus: status));
        case CommandOutcome.ambiguous:
          await store.updateStatus(commandId, item.copyWith(status: OutboxStatus.ambiguous));
        case CommandOutcome.notSent:
          // No salió: conserva su estado (PENDING sigue PENDING; AMBIGUOUS sigue AMBIGUOUS).
          await store.updateStatus(commandId, item);
      }
      return outcome;
    } finally {
      _sending.remove(commandId);
      notifyListeners();
    }
  }

  /// Sube el archivo de [item] y guarda la entrada con el resultado en el cuerpo (y el archivo borrado). `null` si no
  /// salió (sin red, fallo ambiguo o 5xx: se reintenta luego) o si el servidor lo rechazó (4xx: la entrada pasa a
  /// `FAILED` y el archivo se borra, porque ya no sirve).
  Future<OutboxItem?> _uploadFile(OutboxItem item, String accountId) async {
    final file = await files?.read(item.commandId);
    if (file == null) return null;
    final ApiResponse r;
    try {
      r = await apiClient.postFile(
        item.fileUploadPath!,
        field: 'file',
        filename: file.filename,
        contentType: file.contentType,
        bytes: file.bytes,
        credentialMode: CredentialMode.jwt,
      );
    } on TransportException {
      return null;
    }
    final result = r.data?[item.fileResultKey];
    if (r.isSuccess && result is String && result.isNotEmpty) {
      final next = item.withUploadedFile(result);
      await store.updateStatus(item.commandId, next);
      await files?.delete(item.commandId);
      notifyListeners();
      return next;
    }
    if (r.statusCode >= 400 && r.statusCode < 500) {
      await store.updateStatus(
        item.commandId,
        item.copyWith(status: OutboxStatus.failed, rejectionStatus: r.statusCode),
      );
      await files?.delete(item.commandId);
      notifyListeners();
    }
    return null;
  }

  /// Envío automático (Enmienda 4 de ADR-043, S3): manda, de la más antigua a la más reciente, las entradas de
  /// [accountId] en `PENDING` o `AMBIGUOUS`, cada una con su **mismo** `commandId` (el backend responde igual a un
  /// reenvío y no duplica). Se detiene en cuanto una no sale (sin red). `FAILED` no se toca: espera a la persona.
  /// Devuelve cuántas quedaron confirmadas.
  Future<int> sendAll(String accountId) async {
    final List<OutboxItem> due;
    try {
      due =
          (await entriesFor(accountId))
              .where((i) => i.status == OutboxStatus.pending || i.status == OutboxStatus.ambiguous)
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } on AppException {
      return 0; // almacén ilegible: no se toca (lo muestra Pendientes)
    }
    var acknowledged = 0;
    for (final item in due) {
      if (_sending.contains(item.commandId)) continue;
      final CommandOutcome outcome;
      try {
        outcome = await send(item.commandId, accountId);
      } on OutboxOperationNotAllowedException {
        continue; // cambió de estado mientras tanto
      }
      if (outcome == CommandOutcome.notSent) break;
      if (outcome == CommandOutcome.acknowledged) acknowledged++;
    }
    return acknowledged;
  }

  /// "Verificar estado" de una entrada `AMBIGUOUS`. [observedMatchesExpected] es la comprobación de la feature
  /// (p. ej. `lifecycleStatus` esperado). Si coincide → `ACKNOWLEDGED`; si no, sigue `AMBIGUOUS`. Nunca reenvía.
  Future<bool> verify(
    String commandId,
    String accountId,
    Future<bool> Function(OutboxItem item) observedMatchesExpected,
  ) async {
    final item = await _own(commandId, accountId);
    if (item.status != OutboxStatus.ambiguous) {
      throw const OutboxOperationNotAllowedException('Solo se verifica una operación AMBIGUOUS');
    }
    final ok = await observedMatchesExpected(item);
    if (ok) {
      await store.deleteItem(commandId);
      notifyListeners();
    }
    return ok;
  }

  /// Descartar: solo `FAILED` (el backend ya la rechazó; no hay nada que revertir). No envía nada.
  /// La UI pide confirmación antes de llamar.
  Future<void> discard(String commandId, String accountId) async {
    final item = await _own(commandId, accountId);
    if (item.status != OutboxStatus.failed) {
      throw const OutboxOperationNotAllowedException('Solo se descarta una operación rechazada');
    }
    await store.deleteItem(commandId);
    await files?.delete(commandId);
    notifyListeners();
  }
}
