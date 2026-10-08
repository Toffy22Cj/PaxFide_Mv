import 'outbox_status.dart';

/// Representa una operación encolada localmente en el Outbox (ADR-043 D6).
class OutboxItem {
  final String commandId;
  final String assetRef;
  final String actionType; // DISPATCH, RECEIVE, DELIVER
  final Map<String, dynamic> payload;
  final OutboxStatus status;
  final DateTime createdAt;

  const OutboxItem({
    required this.commandId,
    required this.assetRef,
    required this.actionType,
    required this.payload,
    required this.status,
    required this.createdAt,
  });

  OutboxItem copyWith({
    OutboxStatus? status,
  }) {
    return OutboxItem(
      commandId: commandId,
      assetRef: assetRef,
      actionType: actionType,
      payload: payload,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}