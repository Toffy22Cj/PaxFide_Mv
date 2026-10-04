import '../storage/outbox_store.dart';
import 'outbox_status.dart';

/// Gestiona la recuperación del Outbox durante el arranque de la app (ADR-043 D6).
class OutboxRecovery {
  final OutboxStore _store;

  const OutboxRecovery(this._store);

  /// Ejecuta la Regla T-2:
  /// Al arrancar, toda entrada persistida en `inFlight` pasa obligatoriamente a `ambiguous`.
  /// INVARIANTE: `inFlight` NUNCA vuelve a `pending` de forma automática.
  Future<void> executeRecoveryT2() async {
    final items = await _store.getAllItems();

    for (final item in items) {
      if (item.status == OutboxStatus.inFlight) {
        final ambiguousItem = item.copyWith(status: OutboxStatus.ambiguous);
        await _store.updateStatus(item.commandId, ambiguousItem);
      }
    }
  }
}