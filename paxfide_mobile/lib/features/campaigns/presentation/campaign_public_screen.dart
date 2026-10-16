import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/money.dart';
import '../../../shared/quantity.dart';
import '../../../shared/theme/pax_theme.dart';
import '../../../shared/widgets/qr_sheet.dart';
import '../../../shared/widgets/state_views.dart';
import '../../donations/presentation/donate_sheet.dart';
import '../data/campaign_api.dart';

/// `/c/:publicCode` (§13): una causa, cuánto lleva, lo logrado y su historia.
/// Los datos registrados se muestran aparte del relato (DDM-26).
class CampaignPublicScreen extends StatefulWidget {
  const CampaignPublicScreen({super.key, required this.publicCode});

  final String publicCode;

  @override
  State<CampaignPublicScreen> createState() => _CampaignPublicScreenState();
}

class _CampaignPublicScreenState extends State<CampaignPublicScreen> {
  late final AppServices _services = AppScope.of(context);
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
      final c = await _services.campaignApi.get(widget.publicCode);
      if (!mounted) return;
      setState(() => _campaign = c);
      _loadNarrative();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Manual: sin polling (regla 3.5).
  Future<void> _loadNarrative() async {
    setState(() => _narrativeLoading = true);
    try {
      final n = await _services.campaignApi.narrative(widget.publicCode);
      if (mounted) setState(() => _narrative = n);
    } on AppException {
      if (mounted) setState(() => _narrative = null);
    } finally {
      if (mounted) setState(() => _narrativeLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qr = _campaign == null ? null : _services.publicLinks.campaign(widget.publicCode);
    return AppPage(
      title: 'Causa',
      actions: [
        if (qr != null)
          IconButton(
            key: const Key('campaign-qr'),
            tooltip: 'Compartir con código QR',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => showQrSheet(context, title: 'Código QR de la causa', url: qr),
          ),
      ],
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final e = _error;
    if (e is NotFoundException) {
      return const MessageView(icon: Icons.search_off, title: 'No encontramos esta causa.');
    }
    if (e != null) return ErrorRetryView(message: describeError(e), onRetry: _load);
    final c = _campaign;
    if (c == null) return const LoadingView();
    final p = PaxPalette.of(context);
    final target = int.tryParse(c.targetAmount ?? '');
    final cleared = int.tryParse(c.clearedAmount ?? '') ?? 0;
    return Column(
      key: const Key('campaign-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(c.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: p.text)),
        const SizedBox(height: 4),
        Row(
          children: [
            if (c.organizationName.isNotEmpty)
              Flexible(child: Text(c.organizationName, style: TextStyle(fontSize: 13.5, color: p.textMuted))),
            const SizedBox(width: 8),
            StatusChip(campaignStatusLabel(c.status), color: c.status == 'OPEN' ? paxAccent : p.textMuted),
          ],
        ),
        if (c.description != null) ...[
          const SizedBox(height: 12),
          Text(c.description!, style: TextStyle(fontSize: 14, color: p.text, height: 1.5)),
        ],
        const SizedBox(height: 16),
        if (target != null && target > 0)
          SectionCard(
            icon: Icons.savings_outlined,
            title: 'Lo recaudado',
            child: ProgressLine(
              value: cleared / target,
              label: '${formatMinorUnits(cleared, c.currency)} de ${formatMinorUnits(target, c.currency)} · '
                  'termina el ${shortDate(c.endDate)}',
            ),
          ),
        if (canDonate(c)) ...[
          FilledButton.icon(
            key: const Key('donate-open'),
            icon: const Icon(Icons.volunteer_activism),
            label: const Text('Donar'),
            onPressed: () => showDonateSheet(context, publicCode: widget.publicCode, currency: c.currency!),
          ),
          const SizedBox(height: 12),
        ] else if (c.status != 'OPEN')
          const Notice(text: 'Esta causa ya terminó y no recibe más donaciones.'),
        _achievements(context),
      ],
    );
  }

  /// Lo logrado (datos registrados) y la historia contada a partir de ellos.
  Widget _achievements(BuildContext context) {
    final n = _narrative;
    final p = PaxPalette.of(context);
    final f = n?.facts;
    return SectionCard(
      key: const Key('campaign-narrative'),
      icon: Icons.emoji_events_outlined,
      title: 'Lo que se ha logrado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (f != null)
            Row(
              children: [
                Expanded(child: _Stat(value: formatQuantity(f.unitsDelivered), label: 'ayudas entregadas')),
                Expanded(child: _Stat(value: f.distinctRecipients, label: 'lugares o personas que recibieron')),
              ],
            ),
          const SizedBox(height: 12),
          if (_narrativeLoading)
            const LinearProgressIndicator()
          else if (n == null || n.status == 'PENDING') ...[
            Text(n == null ? 'No pudimos cargar la historia.' : 'Estamos preparando la historia de esta causa.',
                style: TextStyle(fontSize: 13, color: p.textMuted)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _loadNarrative, child: const Text('Volver a mirar')),
            ),
          ] else if (n.status == 'AVAILABLE' && (n.content ?? '').isNotEmpty)
            Text(n.content!, style: TextStyle(fontSize: 14, color: p.text, height: 1.5)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: paxAccent)),
        Text(label, style: TextStyle(fontSize: 12, color: p.textMuted)),
      ],
    );
  }
}
