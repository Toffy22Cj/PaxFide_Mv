import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/command_outcome.dart';
import '../../../core/offline/outbox_item.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/error_message.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../domain/asset_action.dart';
import '../domain/asset_command.dart';
import '../domain/asset_operations.dart';
import 'command_form_sheet.dart';
import 'outbox_entry_card.dart';

/// Etiquetas de los campos de referencia. Nunca piden nombres ni documentos.
const fieldLabels = {
  'carrierRef': 'Referencia del transportista',
  'facilityLocation': 'Referencia del lugar de recepción',
  'receiverRef': 'Referencia de quien recibe',
};

/// Aviso fijo bajo cada campo: lo escrito termina en un registro que no se puede borrar.
const referenceWarning = 'Escribe un código o referencia, nunca un nombre ni un número de documento.';

enum _Step { form, review, result }

/// Toda acción de campo (E-04 → E-05 → E-06), una sola hoja parametrizada por [action]: formulario, revisión
/// ("Esto queda registrado para siempre") y resultado (Confirmado / Guardado en el teléfono / No pudimos
/// confirmarlo). Pantalla completa transitoria (Figma 04): no es una ruta (§12). Devuelve el resultado del envío, o
/// null si se cerró antes.
Future<CommandOutcome?> runFieldAction(
  BuildContext context, {
  required AssetAction action,
  required String assetRef,
  required AssetOperations operations,
  required String accountId,
}) {
  return Navigator.of(context).push<CommandOutcome>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FieldActionFlow(action: action, assetRef: assetRef, ops: operations, accountId: accountId),
    ),
  );
}

class _FieldActionFlow extends StatefulWidget {
  const _FieldActionFlow({required this.action, required this.assetRef, required this.ops, required this.accountId});
  final AssetAction action;
  final String assetRef;
  final AssetOperations ops;
  final String accountId;

  @override
  State<_FieldActionFlow> createState() => _FieldActionFlowState();
}

class _FieldActionFlowState extends State<_FieldActionFlow> {
  late final Map<String, TextEditingController> _controllers = {
    for (final f in AssetCommand.fields[widget.action]!) f.key: TextEditingController(),
  };
  late final AppServices _services = AppScope.of(context);
  final _invalid = <String>{};
  _Step _step = _Step.form;
  AssetCommand? _command;
  OutboxItem? _item;
  CommandOutcome? _outcome;
  bool _busy = false;
  bool _registered = false;
  String? _error;

