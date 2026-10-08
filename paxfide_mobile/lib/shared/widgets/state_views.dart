import 'package:flutter/material.dart';

/// UI de espera mientras la sesión está en UNKNOWN / RESTORING.
///
/// NO es una ruta (ADR-043 D8, G-1 a): no existe `/boot`, no se restaura y no
/// es destino de deep links. La muestra el `RouteGate` dentro de la ruta que
/// está esperando.
class SessionWaitingView extends StatelessWidget {
  const SessionWaitingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E4A38)),
              ),
            ),
            SizedBox(height: 14),
            Text('Cargando…', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

/// Ruta aprobada en el árbol v1 cuya pantalla todavía no existe en esta build.
///
/// No promete fechas ni capacidades; solo informa y ofrece volver.
class UnavailableScreenView extends StatelessWidget {
  final String path;

  const UnavailableScreenView({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        automaticallyImplyLeading: canPop,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Esta pantalla no está disponible en esta versión de la app.',
              key: Key('unavailable-screen'),
              style: TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Estados de pantalla (no son rutas, §12 regla 1).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Cargando…'});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(label)],
          ),
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
            Icon(icon, size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(detail!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
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
        action: FilledButton.tonal(onPressed: onRetry, child: const Text('Reintentar')),
      );
}

/// Página estándar de las pantallas internas: barra superior y contenido
/// centrado con ancho máximo legible.
class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.title, required this.body, this.actions, this.scroll = true});

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(padding: const EdgeInsets.all(16), child: body),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: scroll ? SingleChildScrollView(child: content) : content),
    );
  }
}

/// Tarjeta con título para agrupar datos en las pantallas internas.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Fila etiqueta: valor.
class LabeledValue extends StatelessWidget {
  const LabeledValue(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
