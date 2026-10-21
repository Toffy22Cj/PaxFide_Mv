import 'package:flutter/material.dart';

import 'pax_logo.dart';

/// Piezas comunes del diseño de Figma. Todos los colores salen del tema.

/// Tono de un chip o aviso.
enum Tone { success, pending, info, error, neutral }

/// Chip de estado ("Pago confirmado", "Abierta", "Recibido", "Rechazada"…).
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.icon, this.tone = Tone.success});
  final String label;
  final IconData? icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final (bg, fg, border) = switch (tone) {
      Tone.success => (s.primaryContainer, s.onPrimaryContainer, null),
      Tone.pending => (s.tertiaryContainer, s.onTertiaryContainer, s.tertiary),
      Tone.info => (s.secondaryContainer, s.onSecondaryContainer, null),
      Tone.error => (Colors.transparent, s.error, s.error),
      Tone.neutral => (s.surfaceContainerHighest, s.onSurfaceVariant, null),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso en banda (amarillo de advertencia o azul informativo), como "Pago simulado (demo)…".
class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.text, {super.key, this.tone = Tone.pending, this.icon, this.textKey});
  final String text;
  final Tone tone;
  final IconData? icon;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final (bg, fg, defaultIcon) = switch (tone) {
      Tone.info => (s.secondaryContainer, s.onSecondaryContainer, Icons.info_outline),
      Tone.success => (s.primaryContainer, s.onPrimaryContainer, Icons.check_circle_outline),
      Tone.error => (s.errorContainer, s.onErrorContainer, Icons.error_outline),
      _ => (s.tertiaryContainer, s.onTertiaryContainer, Icons.warning_amber_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: 20, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              key: textKey,
              style: TextStyle(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo con la etiqueta encima (y la ayuda debajo la pone el propio campo).
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
      child,
    ],
  );
}

/// Indicador de pasos: barra segmentada y "Paso X de Y" (o un texto propio en mayúsculas).
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, required this.total, this.caption});
  final int step;
  final int total;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Column(
      key: Key('step.$step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 1; i <= total; i++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? s.primary : s.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < total) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          caption ?? 'Paso $step de $total',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: s.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Texto pequeño en mayúsculas y color de marca ("PASO 1 DE 2 / DATOS").
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.primary, letterSpacing: 0.6, fontWeight: FontWeight.w600),
  );
}

/// Tarjeta destacada en verde suave (resúmenes: "Tus donaciones", "Recaudado y acreditado").
class HighlightCard extends StatelessWidget {
  const HighlightCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: DefaultTextStyle.merge(
      style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
      child: child,
    ),
  );
}

/// Tarjeta blanca con borde fino y relleno, para secciones ("Hechos registrados", "Tu aporte, en cifras").
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child, this.padding = const EdgeInsets.all(16)});
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    ),
  );
}

/// Dato con etiqueta pequeña encima ("Cantidad / 120 unidades").
class LabeledValue extends StatelessWidget {
  const LabeledValue(this.label, this.value, {super.key, this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: (mono ? t.bodyMedium?.copyWith(fontFamily: 'monospace') : t.titleSmall)),
        ],
      ),
    );
  }
}

/// Ícono dentro de un círculo suave (estados vacíos, carga, avisos de pantalla).
class IconCircle extends StatelessWidget {
  const IconCircle(this.icon, {super.key, this.size = 56});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: s.surfaceContainerHighest, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.45, color: s.primary),
    );
  }
}

/// Cabecera de marca: logo, "PaxFide" y el lema (arranque, login).
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.logoSize = 64});
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PaxLogo(size: logoSize),
        const SizedBox(height: 12),
        Text('PaxFide', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Trazabilidad verificable de donaciones',
          style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Barra de progreso fina con esquinas redondeadas.
class SlimProgress extends StatelessWidget {
  const SlimProgress(this.value, {super.key, this.semanticsLabel});
  final double value;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 8, semanticsLabel: semanticsLabel),
  );
}
