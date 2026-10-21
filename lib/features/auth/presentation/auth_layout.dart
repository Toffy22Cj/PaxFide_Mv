import 'package:flutter/material.dart';

import '../../../app/text_size_button.dart';
import '../../../app/theme_mode_button.dart';
import '../../../shared/widgets/pax_logo.dart';

/// Pantalla partida en anchos grandes (panel de marca + formulario); una columna en el móvil. Arriba a la derecha,
/// el botón de modo claro u oscuro.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: PaxLogo()),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, c) {
                  if (c.maxWidth < 840) return form;
                  return Row(
                    children: [
                      Expanded(
                        child: ColoredBox(
                          color: scheme.primaryContainer,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const PaxLogo(size: 200),
                                  const SizedBox(height: 16),
                                  Text(
                                    'PaxFide',
                                    style: Theme.of(context).textTheme.displaySmall
                                        ?.copyWith(color: scheme.onPrimaryContainer),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Trazabilidad verificable de donaciones',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: scheme.onPrimaryContainer),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: form),
                    ],
                  );
                },
              ),
            ),
            const Positioned(
              top: 8,
              right: 8,
              child: Row(mainAxisSize: MainAxisSize.min, children: [TextSizeButton(), ThemeModeButton()]),
            ),
          ],
        ),
      ),
    );
  }
}
