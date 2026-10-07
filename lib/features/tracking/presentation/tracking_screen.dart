import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/amount_bars.dart';
import '../../physical_assets/domain/lifecycle_status.dart';
import '../data/tracking_api.dart';

String custodianLabel(String c) => switch (c) {
  'LOGISTICS_PARTNER' => 'Operador logístico',
  'REGIONAL_WAREHOUSE' => 'Bodega regional',
  'LAST_MILE_CARRIER' => 'Transporte de última milla',
  'LOCAL_ALLY' => 'Aliado local',
  'UNCATEGORIZED' => 'Sin categoría',
  _ => c,
};

String _lifecycle(String wire) => switch (LifecycleStatus.fromWire(wire)) {
  LifecycleStatus.registered => 'Registrado',
  LifecycleStatus.dispatched => 'En camino',
  LifecycleStatus.received => 'Recibido',
  LifecycleStatus.delivered => 'Entregado',
  LifecycleStatus.depleted => 'Dividido',
  null => wire,
};

/// `/tracking` (§13), **sin código en la ruta**: el código se escribe a mano, vive solo en la memoria de esta
/// pantalla y viaja en la cabecera `Authorization`. Nunca se persiste, se registra ni se pone en una URL.
/// Cualquier fallo del código: un único mensaje "código no válido o expirado", sin tocar la sesión.
/// Narrativa `PENDING`: "Actualizar" manual, sin polling.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _codeField = TextEditingController();
  late final TrackingApi _api = TrackingApi(AppScope.of(context).apiClient);

  String? _code; // en memoria; se borra al salir o con "Usar otro código"
  bool _loading = false;
  String? _error;
  TrackingSummary? _summary;
  TrackingNarrative? _narrative;
  bool _narrativeLoading = false;
  final Map<String, List<HistoryEntry>> _history = {};

  @override
  void dispose() {
    _codeField.dispose();
    _code = null;
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeField.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _api.summary(code);
      if (!mounted) return;
      _codeField.clear();
      setState(() {
        _code = code;
        _summary = s;
        _loading = false;
      });
      _loadNarrative();
    } on InvalidTrackingCodeException {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Código no válido o expirado.';
        });
      }
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = describeError(e);
        });
      }
    }
  }

  Future<void> _loadNarrative() async {
    final code = _code;
    if (code == null) return;
    setState(() => _narrativeLoading = true);
    try {
      final n = await _api.narrative(code);
      if (mounted) setState(() => _narrative = n);
    } on AppException {
      // La narrativa es una sección: si falla, se muestra "Actualizar".
    } finally {
      if (mounted) setState(() => _narrativeLoading = false);
    }
  }

  Future<void> _loadHistory(String assetRef) async {
    final code = _code;
    if (code == null || _history.containsKey(assetRef)) return;
    try {
      final h = await _api.history(code, assetRef);
      if (mounted) setState(() => _history[assetRef] = h);
    } on AppException {
      if (mounted) setState(() => _history[assetRef] = const []);
    }
  }

  void _forget() => setState(() {
    _code = null;
    _summary = null;
    _narrative = null;
    _history.clear();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento de una donación'),
        actions: [if (_summary != null) TextButton(onPressed: _forget, child: const Text('Usar otro código'))],
      ),
      body: _summary == null ? _form(context) : _content(context, _summary!),
    );
  }

  Widget _form(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text('Escribe el código de seguimiento que recibiste al donar.'),
      const SizedBox(height: 16),
      TextField(
        key: const Key('tracking.code'),
        controller: _codeField,
        enabled: !_loading,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        keyboardType: TextInputType.visiblePassword,
        decoration: const InputDecoration(labelText: 'Código de seguimiento', border: OutlineInputBorder()),
        onSubmitted: (_) => _submit(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          key: const Key('tracking.error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton(
        key: const Key('tracking.submit'),
        onPressed: _loading ? null : _submit,
        child: const Text('Ver seguimiento'),
      ),
    ],
  );

  Widget _content(BuildContext context, TrackingSummary s) {
    final f = s.financial;
    final cur = f.currency ?? '';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Hechos registrados', style: Theme.of(context).textTheme.titleMedium),
        if (s.status != null)
          Text(switch (s.status) {
            'ACTIVA' => 'Donación activa',
            'EN_PROCESO' => 'Donación en proceso',
            _ => s.status!,
          }),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AmountBars(
              unit: cur,
              bars: [
                AmountBar('Donado', f.originalAmount),
                AmountBar('Acreditado', f.clearedAmount),
                AmountBar('Asignación pendiente', f.pendingAllocationAmount),
                AmountBar('Asignación confirmada', f.confirmedAllocationAmount),
                if (f.refundedAmount > 0) AmountBar('Reembolsado', f.refundedAmount),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Logística', style: Theme.of(context).textTheme.titleMedium),
        if (s.logistics.isEmpty)
          const Padding(padding: EdgeInsets.all(8), child: Text('Todavía no hay bienes registrados.')),
        for (final l in s.logistics)
          Card(
            child: ExpansionTile(
              title: Text('${l.assetType} · ${l.quantity} ${l.unitOfMeasure}'),
              subtitle: Text(
                [
                  _lifecycle(l.lifecycleStatus),
                  l.locationZone,
                  custodianLabel(l.custodianCategory),
                ].where((x) => x.isNotEmpty).join(' · '),
              ),
              onExpansionChanged: (open) {
                if (open) _loadHistory(l.assetRef);
              },
              children: [
                if (!_history.containsKey(l.assetRef)) const LinearProgressIndicator(),
                for (final h in _history[l.assetRef] ?? const <HistoryEntry>[])
                  ListTile(
                    dense: true,
                    title: Text(_lifecycle(h.status)),
                    subtitle: Text(
                      [
                        h.timestamp,
                        h.locationZone,
                        custodianLabel(h.custodianCategory),
                      ].where((x) => x.isNotEmpty).join(' · '),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _narrativeSection(context),
      ],
    );
  }

  Widget _narrativeSection(BuildContext context) {
    final n = _narrative;
    final theme = Theme.of(context);
    return Card(
      key: const Key('tracking.narrative'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relato de la donación', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            if (_narrativeLoading)
              const LinearProgressIndicator()
            else if (n == null || n.status == 'PENDING') ...[
              Text(n == null ? 'No pudimos cargar el relato.' : 'El relato todavía se está preparando.'),
              TextButton(
                key: const Key('tracking.narrative.refresh'),
                onPressed: _loadNarrative,
                child: const Text('Actualizar'),
              ),
            ] else ...[
              Text(n.content ?? ''),
              const SizedBox(height: 8),
              Text(
                n.source == 'LLM_GENERATED'
                    ? 'Texto generado con IA a partir de los hechos registrados de arriba.'
                    : 'Texto de plantilla a partir de los hechos registrados de arriba.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
