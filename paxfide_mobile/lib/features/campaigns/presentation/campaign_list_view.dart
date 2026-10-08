import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/money.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/campaign_api.dart';

/// Listado de `GET /public/campaigns` (solo `PUBLIC` y `OPEN`), 20 por página
/// con "Cargar más" manual. Al tocar una, abre `/c/:publicCode`.
class CampaignListView extends StatefulWidget {
  const CampaignListView({super.key});

  @override
  State<CampaignListView> createState() => _CampaignListViewState();
}

class _CampaignListViewState extends State<CampaignListView> {
  final List<CampaignSummary> _items = [];
  String? _cursor;
  bool _loading = false;
  bool _loaded = false;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded && !_loading) _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await AppScope.of(context).campaignApi.list(cursor: reset ? null : _cursor);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _loaded = true;
      });
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _items.isEmpty) {
      return ErrorRetryView(message: describeError(_error!), onRetry: () => _load(reset: true));
    }
    if (!_loaded) return const LoadingView();
    if (_items.isEmpty) {
      return const MessageView(icon: Icons.campaign_outlined, title: 'No hay convocatorias abiertas ahora.');
    }
    return Column(
      key: const Key('campaign-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in _items) _CampaignCard(campaign: c),
        if (_cursor != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              key: const Key('campaign-list-more'),
              onPressed: _loading ? null : _load,
              child: Text(_loading ? 'Cargando…' : 'Cargar más'),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(describeError(_error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ],
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign});
  final CampaignSummary campaign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = int.tryParse(campaign.targetAmount ?? '');
    final cleared = int.tryParse(campaign.clearedAmount ?? '');
    final progress = (target != null && target > 0 && cleared != null) ? (cleared / target).clamp(0.0, 1.0) : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('campaign-${campaign.publicCode}'),
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.campaignPath(campaign.publicCode)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(campaign.title, style: theme.textTheme.titleMedium),
              if (campaign.organizationName != null)
                Text(campaign.organizationName!, style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(
                '${campaignStatusLabel(campaign.status)} · hasta el ${shortDate(campaign.endDate)}'
                '${campaign.acceptedDonationTypes.isEmpty ? '' : ' · ${campaign.acceptedDonationTypes.map(donationTypeLabel).join(', ')}'}',
                style: theme.textTheme.bodySmall,
              ),
              if (progress != null) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(value: progress, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 4),
                Text(
                  '${formatMinorUnits(cleared!, campaign.currency)} de ${formatMinorUnits(target!, campaign.currency)}',
                  style: theme.textTheme.bodySmall,
                ),
              ] else if (cleared != null) ...[
                const SizedBox(height: 6),
                Text('Acreditado: ${formatMinorUnits(cleared, campaign.currency)}', style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
