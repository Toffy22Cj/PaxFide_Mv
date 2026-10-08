import 'package:flutter/material.dart';

import '../../../core/offline/outbox_item.dart';
import '../../../core/offline/outbox_status.dart';
import '../../../shared/labels.dart';
import '../../../shared/theme/pax_theme.dart';
import '../domain/asset_action.dart';
import 'command_form_sheet.dart';

String kindLabel(String kind) {
  final a = AssetAction.fromWire(kind);
  return a == null ? kind : actionLabel(a);
}

String rejectionReason(int? status) => switch (status) {
      403 => 'Tu cuenta no puede registrar este paso.',
      409 => 'Este paso ya no corresponde: alguien más pudo haberlo registrado. Revisa el estado del envío.',
      401 => 'Tu sesión terminó antes de enviarlo. Vuelve a entrar.',
      _ => 'Revisa los datos e inténtalo de nuevo.',
    };

/// Un paso guardado en el teléfono con sus salidas (ADR-043 D6/§7). Si no
/// se sabe si llegó (`AMBIGUOUS`), lo primero es "Comprobar", antes que
/// "Enviar otra vez".
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
    final p = PaxPalette.of(context);
    final label = kindLabel(item.kind);
    final (IconData icon, Color color, String state, String detail, List<Widget> actions) = switch (item.status) {
      OutboxStatus.pending => (
          Icons.schedule,
          const Color(0xFF38BDF8),
          'Guardado sin enviar',
          'Está en este teléfono. Envíalo cuando tengas conexión.',
          [
            FilledButton(
              key: Key('outbox-send-${item.commandId}'),
              onPressed: busy ? null : onSend,
              child: const Text('Enviar'),
            ),
          ],
        ),
      OutboxStatus.inFlight => (Icons.sync, const Color(0xFF38BDF8), 'Enviando…', 'Esperando respuesta.', <Widget>[]),
      OutboxStatus.ambiguous => (
          Icons.help_outline,
          const Color(0xFFF59E0B),
          'No sabemos si se registró',
          'Se cortó la conexión. Toca "Comprobar" para revisar si quedó registrado antes de enviarlo otra vez.',
          [
            FilledButton(
              key: Key('outbox-verify-${item.commandId}'),
              onPressed: busy ? null : onVerify,
              child: const Text('Comprobar'),
            ),
            TextButton(
              key: Key('outbox-retry-${item.commandId}'),
              onPressed: busy ? null : onRetrySame,
              child: const Text('Enviar otra vez'),
            ),
          ],
        ),
      OutboxStatus.failed => (
          Icons.block,
          const Color(0xFFEF4444),
          'No se pudo registrar',
          rejectionReason(item.rejectionStatus),
          [
            if (onNewOperation != null)
              TextButton(onPressed: busy ? null : onNewOperation, child: const Text('Intentar de nuevo')),
            TextButton(
              key: Key('outbox-discard-${item.commandId}'),
              onPressed: busy ? null : onDiscard,
              child: const Text('Borrar'),
            ),
          ],
        ),
      OutboxStatus.acknowledged => (Icons.check_circle, paxAccent, 'Registrado', '', <Widget>[]),
    };
    return Container(
      key: Key('outbox-entry-${item.commandId}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenAsset,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('$label · $state', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: p.text)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(detail, style: TextStyle(fontSize: 12.5, color: p.textMuted, height: 1.4)),
              if (showAsset)
                Text('Guardado el ${dateTime(item.createdAt.toIso8601String())}',
                    style: TextStyle(fontSize: 11.5, color: p.textMuted)),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmación antes de borrar (ADR-043 §0 A1; solo los rechazados, DDM-21).
Future<bool> confirmDiscard(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Borrar este paso?'),
        content: const Text('No se pudo registrar, así que no hay nada que deshacer. Solo se borrará de este teléfono.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancelar')),
          FilledButton(
            key: const Key('discard-confirm'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    ) ??
    false;
