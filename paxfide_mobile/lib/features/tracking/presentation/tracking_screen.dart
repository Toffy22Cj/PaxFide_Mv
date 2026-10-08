import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/money.dart';
import '../../../shared/quantity.dart';
import '../../../shared/widgets/amount_bars.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/tracking_api.dart';

String custodianLabel(String c) => switch (c) {
      'LOGISTICS_PARTNER' => 'Operador logístico',
      'REGIONAL_WAREHOUSE' => 'Bodega regional',
      'LAST_MILE_CARRIER' => 'Transporte de última milla',
      'LOCAL_ALLY' => 'Aliado local',
      'UNCATEGORIZED' => 'Sin categoría',
      _ => c,
    };

/// `/tracking` (§13), sin código en la ruta (ADR-043 §0): el código se escribe
/// a mano, vive solo en la memoria de esta pantalla y viaja en la cabecera
/// `Authorization`. Nunca se persiste, se registra ni se pone en una URL.
/// Cualquier fallo del código da un único mensaje y no toca la sesión.
/// Narrativa `PENDING`: "Actualizar" manual, sin polling.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _codeField = TextEditingController();
  late final TrackingApi _api = AppScope.of(context).trackingApi;

  String? _code; // en memoria; se borra al salir o con "Usar otro código"
  bool _loading = false;
  String? _error;
  TrackingSummary? _summary;
  TrackingNarrative? _narrative;
  bool _narrativeLoading = false;
  IntegrityReport? _integrity;
  bool _integrityLoading = false;
  bool _integrityFailed = false;
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
      _loadIntegrity();
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
      // Sección: si falla, se ofrece "Actualizar".
    } finally {
      if (mounted) setState(() => _narrativeLoading = false);
    }
  }

  Future<void> _loadIntegrity() async {
    final code = _code;
    if (code == null) return;
    setState(() {
      _integrityLoading = true;
      _integrityFailed = false;
    });
    try {
      final r = await _api.integrity(code);
      if (mounted) setState(() => _integrity = r);
    } on AppException {
      if (mounted) setState(() => _integrityFailed = true);
    } finally {
      if (mounted) setState(() => _integrityLoading = false);
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
        _integrity = null;
        _history.clear();
      });

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Seguimiento',
      actions: [
        if (_summary != null)
          TextButton(key: const Key('tracking-forget'), onPressed: _forget, child: const Text('Usar otro código')),
      ],
      body: _summary == null ? _form(context) : _content(context, _summary!),
    );
  }

  Widget _form(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Escribe el código de seguimiento que recibiste al donar.'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('tracking-code'),
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
            Text(_error!, key: const Key('tracking-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('tracking-submit'),
            onPressed: _loading ? null : _submit,
            child: Text(_loading ? 'Consultando…' : 'Ver seguimiento'),
          ),
        ],
      );

  Widget _content(BuildContext context, TrackingSummary s) {
    final f = s.financial;
    return Column(
      key: const Key('tracking-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Dinero',
          trailing: s.status == null
              ? null
              : Chip(
                  label: Text(switch (s.status) {
                    'ACTIVA' => 'Donación activa',
                    'EN_PROCESO' => 'Donación en proceso',
                    _ => s.status!,
                  }),
                ),
          child: AmountBars(
            bars: [
              AmountBar('Donado', f.originalAmount, formatMinorUnits(f.originalAmount, f.currency)),
              AmountBar('Acreditado', f.clearedAmount, formatMinorUnits(f.clearedAmount, f.currency)),
              AmountBar('Asignación pendiente', f.pendingAllocationAmount,
                  formatMinorUnits(f.pendingAllocationAmount, f.currency)),
              AmountBar('Asignación confirmada', f.confirmedAllocationAmount,
                  formatMinorUnits(f.confirmedAllocationAmount, f.currency)),
              if (f.refundedAmount > 0)
                AmountBar('Reembolsado', f.refundedAmount, formatMinorUnits(f.refundedAmount, f.currency)),
            ],
          ),
        ),
        SectionCard(
          title: 'Bienes entregados',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.logistics.isEmpty) const Text('Todavía no hay bienes registrados con esta donación.'),
              for (final l in s.logistics)
                ExpansionTile(
                  key: Key('tracking-asset-${l.assetRef}'),
                  tilePadding: EdgeInsets.zero,
                  title: Text('${l.assetType} · ${formatQuantity(l.quantity)} ${unitLabel(l.unitOfMeasure)}'),
                  subtitle: Text([
                    lifecycleLabel(l.lifecycleStatus),
                    l.locationZone,
                    custodianLabel(l.custodianCategory),
                  ].where((x) => x.isNotEmpty).join(' · ')),
                  onExpansionChanged: (open) {
                    if (open) _loadHistory(l.assetRef);
                  },
                  children: [
                    if (!_history.containsKey(l.assetRef)) const LinearProgressIndicator(),
                    for (final h in _history[l.assetRef] ?? const <HistoryEntry>[])
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.circle, size: 10),
                        title: Text(lifecycleLabel(h.status)),
                        subtitle: Text([
                          h.timestamp.replaceFirst('T', ' ').split('.').first,
                          h.locationZone,
                          custodianLabel(h.custodianCategory),
                        ].where((x) => x.isNotEmpty).join(' · ')),
                      ),
                  ],
                ),
            ],
          ),
        ),
        _integritySection(context),
        _narrativeSection(context),
      ],
    );
  }

  /// `GET /donations/tracking/integrity`: anclaje en blockchain de los
  /// registros de esta donación y su verificación. Solo se afirma "verificada"
  /// con todos los lotes en `MATCH` y nada sin anclar.
  Widget _integritySection(BuildContext context) {
    final theme = Theme.of(context);
    final r = _integrity;
    Widget body;
    if (_integrityLoading) {
      body = const LinearProgressIndicator();
    } else if (r == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_integrityFailed ? 'No pudimos consultar la verificación.' : 'Sin consultar.'),
          TextButton(onPressed: _loadIntegrity, child: const Text('Reintentar')),
        ],
      );
    } else {
      final (icon, color, headline) = r.hasMismatch
          ? (Icons.gpp_bad_outlined, theme.colorScheme.error, 'Se detectó una diferencia en los registros')
          : r.fullyVerified
              ? (Icons.verified_outlined, const Color(0xFF10B981), 'Anclada y verificada')
              : (Icons.hourglass_bottom, theme.colorScheme.outline, 'En proceso de anclaje o sin verificar');
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(headline, key: const Key('tracking-integrity-headline'), style: theme.textTheme.titleSmall)),
          ]),
          if (r.unanchoredEvents > 0) Text('Registros aún sin anclar: ${r.unanchoredEvents}'),
          for (final b in r.batches) ...[
            const Divider(),
            LabeledValue('Resultado', b.result),
            if (b.reasonText != null) LabeledValue('Motivo', b.reasonText!),
            LabeledValue('Estado del anclaje', b.anchorStatus),
            if (b.network != null) LabeledValue('Red', b.network!),
            if (b.transactionHash != null) LabeledValue('Transacción', b.transactionHash!),
            if (b.confirmedBlockNumber != null) LabeledValue('Bloque', b.confirmedBlockNumber!),
            if (b.merkleRoot != null) LabeledValue('Raíz Merkle', b.merkleRoot!),
            LabeledValue('Registros de esta donación', '${b.eventsOfThisDonation}'),
          ],
        ],
      );
    }
    return SectionCard(key: const Key('tracking-integrity'), title: 'Verificación de integridad', child: body);
  }

  Widget _narrativeSection(BuildContext context) {
    final n = _narrative;
    final theme = Theme.of(context);
    return SectionCard(
      key: const Key('tracking-narrative'),
      title: 'Relato de la donación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_narrativeLoading)
            const LinearProgressIndicator()
          else if (n == null || n.status == 'PENDING') ...[
            Text(n == null ? 'No pudimos cargar el relato.' : 'El relato todavía se está preparando.'),
            TextButton(
              key: const Key('tracking-narrative-refresh'),
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
    );
  }
}
