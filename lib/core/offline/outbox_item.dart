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

  /// Código HTTP del rechazo (solo en `FAILED`), para explicar el motivo sin guardar el cuerpo de la respuesta.
  final int? rejectionStatus;

  const OutboxItem({
    required this.commandId,
    required this.accountId,
    required this.kind,
    required this.resourceRef,
    required this.path,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.rejectionStatus,
  });

  OutboxItem copyWith({OutboxStatus? status, int? rejectionStatus}) {
    return OutboxItem(
      commandId: commandId,
      accountId: accountId,
      kind: kind,
      resourceRef: resourceRef,
      path: path,
      payload: payload,
      status: status ?? this.status,
      createdAt: createdAt,
      rejectionStatus: rejectionStatus ?? this.rejectionStatus,
    );
  }

  Map<String, dynamic> toJson() => {
    'commandId': commandId,
    'accountId': accountId,
    'kind': kind,
    'resourceRef': resourceRef,
    'path': path,
    'payload': payload,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'rejectionStatus': ?rejectionStatus,
  };

  /// `null` si la entrada no tiene la forma esperada.
  static OutboxItem? fromJson(Object? j) {
    if (j is! Map) return null;
    final status = OutboxStatus.values.where((s) => s.name == j['status']).firstOrNull;
    final createdAt = j['createdAt'] is String ? DateTime.tryParse(j['createdAt'] as String) : null;
    final payload = j['payload'];
    for (final k in ['commandId', 'accountId', 'kind', 'resourceRef', 'path']) {
      if (j[k] is! String || (j[k] as String).isEmpty) return null;
    }
    if (status == null || createdAt == null || payload is! Map) return null;
    return OutboxItem(
      commandId: j['commandId'] as String,
      accountId: j['accountId'] as String,
      kind: j['kind'] as String,
      resourceRef: j['resourceRef'] as String,
      path: j['path'] as String,
      payload: Map<String, dynamic>.from(payload),
      status: status,
      createdAt: createdAt,
      rejectionStatus: j['rejectionStatus'] is int ? j['rejectionStatus'] as int : null,
    );
  }
}
