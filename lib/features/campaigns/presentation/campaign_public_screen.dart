import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/public_links.dart';
import '../../../app/text_size_button.dart';
import '../../../app/theme_mode_button.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/dates.dart';
import '../../../shared/money.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../../shared/widgets/qr_sheet.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/campaign_api.dart';
import '../domain/campaign_progress.dart';
import '../../../shared/widgets/pax_app_bar.dart';

String campaignStatusLabel(String s) => switch (s) {
  'OPEN' => 'Abierta',
  'CLOSED' => 'Cerrada',
  _ => s,
};

/// `/c/:publicCode` (§13): convocatoria pública + su narrativa (sección, no ruta), con los **hechos** separados del
/// texto generado. Estados: carga; contenido; código inexistente (404); error; narrativa pendiente/no disponible.
class CampaignPublicScreen extends StatefulWidget {
  const CampaignPublicScreen({super.key, required this.publicCode, this.actionsBuilder});

  final String publicCode;

  /// Acciones extra bajo los datos (p. ej. "Donar", bloque 2.8).
  final Widget Function(BuildContext context, PublicCampaign campaign)? actionsBuilder;

  @override
  State<CampaignPublicScreen> createState() => _CampaignPublicScreenState();
}

class _CampaignPublicScreenState extends State<CampaignPublicScreen> {
  late final AppServices _services = AppScope.of(context);
  late final CampaignApi _api = CampaignApi(_services.apiClient);
  PublicCampaign? _campaign;
  Object? _error;
  CampaignNarrative? _narrative;
  bool _narrativeLoading = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _campaign = null;
    });
    try {
      final c = await _api.get(widget.publicCode);
      if (!mounted) return;
      setState(() => _campaign = c);
      _loadNarrative();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadNarrative() async {
    setState(() => _narrativeLoading = true);
    try {
      final n = await _api.narrative(widget.publicCode);
      if (mounted) setState(() => _narrative = n);
    } on AppException {
      // sección opcional
    } finally {
      if (mounted) setState(() => _narrativeLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qr = _campaign == null ? null : PublicLinks(_services.config.publicOrigin).campaign(widget.publicCode);
    final c = _campaign;
    final action = c == null || widget.actionsBuilder == null ? null : widget.actionsBuilder!(context, c);
    return Scaffold(
      appBar: PaxAppBar(
        title: const Text('Convocatoria'),
        actions: [
          if (qr != null)
            IconButton(
              key: const Key('campaign.qr'),
              tooltip: 'Mostrar QR de la convocatoria',
              icon: const Icon(Icons.qr_code_2),
              onPressed: () => showQrSheet(context, title: 'QR de la convocatoria', url: qr),
            ),
          const TextSizeButton(),
          const ThemeModeButton(),
        ],
      ),
      body: _body(context),
      // "Donar" fijo abajo, al alcance del pulgar (Figma 02).
      bottomNavigationBar: action == null || c?.status != 'OPEN'
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                ),
                child: action,
              ),
            ),
    );
  }

  Widget _body(BuildContext context) {
    final e = _error;
    if (e is NotFoundException) {
      return const MessageView(icon: Icons.search_off, title: 'No encontramos esta convocatoria.');
    }
    if (e != null) return ErrorRetryView(message: 'No pudimos cargar esta convocatoria.', onRetry: _load);
    final c = _campaign;
    if (c == null) return const LoadingView(label: 'Cargando convocatoria…');
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final target = int.tryParse(c.targetAmount ?? '');
    final cleared = int.tryParse(c.clearedAmount ?? '');
    final progress = CampaignProgress.of(target: target, cleared: cleared, endDate: c.endDate);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (c.organizationName.isNotEmpty)
          Row(
            children: [
              Flexible(
                child: Text(c.organizationName, style: theme.textTheme.labelMedium?.copyWith(color: muted)),
              ),
              if (_services.organizationVerification.isVerified(c)) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Organización verificada por PaxFide',
                  child: Icon(
                    Icons.verified,
                    key: const Key('campaign.verified'),
                    size: 16,
                    color: theme.colorScheme.primary,
                    semanticLabel: 'Organización verificada',
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 4),
        Text(c.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusChip(
              campaignStatusLabel(c.status),
              key: const Key('campaign.status'),
              icon: Icons.inventory_2_outlined,
              tone: c.status == 'OPEN' ? Tone.info : Tone.neutral,
            ),
            if (progress.reached)
              const StatusChip('Meta alcanzada', key: Key('campaign.reached'), icon: Icons.emoji_events_outlined),
          ],
        ),
        const SizedBox(height: 8),
        Text('del ${shortDate(c.startDate)} al ${shortDate(c.endDate)}', style: TextStyle(color: muted)),
        if (c.description != null) ...[
          const SizedBox(height: 12),
          Text(c.description!, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: 14),
        if (cleared != null || target != null) ...[
          HighlightCard(
            key: const Key('campaign.progress'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recaudado y acreditado', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  cleared == null ? 'Sin datos' : formatMinorUnits(cleared, c.currency),
                  key: const Key('campaign.cleared'),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (target != null)
                  Text('de ${formatMinorUnits(target, c.currency)}', key: const Key('campaign.target')),
                if (progress.fraction != null) ...[
                  const SizedBox(height: 10),
                  SlimProgress(progress.fraction!, semanticsLabel: progress.percentText),
                  const SizedBox(height: 8),
                  Text(
                    'Meta ${(progress.fraction! * 100).floor()} %',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
                if (progress.daysText != null) ...[
                  const SizedBox(height: 4),
                  Text(progress.daysText!, key: const Key('campaign.days')),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else if (progress.daysText != null) ...[
          Text(progress.daysText!, key: const Key('campaign.days')),
          const SizedBox(height: 12),
        ],
        if (c.acceptedDonationTypes.isNotEmpty)
          Text('Acepta: ${c.acceptedDonationTypes.map(_donationType).join(', ')}'),
        if (c.status != 'OPEN') ...[
          const SizedBox(height: 12),
          const NoticeBanner('Esta convocatoria está cerrada. No acepta donaciones ahora.', tone: Tone.info),
        ],
        const SizedBox(height: 12),
        _narrativeSection(context),
      ],
    );
  }

  static String _donationType(String t) => switch (t) {
    'MONETARY' => 'dinero',
    'IN_KIND' => 'bienes',
    _ => t,
  };

  Widget _narrativeSection(BuildContext context) {
    final n = _narrative;
    final theme = Theme.of(context);
    final f = n?.facts;
    return SectionCard(
      key: const Key('campaign.narrative'),
      title: 'Hechos registrados',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (f != null) ...[
            LabeledValue('Unidades entregadas', f.unitsDelivered),
            LabeledValue('Receptores distintos', f.distinctRecipients),
            if (f.clearedAmount != null) LabeledValue('Acreditado', formatMinorUnits(f.clearedAmount!, f.currency)),
          ] else if (!_narrativeLoading)
            const Text('Todavía no hay hechos para mostrar.'),
          const Divider(height: 24),
          Text('Relato', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          if (_narrativeLoading)
            const LinearProgressIndicator()
          else if (n == null || n.status == 'PENDING') ...[
            Text(n == null ? 'No pudimos cargar el relato.' : 'El relato todavía se está preparando.'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _loadNarrative, child: const Text('Actualizar')),
            ),
          ] else if (n.status == 'UNAVAILABLE')
            Text(n.content ?? 'Relato no disponible.')
          else ...[
            Text(
              n.source == 'LLM_GENERATED'
                  ? 'Generado con IA a partir de los hechos registrados.'
                  : 'Texto de plantilla a partir de los hechos registrados.',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(n.content ?? ''),
          ],
        ],
      ),
    );
  }
}
