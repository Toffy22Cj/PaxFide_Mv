import 'package:flutter/foundation.dart';

import '../errors/app_exceptions.dart';
import '../network/api_client.dart';
import '../network/credential_mode.dart';
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
/// - Nunca envía por su cuenta: no hay temporizadores ni reintentos automáticos. Solo [send] lo hace.
/// - `IN_FLIGHT` nunca vuelve a `PENDING`. Si la conexión no llega a abrirse, la entrada no pasa por `IN_FLIGHT`.
/// - H2: cada operación recibe el `accountId` de la sesión y solo actúa sobre entradas de esa cuenta; las demás
///   ni se ven ni se envían. Un logout no borra nada.
/// - El `commandId` lo genera la feature; este motor no crea ninguno.
class SyncEngine extends ChangeNotifier {
  SyncEngine({required this.store, required this.apiClient});

  final OutboxStore store;
  final ApiClient apiClient;
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
    final item = await _own(commandId, accountId);
    if (item.status != OutboxStatus.pending && item.status != OutboxStatus.ambiguous) {
      throw OutboxOperationNotAllowedException('No se puede enviar una operación en ${item.status.name}');
    }
    if (!_sending.add(commandId)) {
      throw const OutboxOperationNotAllowedException('La operación ya se está enviando');
    }
    try {
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
    notifyListeners();
  }
}
