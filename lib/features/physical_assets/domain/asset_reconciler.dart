import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';
import '../../../core/offline/outbox_item.dart';
import '../../../core/offline/outbox_status.dart';
import '../../../core/storage/outbox_store.dart';
import 'asset_action.dart';

/// Resultado de "Verificar estado" para una entrada `AMBIGUOUS` (ADR-043 D6).
enum ReconciliationResult { acknowledged, remainsAmbiguous }

/// Reconciliación de comandos `AMBIGUOUS` de PhysicalAsset (ADR-043 D6). Vive en la feature (D2): conoce la ruta
/// `GET /physical-assets/{assetRef}` y el campo `lifecycleStatus`, que son de este dominio.
///
/// LÍMITE EPISTÉMICO: demuestra que "el estado observado coincide con el esperado", NO que "este commandId causó
/// ese estado".
class AssetReconciler {
  final ApiClient apiClient;
  final OutboxStore outboxStore;

  const AssetReconciler({required this.apiClient, required this.outboxStore});

  Future<ReconciliationResult> reconcile(OutboxItem item) async {
    final expected = AssetAction.fromWire(item.kind)?.expectedStatusAfter;
    if (item.status != OutboxStatus.ambiguous || expected == null) {
      return ReconciliationResult.remainsAmbiguous;
    }

    final response = await apiClient.get(
      '/physical-assets/${Uri.encodeComponent(item.resourceRef)}',
      credentialMode: CredentialMode.jwt,
    );

    if (response.isSuccess && response.data?['lifecycleStatus'] == expected.wire) {
      await outboxStore.updateStatus(item.commandId, item.copyWith(status: OutboxStatus.acknowledged));
      return ReconciliationResult.acknowledged;
    }
    return ReconciliationResult.remainsAmbiguous;
  }
}
