import '../offline/outbox_item.dart';

/// Contrato del almacenamiento seguro e íntegro del Outbox (ADR-043 D5).
///
/// Tecnología decidida (ADR-043 §0, A2): `flutter_secure_storage`, JSON
/// cifrado con un campo de versión. La implementación aún no existe.
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
