import 'package:flutter/material.dart';

import '../../../core/errors/app_exceptions.dart';
import 'auth_layout.dart';

/// Diálogo modal que exige aceptar las condiciones legales pendientes (403 `AcceptanceRequired`).
/// Devuelve true si el usuario aceptó todas las condiciones pendientes, o false si canceló o cerró.
Future<bool> showLegalAcceptanceDialog(BuildContext context, AcceptanceRequiredException pending) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _LegalAcceptanceDialog(pending: pending),
  );
  return result ?? false;
}

class _LegalAcceptanceDialog extends StatefulWidget {
  const _LegalAcceptanceDialog({required this.pending});

  final AcceptanceRequiredException pending;

  @override
  State<_LegalAcceptanceDialog> createState() => _LegalAcceptanceDialogState();
}

class _LegalAcceptanceDialogState extends State<_LegalAcceptanceDialog> {
  bool _acceptedTerms = false;
  bool _acceptedDataPolicy = false;

  @override
  Widget build(BuildContext context) {
    final ink = AuthInk(Theme.of(context).brightness == Brightness.dark);
    final termsVersion = widget.pending.pendingTermsVersion;
    final dataPolicyVersion = widget.pending.pendingDataPolicyVersion;
    final needsTerms = termsVersion != null;
    final needsDataPolicy = dataPolicyVersion != null;

    final canAccept = (!needsTerms || _acceptedTerms) && (!needsDataPolicy || _acceptedDataPolicy);

    Widget checkboxRow({
      required Key key,
      required bool value,
      required ValueChanged<bool?> onChanged,
      required VoidCallback onTap,
      required String label,
    }) => MergeSemantics(
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: ink.button,
                checkColor: ink.onButton,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 13, color: ink.body)),
              ),
            ],
          ),
        ),
      ),
    );

    return AlertDialog(
      key: const Key('legal-acceptance'),
      title: Text(
        'Actualizamos nuestras condiciones',
        style: TextStyle(fontWeight: FontWeight.w700, color: ink.title),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Para entrar, acepta las versiones vigentes.', style: TextStyle(fontSize: 14, color: ink.body)),
            const SizedBox(height: 12),
            if (needsTerms)
              checkboxRow(
                key: const Key('legal-acceptance.terms'),
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                label: 'Acepto los términos y condiciones (versión $termsVersion)',
              ),
            if (needsTerms && needsDataPolicy) const SizedBox(height: 4),
            if (needsDataPolicy)
              checkboxRow(
                key: const Key('legal-acceptance.dataPolicy'),
                value: _acceptedDataPolicy,
                onChanged: (v) => setState(() => _acceptedDataPolicy = v ?? false),
                onTap: () => setState(() => _acceptedDataPolicy = !_acceptedDataPolicy),
                label: 'Autorizo el tratamiento de mis datos personales (versión $dataPolicyVersion)',
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('legal-acceptance.cancel'),
          style: TextButton.styleFrom(foregroundColor: ink.link),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('legal-acceptance.accept'),
          style: FilledButton.styleFrom(backgroundColor: ink.button, foregroundColor: ink.onButton),
          onPressed: canAccept ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Aceptar y entrar'),
        ),
      ],
    );
  }
}
