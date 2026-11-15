import 'package:flutter/material.dart';

import '../../../shared/widgets/brand_mark.dart';

/// Pantalla partida en anchos grandes (panel de marca + formulario); una columna en el móvil.
/// En el móvil, el emblema y el nombre van encima del formulario; en anchos grandes, en el panel de marca.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget form({required bool withBrand}) => Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (withBrand) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BrandMark(size: 56),
                    const SizedBox(width: 12),
                    Text('PaxFide', style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
                const SizedBox(height: 24),
              ],
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
        child: LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 840) return form(withBrand: true);
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
                            const BrandMark(size: 120),
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
                Expanded(child: form(withBrand: false)),
              ],
            );
          },
        ),
      ),
    );
  }
}
