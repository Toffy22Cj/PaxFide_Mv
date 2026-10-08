import '../network/api_client.dart';
import '../network/credential_mode.dart';
import '../storage/outbox_store.dart';
import 'outbox_item.dart';
import 'outbox_status.dart';

/// Resultado de la verificación de estado para un comando ambiguo (ADR-043 D6).
enum ReconciliationResult {
  acknowledged,
  remainsAmbiguous,
}

/// El comando no se puede reconciliar por `lifecycleStatus` (D6, límite de
/// aplicabilidad): `split`, `register` u otro tipo desconocido.
class UnsupportedReconciliationException implements Exception {
  final String actionType;
  const UnsupportedReconciliationException(this.actionType);

  @override
  String toString() =>
      'UnsupportedReconciliationException: "$actionType" no se reconcilia por lifecycleStatus';
}

/// Se pidió reconciliar una entrada que no está en AMBIGUOUS.
class ReconciliationNotApplicableException implements Exception {
  final OutboxStatus status;
  const ReconciliationNotApplicableException(this.status);

  @override
  String toString() =>
      'ReconciliationNotApplicableException: solo se reconcilia AMBIGUOUS, no $status';
}

/// Ejecuta la reconciliación puntual de comandos en estado AMBIGUOUS
/// (ADR-043 D6). Se invoca solo por acción del usuario ("Verificar estado");
/// nunca por timer ni reintento automático.
///
/// LÍMITE EPISTÉMICO:
/// Demuestra que "el estado observado coincide con el esperado",
/// NO que "este commandId causó ese estado".
class AmbiguousReconciler {
  /// Estado esperado tras cada comando reconciliable. Solo estos tres efectos
  /// se reflejan en `lifecycleStatus` (D6).
  static const Map<String, String> expectedStatusByAction = {
    'DISPATCH': 'DISPATCHED',
    'RECEIVE': 'RECEIVED',
    'DELIVER': 'DELIVERED',
  };

  final ApiClient _apiClient;
  final OutboxStore _outboxStore;

  const AmbiguousReconciler({
    required ApiClient apiClient,
    required OutboxStore outboxStore,
  })  : _apiClient = apiClient,
        _outboxStore = outboxStore;

  /// Consulta el estado actual del asset y reconcilia la entrada local.
  ///
  /// El estado esperado se deriva del `actionType` de la propia entrada; el
  /// llamador no puede imponerlo.
  ///
  /// Si la consulta falla (excepción de transporte o respuesta no exitosa),
  /// la entrada no se modifica y sigue AMBIGUOUS.
  Future<ReconciliationResult> reconcile(OutboxItem item) async {
    if (item.status != OutboxStatus.ambiguous) {
      throw ReconciliationNotApplicableException(item.status);
    }
    final expected = expectedStatusByAction[item.actionType];
    if (expected == null) {
      throw UnsupportedReconciliationException(item.actionType);
    }

    // Ruta literal de api-contract-matrix.md §4b. El prefijo de versión y el
    // host los aporta la implementación de ApiClient (base URL única).
    final response = await _apiClient.get(
      '/physical-assets/${Uri.encodeComponent(item.assetRef)}',
      credentialMode: CredentialMode.jwt,
    );

    if (response.isSuccess && response.data != null) {
      final currentStatus = response.data!['lifecycleStatus'];
      if (currentStatus is String && currentStatus == expected) {
        await _outboxStore.updateStatus(
          item.commandId,
          item.copyWith(status: OutboxStatus.acknowledged),
        );
        return ReconciliationResult.acknowledged;
      }
    }

    return ReconciliationResult.remainsAmbiguous;
  }
}
