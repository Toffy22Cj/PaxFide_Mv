import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_services.dart';
import '../../../app/text_size_button.dart';
import '../../../app/theme_mode_button.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/dates.dart';
import '../../../shared/money.dart';
import '../../../shared/quantity.dart';
import '../../../shared/widgets/error_message.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../physical_assets/domain/lifecycle_status.dart';
import '../data/tracking_api.dart';
import '../../../shared/widgets/pax_app_bar.dart';

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
  const TrackingScreen({super.key, this.initialCode});

  /// Código que llega desde "Mis donaciones" (M-16): se consulta al abrir y vive solo en la memoria de la pantalla.
  final String? initialCode;

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
  TrackingIntegrity? _integrity;
  bool _integrityLoading = false;

  @override
  void initState() {
    super.initState();
    final code = widget.initialCode;
    if (code != null) {
      _codeField.text = code;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submit();
      });
    }
  }

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
      // La narrativa es una sección: si falla, se muestra "Actualizar".
    } finally {
      if (mounted) setState(() => _narrativeLoading = false);
    }
  }

  /// M-18: integridad comprobada por el servidor. Es una sección: si falla, se puede volver a pedir.
  Future<void> _loadIntegrity() async {
    final code = _code;
    if (code == null) return;
    setState(() => _integrityLoading = true);
    try {
      final i = await _api.integrity(code);
      if (mounted) setState(() => _integrity = i);
    } on AppException {
      if (mounted) setState(() => _integrity = null);
    } finally {
      if (mounted) setState(() => _integrityLoading = false);
    }
  }

  void _forget() => setState(() {
    _code = null;
    _summary = null;
    _narrative = null;
    _integrity = null;
  });

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Scaffold(
      appBar: PaxAppBar(
        title: Text(s == null ? 'Seguir una donación' : 'Seguimiento de una donación'),
        actions: const [TextSizeButton(), ThemeModeButton()],
      ),
      body: s == null ? _form(context) : _content(context, s),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Sigue el recorrido de tu aporte', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Escribe el código de seguimiento que recibiste al donar.', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Código',
          child: TextField(
            key: const Key('tracking.code'),
            controller: _codeField,
            enabled: !_loading,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(
              // M-19: pegar el código copiado del correo o del mensaje.
              suffixIcon: TextButton(
                key: const Key('tracking.paste'),
                onPressed: _loading
                    ? null
                    : () async {
                        final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
                        if (text != null && text.isNotEmpty && mounted) setState(() => _codeField.text = text);
                      },
                child: const Text('Pegar'),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          ErrorMessage(_error!, textKey: const Key('tracking.error')),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('tracking.submit'),
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'Ver seguimiento…' : 'Ver seguimiento'),
        ),
        const SizedBox(height: 12),
        Text(
          'El código solo se escribe o se pega aquí. No aparece en un QR.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, TrackingSummary s) {
    final theme = Theme.of(context);
    final f = s.financial;
    final base = f.originalAmount <= 0 ? 1 : f.originalAmount;
    Widget figure(String label, int value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            formatMinorUnits(value, f.currency),
            key: Key('tracking.figure.$label'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          // Decorativa: la cifra ya está en el texto (M-04).
          ExcludeSemantics(child: SlimProgress(value / base)),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: TextButton(
            key: const Key('tracking.other'),
            onPressed: _forget,
            child: const Text('Usar otro código'),
          ),
        ),
        Text('Hechos registrados', style: theme.textTheme.headlineSmall),
        if (s.status != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(
              switch (s.status) {
                'ACTIVA' => 'Donación activa',
                'EN_PROCESO' => 'Donación en proceso',
                _ => s.status!,
              },
              icon: Icons.credit_card,
              tone: Tone.info,
            ),
          ),
        ],
        const SizedBox(height: 12),
        SectionCard(
          title: 'Tu aporte, en cifras',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              figure('Donado', f.originalAmount),
              figure('Acreditado', f.clearedAmount),
              figure('Asignación pendiente', f.pendingAllocationAmount),
              figure('Asignación confirmada', f.confirmedAllocationAmount),
              if (f.refundedAmount > 0) figure('Reembolsado', f.refundedAmount),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Logística', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (s.logistics.isEmpty)
          const SectionCard(
            child: Text(
              'Todavía no hay bienes registrados. Los hechos financieros y el sello se mantienen separados del relato.',
            ),
          ),
        for (final l in s.logistics)
          Card(
            key: Key('tracking.item.${s.logistics.indexOf(l)}'),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openRoute(l),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l.assetType} · ${formatQuantityWithUnit(l.quantity, l.unitOfMeasure)}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                    const SizedBox(height: 8),
                    lifecycleChip(l.lifecycleStatus),
                    const SizedBox(height: 8),
                    Text(
                      [l.locationZone, custodianLabel(l.custodianCategory)].where((x) => x.isNotEmpty).join(' · '),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        // M-18: integridad comprobada por el servidor (`GET /donations/tracking/integrity`). Sin datos, no se afirma nada.
        Card(
          key: const Key('tracking.integrity'),
          child: ListTile(
            leading: Icon(integrityIcon(_integrity?.verdict)),
            title: const Text('Verificación de integridad'),
            subtitle: _integrityLoading
                ? const LinearProgressIndicator()
                : Text(_integrity == null ? 'No se pudo comprobar ahora' : integrityTitle(_integrity!.verdict)),
            trailing: _integrity == null && !_integrityLoading
                ? TextButton(
                    key: const Key('tracking.integrity.retry'),
                    onPressed: _loadIntegrity,
                    child: const Text('Reintentar'),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _integrity == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => VerificationScreen(integrity: _integrity!),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        _narrativeSection(context),
      ],
    );
  }

  /// Recorrido de un bien (Figma 03). El código sigue solo en la memoria de esta pantalla: la otra recibe la consulta.
  void _openRoute(LogisticsItem l) {
    final code = _code;
    if (code == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AssetRouteScreen(item: l, load: () => _api.history(code, l.assetRef)),
      ),
    );
  }

  Widget _narrativeSection(BuildContext context) {
    final n = _narrative;
    final theme = Theme.of(context);
    return SectionCard(
      key: const Key('tracking.narrative'),
      title: 'Relato de la donación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            n != null && n.source == 'FALLBACK_TEMPLATE'
                ? 'Texto de plantilla a partir de los hechos registrados de arriba.'
                : 'Texto generado con IA a partir de los hechos registrados de arriba.',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          if (_narrativeLoading)
            const LinearProgressIndicator()
          else if (n == null || n.status == 'PENDING') ...[
            Text(n == null ? 'No se pudo cargar el relato.' : 'El relato todavía se está preparando.'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('tracking.narrative.refresh'),
                onPressed: _loadNarrative,
                child: const Text('Actualizar'),
              ),
            ),
          ] else
            Text(n.content ?? ''),
        ],
      ),
    );
  }
}

