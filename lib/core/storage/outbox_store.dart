import '../offline/outbox_item.dart';

/// Contrato abstracto para el almacenamiento seguro e íntegro del Outbox (ADR-043 D5, D12).
///
/// La tecnología de implementación sigue PENDIENTE según D12
/// y requiere enmienda formal previa antes de añadirse a pubspec.yaml.
abstract class OutboxStore {
  Future<List<OutboxItem>> getAllItems();
  Future<void> saveItem(OutboxItem item);
  Future<void> updateStatus(String commandId, OutboxItem updatedItem);
  Future<void> deleteItem(String commandId);
}
