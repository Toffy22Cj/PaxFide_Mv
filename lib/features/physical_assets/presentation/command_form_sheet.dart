import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../domain/asset_action.dart';
import '../domain/asset_command.dart';

String actionLabel(AssetAction a) => switch (a) {
  AssetAction.dispatch => 'Despachar',
  AssetAction.receive => 'Recibir',
  AssetAction.deliver => 'Entregar',
  AssetAction.readOnly => 'Solo lectura',
};

/// Formulario de comando: transitorio sobre `AssetScreen` (hoja), nunca una ruta ni restaurable (§12 regla 2).
/// Con cambios sin enviar, un deep link entrante pide confirmación (§11, opción ii).
Future<AssetCommand?> showCommandForm(BuildContext context, AssetAction action, String assetRef) {
  return showModalBottomSheet<AssetCommand>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CommandForm(action: action, assetRef: assetRef),
  );
}

class _CommandForm extends StatefulWidget {
  const _CommandForm({required this.action, required this.assetRef});
  final AssetAction action;
  final String assetRef;

  @override
  State<_CommandForm> createState() => _CommandFormState();
}

class _CommandFormState extends State<_CommandForm> {
  late final Map<String, TextEditingController> _controllers = {
    for (final f in AssetCommand.fields[widget.action]!) f.key: TextEditingController(),
  };
  final _invalid = <String>{};
  late final AppServices _services = AppScope.of(context);
  bool _registered = false;

  bool get _dirty => _controllers.values.any((c) => c.text.isNotEmpty);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_registered) {
      _registered = true;
      _services.router.setLeaveConfirmation(_confirmLeave);
    }
  }

  /// Abandonar → descarta el formulario y el deep link se consume; cancelar → se conserva el formulario.
  Future<bool> _confirmLeave() async {
    if (!_dirty || !mounted) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Salir sin enviar?'),
        content: const Text('Se abrió un enlace. Si sales, se pierden los datos escritos en el formulario.'),
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

  void _submit() {
    final errors = <String>[];
    final cmd = AssetCommand.build(widget.action, widget.assetRef, {
      for (final e in _controllers.entries) e.key: e.value.text,
    }, errors: errors);
    if (cmd == null) {
      setState(
        () => _invalid
          ..clear()
          ..addAll(errors),
      );
      return;
    }
    Navigator.of(context).pop(cmd);
  }

  @override
  Widget build(BuildContext context) {
    final spec = AssetCommand.fields[widget.action]!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(actionLabel(widget.action), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Activo ${widget.assetRef}'),
            const SizedBox(height: 16),
            for (final f in spec) ...[
              TextField(
                key: Key('form.${f.key}'),
                controller: _controllers[f.key],
                maxLength: AssetCommand.maxLength,
                decoration: InputDecoration(
                  labelText: f.label,
                  border: const OutlineInputBorder(),
                  errorText: _invalid.contains(f.key) ? 'Obligatorio (máximo ${AssetCommand.maxLength})' : null,
                ),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(key: const Key('form.submit'), onPressed: _submit, child: Text(actionLabel(widget.action))),
          ],
        ),
      ),
    );
  }
}