/// Chip del estado de un bien con su ícono.
Widget lifecycleChip(String wire) => StatusChip(_lifecycle(wire), icon: _lifecycleIcon(wire));

IconData _lifecycleIcon(String wire) => switch (LifecycleStatus.fromWire(wire)) {
  LifecycleStatus.registered => Icons.inventory_2_outlined,
  LifecycleStatus.dispatched => Icons.local_shipping_outlined,
  LifecycleStatus.received => Icons.inventory_outlined,
  LifecycleStatus.delivered => Icons.task_alt,
  LifecycleStatus.depleted => Icons.call_split,
  null => Icons.circle_outlined,
};

/// "3 oct 2026, 09:10" en la hora del teléfono; el texto original si no es una fecha.
String formatEventTime(String iso) => shortDateTime(iso);

/// "Recorrido del bien" (Figma 03): cabecera del bien y su línea de tiempo. Estados: cargando, error, sin eventos.
class AssetRouteScreen extends StatefulWidget {
  const AssetRouteScreen({super.key, required this.item, required this.load});
  final LogisticsItem item;
  final Future<List<HistoryEntry>> Function() load;

  @override
  State<AssetRouteScreen> createState() => _AssetRouteScreenState();
}

class _AssetRouteScreenState extends State<AssetRouteScreen> {
  List<HistoryEntry>? _entries;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _failed = false;
      _entries = null;
    });
    try {
      final e = await widget.load();
      if (mounted) setState(() => _entries = e);
    } on AppException {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = widget.item;
    final e = _entries;
    return Scaffold(
      appBar: PaxAppBar(title: const Text('Recorrido del bien')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${l.assetType} · ${formatQuantityWithUnit(l.quantity, l.unitOfMeasure)}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: lifecycleChip(l.lifecycleStatus)),
          const SizedBox(height: 10),
          Text(
            'Del primer registro al último hito confirmado',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (_failed)
            ErrorRetryView(message: 'No pudimos cargar el recorrido.', onRetry: _run)
          else if (e == null)
            const LoadingView(label: 'Cargando recorrido…')
          else if (e.isEmpty)
            const MessageView(
              icon: Icons.timeline,
              title: 'Sin eventos todavía',
              detail: 'Aquí aparecerán los hitos registrados para este bien.',
            )
          else
            RouteTimeline(e),
        ],
      ),
    );
  }
}

