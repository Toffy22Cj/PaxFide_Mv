import 'package:flutter/material.dart';

import '../../../shared/money.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../domain/campaign_progress.dart';
import '../domain/campaign_search.dart';

CampaignProgress _progressOf(CampaignSummary c) => CampaignProgress.of(
  target: int.tryParse(c.targetAmount ?? ''),
  cleared: int.tryParse(c.clearedAmount ?? ''),
  endDate: c.endDate,
);

/// Tarjeta compacta de una convocatoria del listado público (Inicio, decisión 5): organización, título, barra de la
/// meta y días que quedan. Tocarla llama a [onTap].
class CampaignSummaryCard extends StatelessWidget {
  const CampaignSummaryCard(this.campaign, {super.key, required this.onTap});
  final CampaignSummary campaign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(14), child: CampaignSummaryCardBody(campaign)),
    ),
  );
}

/// Contenido de [CampaignSummaryCard].
class CampaignSummaryCardBody extends StatelessWidget {
  const CampaignSummaryCardBody(this.c, {super.key});
  final CampaignSummary c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _progressOf(c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.organizationName.isNotEmpty)
          Text(
            c.organizationName,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        Text(c.title, style: theme.textTheme.titleSmall),
        if (p.fraction != null) ...[
          const SizedBox(height: 8),
          SlimProgress(p.fraction!, semanticsLabel: p.percentText),
          const SizedBox(height: 4),
          Text(p.percentText!, style: theme.textTheme.labelSmall),
        ],
        if (p.daysText != null) ...[const SizedBox(height: 2), Text(p.daysText!, style: theme.textTheme.labelSmall)],
      ],
    );
  }
}

/// Tarjeta tipográfica de una convocatoria (variante 15 del landing): sin foto, con la cifra como protagonista. Solo
/// usa lo que trae `GET /public/campaigns`. Estados: con meta (porcentaje), sin meta en dinero (días que quedan), meta
/// alcanzada y cerrada.
class CampaignFigureCard extends StatelessWidget {
  const CampaignFigureCard(this.campaign, {super.key, required this.onOpen, this.detailsKey});
  final CampaignSummary campaign;
  final VoidCallback onOpen;
  final Key? detailsKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.colorScheme;
    final c = campaign;
    final p = _progressOf(c);
    final target = int.tryParse(c.targetAmount ?? '');
    final cleared = int.tryParse(c.clearedAmount ?? '');
    final closed = c.status.isNotEmpty && c.status != 'OPEN';
    final figure = p.fraction != null
        ? '${(p.fraction! * 100).floor()} %'
        : (p.daysText ?? (closed ? 'Cerrada' : 'Abierta'));
    final figureCaption = p.fraction != null ? 'de la meta' : 'Sin meta en dinero';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.organizationName.isNotEmpty)
                Text(
                  c.organizationName.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 0.5,
                    color: s.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                children: [
                  Text(
                    figure,
                    key: const Key('campaign.figure'),
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: s.primary),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(figureCaption, style: TextStyle(color: s.onSurfaceVariant)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(c.title, style: theme.textTheme.titleMedium),
              if (p.fraction != null) ...[
                const SizedBox(height: 10),
                SlimProgress(p.fraction!, semanticsLabel: p.percentText),
              ],
              const SizedBox(height: 8),
              Text(
                [
                  if (cleared != null && target != null)
                    '${formatMinorUnits(cleared, c.currency)} de ${formatMinorUnits(target, c.currency)}',
                  if (p.fraction != null && p.daysText != null) p.daysText!,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: s.onSurfaceVariant),
              ),
              if (p.reached || closed) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (p.reached)
                      const StatusChip(
                        'Meta alcanzada',
                        key: Key('campaign.reached'),
                        icon: Icons.emoji_events_outlined,
                      ),
                    if (closed)
                      const StatusChip(
                        'Cerrada',
                        key: Key('campaign.closed'),
                        icon: Icons.lock_outline,
                        tone: Tone.neutral,
                      ),
                  ],
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(key: detailsKey, onPressed: onOpen, child: const Text('Ver detalles')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta esqueleto mientras responde el listado (variante 17): bloques grises con el borde del tema, sin texto.
class CampaignSkeletonCard extends StatelessWidget {
  const CampaignSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final block = Theme.of(context).colorScheme.outlineVariant;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(6)),
      ),
    );
    return Semantics(
      label: 'Cargando convocatoria',
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bar(0.35, 10), bar(0.3, 28), bar(0.85, 14), bar(1, 8), bar(0.6, 10)],
            ),
          ),
        ),
      ),
    );
  }
}