  bool get _dirty => _step == _Step.form && _controllers.values.any((c) => c.text.isNotEmpty);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_registered) {
      _registered = true;
      _services.router.setLeaveConfirmation(_confirmLeave);
    }
  }

  /// Con datos escritos, un enlace entrante pide confirmación antes de descartarlos (§11, opción ii).
  Future<bool> _confirmLeave() async {
    if (!_dirty || !mounted) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Salir sin enviar?'),
        content: const Text('Se abrió un enlace. Si sales, se pierden los datos escritos.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Seguir aquí')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Salir')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
    return leave == true;
  }

  @override
  void dispose() {
    _services.router.setLeaveConfirmation(null);
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toReview() {
    final errors = <String>[];
    final cmd = AssetCommand.build(widget.action, widget.assetRef, {
      for (final e in _controllers.entries) e.key: e.value.text,
    }, errors: errors);
    setState(() {
      _invalid
        ..clear()
        ..addAll(errors);
      if (cmd != null) {
        _command = cmd;
        _step = _Step.review;
      }
    });
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (item, outcome) = await widget.ops.submit(_command!, accountId: widget.accountId);
      if (!mounted) return;
      setState(() {
        _item = item;
        _outcome = outcome;
        _step = _Step.result;
      });
    } on AppException catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final ok = await widget.ops.verify(_item!, accountId: widget.accountId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _outcome = CommandOutcome.acknowledged;
    });
    if (!ok) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Todavía no podemos confirmarla. Inténtalo de nuevo en un momento.')),
      );
    }
  }

  /// La X: con datos escritos pide confirmación; en la revisión o el resultado cierra sin más.
  Future<void> _close() async {
    if (_busy) return;
    if (!_dirty) {
      Navigator.of(context).pop(_outcome);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Salir sin enviar?'),
        content: const Text('Los datos escritos no se enviarán. La operación todavía no queda registrada.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Salir sin enviar')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy && !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            key: const Key('form.close'),
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
          title: Text('${actionLabel(widget.action)} · ${widget.assetRef}', overflow: TextOverflow.ellipsis),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: switch (_step) {
              _Step.form => _form(context),
              _Step.review => _review(context),
              _Step.result => _result(context),
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _header(BuildContext context, String overline, String title) => [
    Overline(overline),
    const SizedBox(height: 6),
    Text(widget.assetRef, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
    const SizedBox(height: 6),
    Text(title, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 16),
  ];

  List<Widget> _form(BuildContext context) => [
    ..._header(context, 'Paso 1 de 2 / Datos', 'Datos de la operación'),
    for (final f in AssetCommand.fields[widget.action]!) ...[
      LabeledField(
        label: fieldLabels[f.key] ?? f.label,
        child: TextField(
          key: Key('form.${f.key}'),
          controller: _controllers[f.key],
          maxLength: AssetCommand.maxLength,
          decoration: InputDecoration(
            counterText: '',
            helperText: referenceWarning,
            helperMaxLines: 2,
            errorText: _invalid.contains(f.key)
                ? 'Escribe la referencia (máximo ${AssetCommand.maxLength} caracteres)'
                : null,
          ),
        ),
      ),
      const SizedBox(height: 14),
    ],
    const SizedBox(height: 4),
    FilledButton(key: const Key('form.submit'), onPressed: _toReview, child: const Text('Revisar operación')),
  ];

  List<Widget> _review(BuildContext context) {
    final cmd = _command!;
    return [
      ..._header(context, 'Paso 2 de 2 / Revisión', 'Revisa antes de enviar'),
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledValue('Acción', actionLabel(widget.action)),
            for (final e in cmd.values.entries) LabeledValue(fieldLabels[e.key] ?? e.key, e.value, mono: true),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const NoticeBanner('Esto queda registrado para siempre.', textKey: Key('review.permanent')),
      if (_error != null) ...[const SizedBox(height: 12), ErrorMessage(_error!)],
      const SizedBox(height: 16),
      FilledButton(
        key: const Key('review.confirm'),
        onPressed: _busy ? null : _confirm,
        child: _busy
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Confirmar y enviar'),
      ),
      TextButton(
        key: const Key('review.edit'),
        onPressed: _busy ? null : () => setState(() => _step = _Step.form),
        child: const Text('Volver'),
      ),
    ];
  }

  List<Widget> _result(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, title, detail, bg, fg) = switch (_outcome!) {
      CommandOutcome.acknowledged => (
        Icons.check_circle,
        'Confirmado',
        'La operación quedó registrada.',
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      CommandOutcome.notSent => (
        Icons.save_alt,
        'Guardado en el teléfono',
        'No hay conexión. La operación quedó guardada; envíala desde Pendientes cuando vuelvas a tener señal.',
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      CommandOutcome.ambiguous => (
        Icons.help_outline,
        'No pudimos confirmarlo',
        'Puede que haya quedado registrada. Verifica el estado; no la vuelvas a enviar.',
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      CommandOutcome.failed => (
        Icons.block,
        'No se pudo registrar',
        rejectionReason(_item?.rejectionStatus),
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    };
    return [
      // Se anuncia en el lector de pantalla en cuanto aparece (M-04).
      Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          key: Key('result.${_outcome!.name}'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Icon(icon, size: 48, color: fg),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: fg)),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: TextStyle(color: fg),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (_outcome == CommandOutcome.ambiguous)
        FilledButton(
          key: const Key('result.verify'),
          onPressed: _busy ? null : _verify,
          child: const Text('Verificar estado'),
        ),
      if (_outcome == CommandOutcome.notSent || _outcome == CommandOutcome.ambiguous)
        TextButton(
          key: const Key('result.pending'),
          onPressed: () {
            Navigator.of(context).pop(_outcome);
            _services.router.push(AppRoutes.operatorPending);
          },
          child: const Text('Ir a Pendientes'),
        ),
      TextButton(
        key: const Key('result.close'),
        onPressed: () => Navigator.of(context).pop(_outcome),
        child: const Text('Listo'),
      ),
    ];
  }
}
