import 'package:flutter/material.dart';

import '../../../shared/theme/pax_theme.dart';
import '../domain/asset_action.dart';
import '../domain/asset_command.dart';

String actionLabel(AssetAction a) => switch (a) {
      AssetAction.dispatch => 'Enviar',
      AssetAction.receive => 'Recibir',
      AssetAction.deliver => 'Entregar',
      AssetAction.readOnly => 'Sin acciones',
    };

/// Explicación de cada paso para quien lo registra.
String actionHint(AssetAction a) => switch (a) {
      AssetAction.dispatch => 'Regístralo cuando el envío salga de la bodega.',
      AssetAction.receive => 'Regístralo cuando el envío llegue al centro de acopio.',
      AssetAction.deliver => 'Regístralo cuando entregues las ayudas a quien las necesita.',
      AssetAction.readOnly => 'Este envío ya terminó su recorrido.',
    };

/// Formulario de un paso: hoja transitoria sobre `AssetScreen`, nunca una
/// ruta ni restaurable (§12 regla 2).
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

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final errors = <String>[];
    final cmd = AssetCommand.build(
      widget.action,
      widget.assetRef,
      {for (final e in _controllers.entries) e.key: e.value.text},
      errors: errors,
    );
    if (cmd == null) {
      setState(() => _invalid
        ..clear()
        ..addAll(errors));
      return;
    }
    Navigator.of(context).pop(cmd);
  }

  @override
  Widget build(BuildContext context) {
    final spec = AssetCommand.fields[widget.action]!;
    final p = PaxPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(actionLabel(widget.action), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: p.text)),
            const SizedBox(height: 4),
            Text(actionHint(widget.action), style: TextStyle(fontSize: 13, color: p.textMuted)),
            const SizedBox(height: 16),
            for (final f in spec) ...[
              TextField(
                key: Key('form-${f.key}'),
                controller: _controllers[f.key],
                maxLength: AssetCommand.maxLength,
                decoration: InputDecoration(
                  labelText: f.label,
                  counterText: '',
                  errorText: _invalid.contains(f.key) ? 'Completa este dato' : null,
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            FilledButton(key: const Key('form-submit'), onPressed: _submit, child: Text('Registrar: ${actionLabel(widget.action).toLowerCase()}')),
          ],
        ),
      ),
    );
  }
}
