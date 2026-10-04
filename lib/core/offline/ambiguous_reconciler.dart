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

/// Ejecuta la reconciliación puntual de comandos en estado AMBIGUOUS (ADR-043 D6).
///
/// LÍMITE EPISTÉMICO:
/// Demuestra que "el estado observado coincide con el esperado",
/// NO que "este commandId causó ese estado".
class AmbiguousReconciler {
  final ApiClient _apiClient;
  final OutboxStore _outboxStore;

  const AmbiguousReconciler({
    required ApiClient apiClient,
    required OutboxStore outboxStore,
  })  : _apiClient = apiClient,
        _outboxStore = outboxStore;

  /// Consulta el estado actual del asset en backend y reconcilia la entrada local.
  Future<ReconciliationResult> reconcile({
    required OutboxItem item,
    required String expectedLifecycleStatus,
  }) async {
    final response = await _apiClient.get(
      '/physical-assets/${item.assetRef}',
      credentialMode: CredentialMode.jwt,
    );

    if (response.isSuccess && response.data != null) {
      final currentStatus = response.data!['lifecycleStatus'] as String?;

      if (currentStatus == expectedLifecycleStatus) {
        final ackItem = item.copyWith(status: OutboxStatus.acknowledged);
        await _outboxStore.updateStatus(item.commandId, ackItem);
        return ReconciliationResult.acknowledged;
      }
    }

    return ReconciliationResult.remainsAmbiguous;
  }
}