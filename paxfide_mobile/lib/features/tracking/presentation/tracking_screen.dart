import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/money.dart';
import '../../../shared/quantity.dart';
import '../../../shared/theme/pax_theme.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/tracking_api.dart';

String custodianLabel(String c) => switch (c) {
      'LOGISTICS_PARTNER' => 'Empresa de transporte',
      'REGIONAL_WAREHOUSE' => 'Bodega regional',
      'LAST_MILE_CARRIER' => 'Repartidor local',
      'LOCAL_ALLY' => 'Aliado en la zona',
      'UNCATEGORIZED' => '',
      _ => c,
    };

/// `/tracking`: pantalla completa con [TrackingView].
class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) => const AppPage(title: 'Seguimiento', body: TrackingView());
}

/// Seguimiento de una donación (§13), sin código en la ruta (ADR-043 §0): el
/// código se escribe a mano, vive solo en la memoria de esta vista y viaja en
/// la cabecera `Authorization`. Nunca se guarda ni va en una URL. Cualquier
/// fallo del código da un único mensaje y no toca la sesión.
class TrackingView extends StatefulWidget {
  const TrackingView({super.key});

  @override
  State<TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<TrackingView> {
  final _codeField = TextEditingController();
  late final TrackingApi _api = AppScope.of(context).trackingApi;

  String? _code; // en memoria; se borra al salir o con "Consultar otra"
  bool _loading = false;
  String? _error;
  TrackingSummary? _summary;
  TrackingNarrative? _narrative;
  bool _narrativeLoading = false;
  IntegrityReport? _integrity;
  bool _integrityLoading = false;
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
          _error = 'Ese código no es válido o ya venció. Revísalo e inténtalo de nuevo.';
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

  /// Manual: sin polling (regla 3.5).
  Future<void> _loadNarrative() async {
    final code = _code;
    if (code == null) return;
    setState(() => _narrativeLoading = true);
    try {
      final n = await _api.narrative(code);
      if (mounted) setState(() => _narrative = n);
    } on AppException {
      // Sección opcional.
    } finally {
      if (mounted) setState(() => _narrativeLoading = false);
    }
  }

  Future<void> _loadIntegrity() async {
    final code = _code;
    if (code == null) return;
    setState(() => _integrityLoading = true);
    try {
      final r = await _api.integrity(code);
      if (mounted) setState(() => _integrity = r);
    } on AppException {
      if (mounted) setState(() => _integrity = null);
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
  Widget build(BuildContext context) => _summary == null ? _form(context) : _content(context, _summary!);

  Widget _form(BuildContext context) => SectionCard(
        icon: Icons.qr_code_2_rounded,
        title: 'Escribe tu código de seguimiento',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Te lo dimos al terminar tu donación. Puedes pegarlo aquí.',
              style: TextStyle(fontSize: 13, color: PaxPalette.of(context).textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('tracking-code'),
              controller: _codeField,
              enabled: !_loading,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              keyboardType: TextInputType.visiblePassword,
              decoration: const InputDecoration(labelText: 'Código de seguimiento'),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Notice(key: const Key('tracking-error'), kind: NoticeKind.error, text: _error!),
            ],
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('tracking-submit'),
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Buscando…' : 'Ver mi donación'),
            ),
          ],
        ),
      );

