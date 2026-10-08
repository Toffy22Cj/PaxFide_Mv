import 'package:flutter/material.dart';

import '../../../core/offline/outbox_item.dart';
import '../../../core/offline/outbox_status.dart';
import '../domain/asset_action.dart';
import 'command_form_sheet.dart';

String kindLabel(String kind) {
  final a = AssetAction.fromWire(kind);
  return a == null ? kind : actionLabel(a);
}

String rejectionReason(int? status) => switch (status) {
      403 => 'Tu cuenta no puede hacer esta operación con este activo.',
      409 => 'El estado del activo ya no la permite.',
      401 => 'Tu sesión terminó antes de enviarla.',
      _ => 'Revisa los datos y, si hace falta, haz una operación nueva.',
    };

/// Una entrada del Outbox con sus salidas (ADR-043 D6/§7). `AMBIGUOUS`: "no
/// pudimos confirmar", con "Verificar estado" como acción primaria antes que
/// "Reintentar". Es un estado de sincronización, no un `lifecycleStatus`.
class OutboxEntryCard extends StatelessWidget {
  const OutboxEntryCard({
    super.key,
    required this.item,
    required this.busy,
    this.showAsset = false,
    this.onSend,
    this.onVerify,
    this.onRetrySame,
    this.onDiscard,
    this.onNewOperation,
    this.onOpenAsset,
  });

  final OutboxItem item;
  final bool busy;
  final bool showAsset;
  final VoidCallback? onSend;
  final VoidCallback? onVerify;
  final VoidCallback? onRetrySame;
  final VoidCallback? onDiscard;
  final VoidCallback? onNewOperation;
  final VoidCallback? onOpenAsset;

  @override
  Widget build(BuildContext context) {
    final label = kindLabel(item.kind);
    final title = showAsset ? '$label · activo ${item.resourceRef}' : label;
    final (IconData icon, String state, String detail, List<Widget> actions) = switch (item.status) {
      OutboxStatus.pending => (
          Icons.schedule,
          'Pendiente de enviar',
          'Guardada en este dispositivo. No se ha enviado.',
          [
            FilledButton(
              key: Key('outbox-send-${item.commandId}'),
              onPressed: busy ? null : onSend,
              child: const Text('Enviar'),
            ),
          ],
        ),
      OutboxStatus.inFlight => (Icons.sync, 'Enviando…', 'Esperando la respuesta del servidor.', <Widget>[]),
      OutboxStatus.ambiguous => (
          Icons.help_outline,
          'No pudimos confirmar la operación',
          'Puede que el servidor la haya registrado. Verifica el estado antes de reintentar.',
          [
            FilledButton(
              key: Key('outbox-verify-${item.commandId}'),
              onPressed: busy ? null : onVerify,
              child: const Text('Verificar estado'),
            ),
            TextButton(
              key: Key('outbox-retry-${item.commandId}'),
              onPressed: busy ? null : onRetrySame,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      OutboxStatus.failed => (
          Icons.block,
          'El servidor la rechazó',
          rejectionReason(item.rejectionStatus),
          [
            if (onNewOperation != null)
              TextButton(onPressed: busy ? null : onNewOperation, child: const Text('Nueva operación')),
            TextButton(
              key: Key('outbox-discard-${item.commandId}'),
              onPressed: busy ? null : onDiscard,
              child: const Text('Descartar'),
            ),
          ],
        ),
      OutboxStatus.acknowledged => (Icons.check_circle, 'Confirmada', '', <Widget>[]),
    };
    return Card(
      key: Key('outbox-entry-${item.commandId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text('$state\n$detail'),
            isThreeLine: true,
            onTap: onOpenAsset,
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: OverflowBar(alignment: MainAxisAlignment.end, spacing: 8, children: actions),
            ),
        ],
      ),
    );
  }
}

/// Confirmación antes de descartar (ADR-043 §0 A1; solo `FAILED`, DDM-21).
Future<bool> confirmDiscard(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Descartar la operación?'),
        content: const Text('El servidor ya la rechazó. Se borrará de este dispositivo y no se enviará nada.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancelar')),
          FilledButton(
            key: const Key('discard-confirm'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    ) ??
    false;
