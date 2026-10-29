import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../shared/dates.dart';
import '../../../shared/money.dart';
import '../../../shared/motion/pax_motion.dart';
import '../../../shared/theme/pax_tokens.dart';
import '../../../shared/widgets/loaders.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../data/campaign_api.dart';

/// «✓ Verificada» (web: `CampaignCard`), solo si la organización está verificada.
class OrganizationVerifiedBadge extends StatelessWidget {
  const OrganizationVerifiedBadge({super.key = const Key('campaign.verified')});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? PaxDarkTokens.green : PaxTokens.brandGreen800;
    final bg = isDark ? PaxTokens.brandGreen900 : PaxTokens.brandGreen50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            'Verificada',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
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
  const CampaignCoverImage({super.key, required this.coverUrl, this.aspectRatio = 16 / 9, this.heroCode});

  final Uri? coverUrl;
  final double aspectRatio;

  /// Con el código público, la portada «vuela» de la tarjeta a la pantalla de la convocatoria (`movimiento.html`,
  /// tarjeta que se expande, 450 ms).
  final String? heroCode;

  static Object heroTag(String code) => 'campaign.cover.$code';

  @override
  Widget build(BuildContext context) {
    if (coverUrl == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallback = Container(
      color: isDark ? PaxDarkTokens.surfaceHigh : PaxTokens.brandGreen50,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: isDark ? PaxDarkTokens.neutral : PaxTokens.brandGreen500, size: 32),
    );

    final image = AspectRatio(
      aspectRatio: aspectRatio,
      child: Image.network(
        coverUrl.toString(),
        fit: BoxFit.cover,
        // Se decodifica al ancho de un teléfono, no al de la foto original: menos memoria y desplazamiento fluido.
        cacheWidth: 1080,
        excludeFromSemantics: true,
        loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
    final code = heroCode;
    if (code == null || PaxMotion.reduce(context)) return image;
    return Hero(
      tag: heroTag(code),
      createRectTween: (a, b) => MaterialRectCenterArcTween(begin: a, end: b),
      child: image,
    );
  }
}

/// Tarjeta de una convocatoria del listado público: la variante 01 elegida, igual que `CampaignCard` de la web.
/// Portada arriba si la hay; logo (o la inicial), nombre y «Verificada»; título; barra con «$X de $Y (N %)» y
/// «Cierra el …». Toda la tarjeta se toca para abrirla ([onTap]).
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
            if (coverUrl != null) CampaignCoverImage(coverUrl: coverUrl, heroCode: campaign.publicCode),
            Padding(
              padding: const EdgeInsets.all(16),
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
    final s = theme.colorScheme;
    final target = int.tryParse(c.targetAmount ?? '');
    final cleared = int.tryParse(c.clearedAmount ?? '0') ?? 0;
    // Como `percentOf` de la web: entero hacia abajo, sin tope (la barra sí se queda en 100 %).
    final pct = target == null || target <= 0 ? null : cleared * 100 ~/ target;
    final hasOrg = c.organizationName.isNotEmpty || logoUrl != null || c.organizationVerified;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasOrg) ...[
          Row(
            children: [
              _OrganizationMark(name: c.organizationName, logoUrl: logoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.organizationName.isNotEmpty)
                      Text(c.organizationName, style: theme.textTheme.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                    if (c.organizationVerified) ...[const SizedBox(height: 4), const OrganizationVerifiedBadge()],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text(c.title, style: theme.textTheme.titleMedium?.copyWith(height: 1.2)),
        if (c.currency != null && target != null) ...[
          const SizedBox(height: 12),
          if (pct != null) ...[SlimProgress((pct / 100).clamp(0.0, 1.0)), const SizedBox(height: 8)],
          Text(
            '${formatMinorUnits(cleared, c.currency)} de ${formatMinorUnits(target, c.currency)}'
            '${pct == null ? '' : ' ($pct %)'}',
            key: const Key('campaign.amounts'),
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: s.onSurface),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Cierra el ${longDate(c.endDate)}',
          key: const Key('campaign.closes'),
          style: theme.textTheme.bodySmall?.copyWith(color: s.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Logo cuadrado de 40 (radio de control) o la inicial del nombre sobre el verde suave; sin nombre ni logo, nada.
class _OrganizationMark extends StatelessWidget {
  const _OrganizationMark({required this.name, this.logoUrl});
  final String name;
  final Uri? logoUrl;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final first = name.trim().characters.firstOrNull?.toUpperCase();
    final initial = first == null
        ? const SizedBox(width: 40, height: 40)
        : Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? PaxTokens.brandGreen900 : PaxTokens.brandGreen50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              first,
              key: const Key('organization.initials'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? PaxDarkTokens.green : PaxTokens.brandGreen800,
              ),
            ),
          );
    final url = logoUrl;
    if (url == null) return initial;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url.toString(),
        width: 40,
        height: 40,
        cacheWidth: 120,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        loadingBuilder: (context, child, progress) => progress == null ? child : initial,
        errorBuilder: (context, error, stackTrace) => initial,
      ),
    );
  }
}

/// Tarjeta esqueleto mientras responde el listado: la forma de la tarjeta con el brillo de carga.
class CampaignSkeletonCard extends StatelessWidget {
  const CampaignSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) => Card(child: Skeleton.card(label: 'Cargando convocatoria'));
}
