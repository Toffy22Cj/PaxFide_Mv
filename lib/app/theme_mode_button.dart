import 'package:flutter/material.dart';

import 'app_services.dart';

/// Botón para elegir el modo claro, oscuro o "como el teléfono". Está en todas las pantallas: login, registro, las
/// públicas y las de la sesión.
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  static const labels = {
    ThemeMode.light: 'Modo claro',
    ThemeMode.dark: 'Modo oscuro',
    ThemeMode.system: 'Como el teléfono',
  };

  static const icons = {
    ThemeMode.light: Icons.light_mode_outlined,
    ThemeMode.dark: Icons.dark_mode_outlined,
    ThemeMode.system: Icons.brightness_auto_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = AppScope.of(context).theme;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: theme,
      builder: (context, mode, _) => PopupMenuButton<ThemeMode>(
        key: const Key('theme.menu'),
        tooltip: 'Tema: ${labels[mode]}',
        icon: Icon(icons[mode]),
        initialValue: mode,
        onSelected: theme.select,
        itemBuilder: (context) => [
          for (final m in [ThemeMode.light, ThemeMode.dark, ThemeMode.system])
            PopupMenuItem(
              key: Key('theme.${m.name}'),
              value: m,
              child: Row(
                children: [
                  Icon(icons[m]),
                  const SizedBox(width: 12),
                  Flexible(child: Text(labels[m]!, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