/// "a3f9c8d1…c801": el principio y el final de una huella, en monoespaciada.
String shortHash(String h) => h.length <= 16 ? h : '${h.substring(0, 8)}…${h.substring(h.length - 6)}';

String integrityTitle(IntegrityVerdict v) => switch (v) {
  IntegrityVerdict.verified => 'Registro sellado y verificado',
  IntegrityVerdict.partial => 'Lo sellado está verificado; hay registros por sellar',
  IntegrityVerdict.pending => 'Todavía no hay registros sellados',
  IntegrityVerdict.inconclusive => 'No se pudo comprobar en este momento',
  IntegrityVerdict.mismatch => 'Hay una diferencia en el registro: se está revisando',
};

IconData integrityIcon(IntegrityVerdict? v) => switch (v) {
  IntegrityVerdict.verified => Icons.verified_user,
  IntegrityVerdict.mismatch => Icons.gpp_maybe_outlined,
  _ => Icons.verified_user_outlined,
};

Tone _verdictTone(IntegrityVerdict v) => switch (v) {
  IntegrityVerdict.verified => Tone.success,
  IntegrityVerdict.partial || IntegrityVerdict.pending => Tone.pending,
  IntegrityVerdict.inconclusive => Tone.neutral,
  IntegrityVerdict.mismatch => Tone.error,
};

/// Sello de un paso (G-3): en qué punto del anclaje está su huella.
(String, Tone, IconData) anchorLabel(String status) => switch (status) {
  'ANCHORED' => ('Sellado', Tone.success, Icons.lock_outline),
  'IN_BATCH' => ('En lote, por sellar', Tone.pending, Icons.hourglass_bottom),
  'UNDER_REVIEW' => ('En revisión', Tone.error, Icons.gpp_maybe_outlined),
  _ => ('Sin sellar todavía', Tone.neutral, Icons.lock_open_outlined),
};

