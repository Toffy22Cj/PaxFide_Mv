import 'package:flutter/material.dart';

/// Aviso de error de una pantalla, legible en los dos modos: en claro, fondo `danger-700` y texto blanco; en oscuro,
/// fondo rojo oscuro y texto rojo claro. [textKey] va en el texto, para encontrarlo como antes.
class ErrorMessage extends StatelessWidget {
  const ErrorMessage(this.text, {super.key, this.textKey});

  final String text;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              key: textKey,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
