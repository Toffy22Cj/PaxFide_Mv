import 'package:flutter/material.dart';

import '../shared/theme/text_size_controller.dart';
import 'app_services.dart';

/// Botón "Tamaño del texto" (M-04), junto al del tema en todas las pantallas.
class TextSizeButton extends StatelessWidget {
  const TextSizeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).textSize;
    return ValueListenableBuilder<TextSize>(
      valueListenable: controller,
      builder: (context, size, _) => PopupMenuButton<TextSize>(
        key: const Key('textSize.menu'),
        tooltip: 'Tamaño del texto: ${size.label}',
        icon: const Icon(Icons.format_size),
        initialValue: size,
        onSelected: controller.select,
        itemBuilder: (context) => [
          for (final s in TextSize.values)
            PopupMenuItem(
              key: Key('textSize.${s.name}'),
              value: s,
              child: Row(
                children: [
                  Icon(s == size ? Icons.radio_button_checked : Icons.radio_button_off),
                  const SizedBox(width: 12),
                  // Cada opción se ve con su propio tamaño, para elegir viéndolo.
                  Flexible(
                    child: Text(s.label, overflow: TextOverflow.ellipsis, textScaler: TextScaler.linear(s.factor)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