/// "Ver verificación" (M-18, Figma 03): el resultado que calcula el servidor, lote a lote. La app no recalcula
/// nada: muestra el estado, la red y las huellas.
class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key, required this.integrity});
  final TrackingIntegrity integrity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final v = integrity.verdict;
    return Scaffold(
      appBar: PaxAppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Ver verificación'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(
              integrityTitle(v),
              key: const Key('verification.verdict'),
              icon: integrityIcon(v),
              tone: _verdictTone(v),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Cada registro de tu donación tiene una huella digital. Por lotes, esas huellas se resumen en una raíz que '
            'se ancla en una red pública. El servidor comprueba que la raíz anclada coincide con los registros.',
            style: muted,
          ),
          if (integrity.unanchoredEvents > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${integrity.unanchoredEvents} '
              '${integrity.unanchoredEvents == 1 ? 'registro está' : 'registros están'} esperando su sello.',
              key: const Key('verification.unanchored'),
            ),
          ],
          const SizedBox(height: 16),
          for (final (i, b) in integrity.batches.indexed) ...[
            SectionCard(
              key: Key('verification.batch.$i'),
              title: 'Lote ${i + 1}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LabeledValue('Resultado', switch (b.result) {
                    'MATCH' => 'Coincide',
                    'MISMATCH' => 'No coincide',
                    _ => 'Sin comprobar',
                  }),
                  if (b.reasonText != null) LabeledValue('Detalle', b.reasonText!),
                  LabeledValue('Registros de tu donación', '${b.eventsOfThisDonation}'),
                  if (b.anchoredAt != null) LabeledValue('Sellado', formatEventTime(b.anchoredAt!)),
                  if (b.network != null) LabeledValue('Red', b.network!),
                  if (b.transactionHash != null) LabeledValue('Transacción', shortHash(b.transactionHash!), mono: true),
                  if (b.merkleRoot != null) LabeledValue('Raíz', shortHash(b.merkleRoot!), mono: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (integrity.checkedAt.isNotEmpty)
            Text('Comprobado: ${formatEventTime(integrity.checkedAt)}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// M-17: línea de tiempo del recorrido de un bien, del primer movimiento al último (el actual, resaltado).
class RouteTimeline extends StatelessWidget {
  const RouteTimeline(this.entries, {super.key});
  final List<HistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      key: const Key('tracking.timeline'),
      children: [
        for (final (i, h) in entries.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == entries.length - 1 ? scheme.primary : scheme.primaryContainer,
                        ),
                        child: Icon(
                          _lifecycleIcon(h.status),
                          size: 16,
                          color: i == entries.length - 1 ? scheme.onPrimary : scheme.onPrimaryContainer,
                        ),
                      ),
                      if (i < entries.length - 1) Expanded(child: Container(width: 2, color: scheme.primary)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: i == entries.length - 1 ? scheme.primaryContainer : scheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: i == entries.length - 1 ? null : Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i == entries.length - 1 ? '${_lifecycle(h.status)} · Actual' : _lifecycle(h.status),
                            style: text.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(formatEventTime(h.timestamp), style: text.labelSmall),
                          if (h.locationZone.isNotEmpty) ...[const SizedBox(height: 6), Text(h.locationZone)],
                          if (custodianLabel(h.custodianCategory).isNotEmpty)
                            Text(custodianLabel(h.custodianCategory), style: TextStyle(color: scheme.onSurfaceVariant)),
                          if (h.evidenceRegistered == true) ...[
                            const SizedBox(height: 6),
                            Row(
                              key: Key('tracking.step.$i.evidence'),
                              children: [
                                Icon(Icons.photo_camera_outlined, size: 16, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 6),
                                const Expanded(child: Text('Evidencia de entrega registrada')),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          _StepSeal(entry: h, index: i),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Sello y huella de un paso. La huella completa se lee en voz alta y se puede copiar.
class _StepSeal extends StatelessWidget {
  const _StepSeal({required this.entry, required this.index});
  final HistoryEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = anchorLabel(entry.anchorStatus);
    final hash = entry.eventHash;
    final proof = entry.anchorProof;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusChip(label, key: Key('tracking.step.$index.seal'), icon: icon, tone: tone),
        if (hash != null)
          Semantics(
            label: 'Huella del registro: $hash',
            excludeSemantics: true,
            child: InkWell(
              key: Key('tracking.step.$index.hash'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: hash));
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Huella copiada.')));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Huella: ${shortHash(hash)}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: muted),
                ),
              ),
            ),
          ),
        if (proof != null)
          Text(
            'Sellado en ${proof.network}${proof.anchoredAt == null ? '' : ', ${formatEventTime(proof.anchoredAt!)}'}',
            key: Key('tracking.step.$index.proof'),
            style: TextStyle(fontSize: 13, color: muted),
          ),
      ],
    );
  }
}
