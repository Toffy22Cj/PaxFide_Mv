import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/public_links.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/money.dart';
import '../../../shared/widgets/amount_bars.dart';
import '../../../shared/widgets/qr_sheet.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/campaign_api.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Convocatoria'),
        actions: [
          if (qr != null)
            IconButton(
              key: const Key('campaign.qr'),
              tooltip: 'Mostrar QR de la convocatoria',
              icon: const Icon(Icons.qr_code_2),
              onPressed: () => showQrSheet(context, title: 'QR de la convocatoria', url: qr),
            ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final e = _error;
    if (e is NotFoundException) {
      return const MessageView(icon: Icons.search_off, title: 'No encontramos esta convocatoria.');
    }
    if (e != null) return ErrorRetryView(message: describeError(e), onRetry: _load);
    final c = _campaign;
    if (c == null) return const LoadingView();
    final theme = Theme.of(context);
    final target = int.tryParse(c.targetAmount ?? '');
    final cleared = int.tryParse(c.clearedAmount ?? '');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(c.title, style: theme.textTheme.headlineSmall),
        Text(c.organizationName, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text('${campaignStatusLabel(c.status)} · del ${c.startDate.split('T').first} al ${c.endDate.split('T').first}'),
        if (c.description != null) ...[const SizedBox(height: 12), Text(c.description!)],
        const SizedBox(height: 12),
        if (target != null || cleared != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AmountBars(
                bars: [
                  if (target != null) AmountBar('Meta', target, formatMinorUnits(target, c.currency)),
                  if (cleared != null)
                    AmountBar('Recaudado y acreditado', cleared, formatMinorUnits(cleared, c.currency)),
                ],
              ),
            ),
          ),
        if (c.acceptedDonationTypes.isNotEmpty)
          Text('Acepta: ${c.acceptedDonationTypes.map(_donationType).join(', ')}'),
        if (widget.actionsBuilder != null) ...[const SizedBox(height: 12), widget.actionsBuilder!(context, c)],
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
    return Card(
      key: const Key('campaign.narrative'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hechos registrados', style: theme.textTheme.titleMedium),
            if (f != null) ...[
              Text('Unidades entregadas: ${f.unitsDelivered}'),
              Text('Receptores distintos: ${f.distinctRecipients}'),
              if (f.clearedAmount != null) Text('Acreditado: ${formatMinorUnits(f.clearedAmount!, f.currency)}'),
            ],
            const Divider(),
            Text('Relato', style: theme.textTheme.titleMedium),
            if (_narrativeLoading)
              const LinearProgressIndicator()
            else if (n == null || n.status == 'PENDING') ...[
              Text(n == null ? 'No pudimos cargar el relato.' : 'El relato todavía se está preparando.'),
              TextButton(onPressed: _loadNarrative, child: const Text('Actualizar')),
            ] else if (n.status == 'UNAVAILABLE')
              Text(n.content ?? 'Narrativa no disponible')
            else ...[
              Text(n.content ?? ''),
              const SizedBox(height: 8),
              Text(
                n.source == 'LLM_GENERATED'
                    ? 'Texto generado con IA a partir de los hechos registrados.'
                    : 'Texto de plantilla a partir de los hechos registrados.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
