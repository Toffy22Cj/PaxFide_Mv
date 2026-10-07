import 'outbox_status.dart';

/// Operación encolada localmente en el Outbox (ADR-043 D6).
///
/// Genérica: `core` no conoce el dominio. La feature que crea la entrada fija `kind` (p. ej. `DISPATCH`),
/// `resourceRef` (p. ej. el `assetRef`), la ruta y el cuerpo.
///
/// H2 (ADR-043 §0 A1): `accountId` es la cuenta que creó la entrada. Una cuenta distinta nunca la envía ni la ve.
class OutboxItem {
  final String commandId;
  final String accountId;
  final String kind;
  final String resourceRef;
  final String path;
  final Map<String, dynamic> payload;
  final OutboxStatus status;
  final DateTime createdAt;

  const OutboxItem({
    required this.commandId,
    required this.accountId,
    required this.kind,
    required this.resourceRef,
    required this.path,
    required this.payload,
    required this.status,
    required this.createdAt,
  });

  OutboxItem copyWith({OutboxStatus? status}) {
    return OutboxItem(
      commandId: commandId,
      accountId: accountId,
      kind: kind,
      resourceRef: resourceRef,
      path: path,
      payload: payload,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
