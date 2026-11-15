import 'package:flutter/material.dart';

import 'loaders.dart';
import 'pax_ui.dart';
import 'pax_app_bar.dart';

/// Estados de pantalla (no son rutas, §12 regla 1). La carga son los cubos encadenados, como en la web.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Cargando…'});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [const ChainCubesLoader(), const SizedBox(height: 12), Text(label)],
    ),
  );
}

class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.title, this.detail, this.action});

  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconCircle(icon),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MessageView(
    icon: Icons.cloud_off,
    title: message,
    action: OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
  );
}

/// Pantalla de espera del arranque (G-1 a): no es una ruta.
class WaitingView extends StatelessWidget {
  const WaitingView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: PaxAppBar(title: const Text('PaxFide')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandHeader(),
          const SizedBox(height: 40),
          const ChainCubesLoader(),
          const SizedBox(height: 16),
          Text('Comprobando la sesión…', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    ),
  );
}
