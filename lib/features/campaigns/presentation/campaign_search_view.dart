import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/campaign_progress.dart';
import '../domain/campaign_search.dart';

/// M-10: buscar, filtrar y ordenar convocatorias. Aún sin ruta (`/campaigns` está diferida hasta la enmienda de
/// ADR-043) ni backend (enmienda de ADR-041): depende solo de [CampaignSearch].
class CampaignSearchView extends StatefulWidget {
  const CampaignSearchView({super.key, required this.search, required this.onOpen});
  final CampaignSearch search;
  final ValueChanged<String> onOpen;

  @override
  State<CampaignSearchView> createState() => _CampaignSearchViewState();
}

class _CampaignSearchViewState extends State<CampaignSearchView> {
  final _text = TextEditingController();
  CampaignQuery _query = const CampaignQuery();
  List<CampaignSummary>? _items;
  Object? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _items = null;
      _error = null;
    });
    final q = _query;
    try {
      final items = await widget.search.search(q);
      if (mounted && identical(q, _query)) setState(() => _items = items);
    } on CampaignSearchUnavailable catch (e) {
      if (mounted) setState(() => _error = e);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _update(CampaignQuery q) {
    _query = q;
    _run();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            key: const Key('campaigns.search'),
            controller: _text,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar por nombre de la convocatoria u organización',
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () => _update(_query.copyWith(text: v.trim())));
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilterChip(
                key: const Key('campaigns.openOnly'),
                label: const Text('Solo abiertas'),
                selected: _query.openOnly,
                onSelected: (v) => _update(_query.copyWith(openOnly: v)),
              ),
              const SizedBox(width: 8),
              for (final s in CampaignSort.values) ...[
                ChoiceChip(
                  key: Key('campaigns.sort.${s.name}'),
                  label: Text(s.label),
                  selected: _query.sort == s,
                  onSelected: (_) => _update(_query.copyWith(sort: s)),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(child: _results()),
      ],
    );
  }

  Widget _results() {
    final e = _error;
    if (e is CampaignSearchUnavailable) {
      return const MessageView(
        key: Key('campaigns.unavailable'),
        icon: Icons.search_off,
        title: 'La búsqueda de convocatorias todavía no está disponible.',
        detail: 'Puedes abrir una convocatoria con su código QR o su enlace.',
      );
    }
    if (e != null) return ErrorRetryView(message: describeError(e), onRetry: _run);
    final items = _items;
    if (items == null) return const LoadingView();
    if (items.isEmpty) {
      return const MessageView(icon: Icons.search, title: 'No encontramos convocatorias con esa búsqueda.');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final c in items)
          Card(
            child: ListTile(
              key: Key('campaigns.item.${c.publicCode}'),
              title: Text(c.title),
              subtitle: Text(
                [
                  c.organizationName,
                  CampaignProgress.of(endDate: c.endDate).daysText ?? '',
                ].where((x) => x.isNotEmpty).join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.onOpen(c.publicCode),
            ),
          ),
      ],
    );
  }
}
