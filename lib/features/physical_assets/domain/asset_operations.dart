import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/command_outcome.dart';
import '../../../core/offline/outbox_item.dart';
import '../../../core/offline/outbox_status.dart';
import '../../../core/offline/sync_engine.dart';
import '../data/physical_asset_api.dart';
import 'asset_action.dart';
import 'asset_command.dart';
import 'command_id.dart';

/// Operaciones del operador sobre PhysicalAsset a través del Outbox (ADR-043 D6, H2).
///
/// Es el único sitio que crea entradas del Outbox y genera `Command-Id` (nunca un deep link, R3).
class AssetOperations {
  AssetOperations({required this.engine, required this.api, CommandIdGenerator? ids})
    : _ids = ids ?? CommandIdGenerator();

  final SyncEngine engine;
  final PhysicalAssetApi api;
  final CommandIdGenerator _ids;

  /// Nueva operación: entrada `PENDING` con un `commandId` nuevo, guardada antes de enviarla; luego se envía.
  Future<(OutboxItem, CommandOutcome)> submit(AssetCommand command, {required String accountId}) async {
    final item = OutboxItem(
      commandId: _ids.next(),
      accountId: accountId,
      kind: command.action.wire,
      resourceRef: command.assetRef,
      path: command.path,
      payload: command.body,
      status: OutboxStatus.pending,
      createdAt: DateTime.now().toUtc(),
    );
    await engine.enqueue(item);
    return (item, await engine.send(item.commandId, accountId));
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