  Widget _content(BuildContext context, TrackingSummary s) {
    final f = s.financial;
    final pal = PaxPalette.of(context);
    String money(int v) => formatMinorUnits(v, f.currency);
    final used = f.confirmedAllocationAmount;
    return Column(
      key: const Key('tracking-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Tu donación de ${money(f.originalAmount)}',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: pal.text)),
            ),
            TextButton(key: const Key('tracking-forget'), onPressed: _forget, child: const Text('Consultar otra')),
          ],
        ),
        const SizedBox(height: 8),
        SectionCard(
          icon: Icons.payments_outlined,
          title: '¿Qué pasó con el dinero?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _moneyRow(context, 'Recibido por la organización', money(f.clearedAmount), f.clearedAmount > 0),
              _moneyRow(context, 'Usado para comprar ayudas', money(used), used > 0),
              if (f.pendingAllocationAmount > 0)
                _moneyRow(context, 'Apartado para próximas compras', money(f.pendingAllocationAmount), true),
              if (f.refundedAmount > 0) _moneyRow(context, 'Devuelto', money(f.refundedAmount), true),
              if (f.originalAmount > 0) ...[
                const SizedBox(height: 10),
                ProgressLine(
                  value: used / f.originalAmount,
                  label: used == 0
                      ? 'Aún no se ha usado en compras.'
                      : 'Se ha usado el ${(used * 100 / f.originalAmount).round()} % de tu donación.',
                ),
              ],
            ],
          ),
        ),
        SectionCard(
          icon: Icons.inventory_2_outlined,
          title: '¿Qué se entregó?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.logistics.isEmpty)
                Text('Todavía no se han comprado ni entregado ayudas con tu donación.',
                    style: TextStyle(fontSize: 13, color: pal.textMuted)),
              for (final l in s.logistics)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: Key('tracking-asset-${l.assetRef}'),
                    tilePadding: EdgeInsets.zero,
                    title: Text('${formatQuantity(l.quantity)} ${unitLabel(l.unitOfMeasure)} de ${l.assetType}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: pal.text)),
                    subtitle: Text(
                      [lifecycleLabel(l.lifecycleStatus), l.locationZone].where((x) => x.isNotEmpty).join(' · '),
                      style: TextStyle(color: pal.textMuted),
                    ),
                    onExpansionChanged: (open) {
                      if (open) _loadHistory(l.assetRef);
                    },
                    children: [
                      if (!_history.containsKey(l.assetRef)) const LinearProgressIndicator(),
                      for (final h in _history[l.assetRef] ?? const <HistoryEntry>[])
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.circle, size: 10, color: paxAccent),
                          title: Text(lifecycleLabel(h.status)),
                          subtitle: Text([
                            dateTime(h.timestamp),
                            h.locationZone,
                            custodianLabel(h.custodianCategory),
                          ].where((x) => x.isNotEmpty).join(' · ')),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _integritySection(context),
        _narrativeSection(context),
      ],
    );
  }

  Widget _moneyRow(BuildContext context, String label, String value, bool highlight) {
    final pal = PaxPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, color: pal.textMuted))),
          Text(value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: highlight ? pal.text : pal.textMuted)),
        ],
      ),
    );
  }

  /// Protección del registro (anclaje en blockchain). Solo se afirma
  /// "protegido" con todos los lotes verificados y nada pendiente.
  Widget _integritySection(BuildContext context) {
    final r = _integrity;
    if (_integrityLoading) return const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator());
    if (r == null) return const SizedBox.shrink();
    final notice = r.hasMismatch
        ? const Notice(
            kind: NoticeKind.error,
            title: 'Encontramos una diferencia en el registro',
            text: 'Algo en el registro de tu donación no coincide con la copia protegida. Contacta a la organización.',
          )
        : r.fullyVerified
            ? const Notice(
                kind: NoticeKind.success,
                title: 'Registro protegido',
                text: 'Guardamos una copia del registro de tu donación que nadie puede cambiar, y coincide con lo que ves aquí.',
              )
            : const Notice(
                kind: NoticeKind.warning,
                title: 'Protegiendo el registro',
                text: 'Estamos guardando la copia protegida de tu donación. Vuelve a mirar en unos minutos.',
              );
    final tx = r.batches.map((b) => b.transactionHash).whereType<String>().toList();
    return Column(
      key: const Key('tracking-integrity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        notice,
        if (tx.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Ver comprobante', style: TextStyle(fontSize: 13, color: PaxPalette.of(context).textMuted)),
              children: [
                for (final b in r.batches)
                  Column(
                    children: [
                      if (b.transactionHash != null) LabeledValue('Comprobante', b.transactionHash!),
                      if (b.network != null) LabeledValue('Red', b.network!),
                      if (b.anchoredAt != null) LabeledValue('Fecha', dateTime(b.anchoredAt!)),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _narrativeSection(BuildContext context) {
    final n = _narrative;
    final pal = PaxPalette.of(context);
    return SectionCard(
      key: const Key('tracking-narrative'),
      icon: Icons.auto_stories_outlined,
      title: 'La historia de tu donación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_narrativeLoading)
            const LinearProgressIndicator()
          else if (n == null || n.status == 'PENDING') ...[
            Text(n == null ? 'No pudimos cargarla.' : 'La estamos preparando.',
                style: TextStyle(fontSize: 13, color: pal.textMuted)),
            TextButton(
              key: const Key('tracking-narrative-refresh'),
              onPressed: _loadNarrative,
              child: const Text('Volver a mirar'),
            ),
          ] else
            Text(n.content ?? '', style: TextStyle(fontSize: 14, color: pal.text, height: 1.5)),
        ],
      ),
    );
  }
}
