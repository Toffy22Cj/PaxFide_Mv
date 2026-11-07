import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/command_outcome.dart';
import '../../../core/offline/outbox_item.dart';
import '../../../core/offline/outbox_status.dart';
import '../../../core/offline/sync_engine.dart';
import '../../../core/storage/outbox_file_store.dart';
import '../data/physical_asset_api.dart';
import 'asset_action.dart';
import 'asset_command.dart';
import '../../../core/util/command_id.dart';

/// Operaciones del operador sobre PhysicalAsset a través del Outbox (ADR-043 D6, H2).
///
/// Es el único sitio que crea entradas del Outbox y genera `Command-Id` (nunca un deep link, R3).
class AssetOperations {
  AssetOperations({required this.engine, required this.api, CommandIdGenerator? ids})
    : _ids = ids ?? CommandIdGenerator();

  final SyncEngine engine;
  final PhysicalAssetApi api;
  final CommandIdGenerator _ids;

  /// Nueva operación: entrada `PENDING` con un `commandId` nuevo, guardada antes de enviarla; luego se envía. Si no
  /// sale (sin red), se queda en la cola y se envía sola cuando vuelve la conexión (Enmienda 4 de ADR-043, S3).
  ///
  /// Entregar sin conexión (S4): con [evidencePhoto] y [evidenceUploadPath], la foto se guarda cifrada con la entrada
  /// y, al enviarse, se sube primero y su `evidenceRef` va en el cuerpo.
  Future<(OutboxItem, CommandOutcome)> submit(
    AssetCommand command, {
    required String accountId,
    OutboxFile? evidencePhoto,
    String? evidenceUploadPath,
  }) async {
    final withPhoto = evidencePhoto != null && evidenceUploadPath != null;
    final item = OutboxItem(
      commandId: _ids.next(),
      accountId: accountId,
      kind: command.action.wire,
      resourceRef: command.assetRef,
      path: command.path,
      payload: command.body,
      status: OutboxStatus.pending,
      createdAt: DateTime.now().toUtc(),
      fileUploadPath: withPhoto ? evidenceUploadPath : null,
      fileResultKey: withPhoto ? 'evidenceRef' : null,
    );
    if (withPhoto) {
      final files = engine.files;
      if (files == null) throw const OutboxOperationNotAllowedException('Sin almacén para la foto');
      await files.save(item.commandId, evidencePhoto);
    }
    await engine.enqueue(item);
    final outcome = await engine.send(item.commandId, accountId);
    return (item, outcome);
  }

  /// "Verificar estado": `GET /physical-assets/{assetRef}`; `lifecycleStatus` esperado → `ACKNOWLEDGED`.
  /// LÍMITE EPISTÉMICO: el estado observado coincide con el esperado; no prueba que este `commandId` lo causara.
  Future<bool> verify(OutboxItem item, {required String accountId}) =>
      engine.verify(item.commandId, accountId, (i) async {
        final expected = AssetAction.fromWire(i.kind)?.expectedStatusAfter;
        if (expected == null) return false;
        try {
          return (await api.get(i.resourceRef)).lifecycleStatus == expected.wire;
        } on AppException {
          return false; // sin poder leer, sigue AMBIGUOUS
        }
      });
}
