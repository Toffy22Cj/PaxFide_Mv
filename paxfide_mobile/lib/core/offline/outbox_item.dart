import 'outbox_status.dart';

/// Representa una operación encolada localmente en el Outbox (ADR-043 D6).
///
/// [accountId] es la cuenta que la creó (ADR-043 §0, A1): ninguna otra cuenta
/// la ve, la envía ni la reconcilia.
class OutboxItem {
  final String commandId;
  final String accountId;
  final String assetRef;
  final String actionType; // DISPATCH, RECEIVE, DELIVER
  final Map<String, dynamic> payload;
  final OutboxStatus status;
  final DateTime createdAt;

  const OutboxItem({
    required this.commandId,
    required this.accountId,
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
      accountId: accountId,
      assetRef: assetRef,
      actionType: actionType,
      payload: payload,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}