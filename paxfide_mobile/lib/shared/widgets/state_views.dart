import 'package:flutter/material.dart';

import '../theme/pax_theme.dart';

/// UI de espera mientras la sesión está en UNKNOWN / RESTORING.
///
/// NO es una ruta (ADR-043 D8, G-1 a): no existe `/boot`, no se restaura y no
/// es destino de deep links.
class SessionWaitingView extends StatelessWidget {
  const SessionWaitingView({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: LoadingView());
}

/// Ruta aprobada en el árbol cuya pantalla no existe en esta build.
class UnavailableScreenView extends StatelessWidget {
  final String path;

  const UnavailableScreenView({super.key, required this.path});

  @override
  Widget build(BuildContext context) => const AppPage(
    title: 'PaxFide',
    body: MessageView(
      key: Key('unavailable-screen'),
      icon: Icons.construction_outlined,
      title: 'Esta pantalla todavía no está disponible.',
    ),
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Cargando…'});
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontSize: 13.5, color: p.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Mensaje centrado con icono: vacío, sin acceso, no encontrado…
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: paxAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: paxAccent),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.4),
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
  const ErrorRetryView({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MessageView(
    icon: Icons.cloud_off_outlined,
    title: message,
    action: OutlinedButton(
      onPressed: onRetry,
      child: const Text('Intentar de nuevo'),
    ),
  );
}

/// Página interna con el diseño de la app: barra superior y contenido
/// centrado con ancho máximo legible.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.scroll = true,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: body,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: scroll ? SingleChildScrollView(child: content) : content,
      ),
    );
  }
}

/// Título y explicación corta de una sección.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: p.text,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta con título para agrupar información.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.icon,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    // Material (no un DecoratedBox) para que las listas desplegables de
    // dentro pinten bien su fondo y sus efectos.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: paxAccent),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
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
    final p = PaxPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: p.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso destacado (información, éxito, atención o error).
enum NoticeKind { info, success, warning, error }

class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.text,
    this.kind = NoticeKind.info,
    this.title,
    this.action,
  });

  final String text;
  final String? title;
  final NoticeKind kind;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    final (Color color, IconData icon) = switch (kind) {
      NoticeKind.info => (const Color(0xFF38BDF8), Icons.info_outline_rounded),
      NoticeKind.success => (paxAccent, Icons.check_circle_outline_rounded),
      NoticeKind.warning => (const Color(0xFFF59E0B), Icons.schedule_rounded),
      NoticeKind.error => (
        const Color(0xFFEF4444),
        Icons.error_outline_rounded,
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  text,
                  style: TextStyle(fontSize: 13, color: p.text, height: 1.4),
                ),
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta de estado con color.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color = paxAccent});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );
}

/// Barra de progreso con texto debajo.
class ProgressLine extends StatelessWidget {
  const ProgressLine({
    super.key,
    required this.value,
    this.label,
    this.color = paxAccent,
  });
  final double value;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
            backgroundColor: p.surfaceAlt,
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label!, style: TextStyle(fontSize: 12.5, color: p.textMuted)),
        ],
      ],
    );
  }
}
