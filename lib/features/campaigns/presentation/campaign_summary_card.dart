import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../shared/money.dart';
import '../../../shared/theme/pax_tokens.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../data/campaign_api.dart';
import '../domain/campaign_progress.dart';

CampaignProgress _progressOf(CampaignSummary c) => CampaignProgress.of(
  target: int.tryParse(c.targetAmount ?? ''),
  cleared: int.tryParse(c.clearedAmount ?? ''),
  endDate: c.endDate,
);

/// Insignia / sello «✓ Organización verificada», solo visible si la organización está verificada.
class OrganizationVerifiedBadge extends StatelessWidget {
  const OrganizationVerifiedBadge({super.key = const Key('campaign.verified')});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? PaxDarkTokens.green : PaxTokens.brandGreen800;
    final bg = isDark ? PaxDarkTokens.surfaceHigh : PaxTokens.brandGreen50;
    final border = isDark ? PaxDarkTokens.green.withValues(alpha: 0.3) : PaxTokens.brandGreen500.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      ),
      child: Text(
        '✓ Organización verificada',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// Logo circular de la organización con iniciales de reserva sobre fondo de tokens.
class OrganizationLogo extends StatelessWidget {
  const OrganizationLogo({super.key, required this.organizationName, this.logoUrl, this.size = 32});

  final String organizationName;
  final Uri? logoUrl;
  final double size;

  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'O';
    if (words.length == 1) {
      final chars = words[0].characters.toList();
      return chars.take(2).join().toUpperCase();
    }
    return '${words[0].characters.first}${words[1].characters.first}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = initialsOf(organizationName);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? PaxDarkTokens.surfaceHigh : PaxTokens.brandGreen50,
        border: Border.all(
          color: isDark ? PaxDarkTokens.neutral.withValues(alpha: 0.3) : PaxTokens.brandGreen500.withValues(alpha: 0.3),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        key: const Key('organization.initials'),
        style: TextStyle(
          color: isDark ? PaxDarkTokens.green : PaxTokens.brandGreen900,
          fontWeight: FontWeight.w700,
          fontSize: (size * 0.4).clamp(12.0, 20.0),
        ),
      ),
    );

    if (logoUrl == null) return fallback;

    return ClipOval(
      child: Image.network(
        logoUrl.toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

/// Portada de la convocatoria con relación de aspecto 16:9 y fondo de reserva.
class CampaignCoverImage extends StatelessWidget {
  const CampaignCoverImage({super.key, required this.coverUrl, this.aspectRatio = 16 / 9});

  final Uri? coverUrl;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    if (coverUrl == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallback = Container(
      color: isDark ? PaxDarkTokens.surfaceHigh : PaxTokens.brandGreen50,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: isDark ? PaxDarkTokens.neutral : PaxTokens.brandGreen500, size: 32),
    );

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Image.network(
        coverUrl.toString(),
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

/// Tarjeta compacta de una convocatoria del listado público (Inicio, decisión 5): organización, título, barra de la
/// meta y días que quedan. Tocarla llama a [onTap].
class CampaignSummaryCard extends StatelessWidget {
  const CampaignSummaryCard(this.campaign, {super.key, required this.onTap, this.apiBaseUrl});
  final CampaignSummary campaign;
  final VoidCallback onTap;
  final Uri? apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final baseUrl = apiBaseUrl ?? AppScope.maybeOf(context)?.config.apiBaseUrl;
    final coverUrl = resolveApiMediaUrl(baseUrl, campaign.coverImageUrl);
    final logoUrl = resolveApiMediaUrl(baseUrl, campaign.organizationLogoUrl);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (coverUrl != null) CampaignCoverImage(coverUrl: coverUrl),
            Padding(
              padding: const EdgeInsets.all(14),
              child: CampaignSummaryCardBody(campaign, logoUrl: logoUrl),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contenido de [CampaignSummaryCard].
class CampaignSummaryCardBody extends StatelessWidget {
  const CampaignSummaryCardBody(this.c, {super.key, this.logoUrl});
  final CampaignSummary c;
  final Uri? logoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _progressOf(c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            OrganizationLogo(organizationName: c.organizationName, logoUrl: logoUrl, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.organizationName.isNotEmpty)
                    Text(
                      c.organizationName,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  if (c.organizationVerified) ...[const SizedBox(height: 2), const OrganizationVerifiedBadge()],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
