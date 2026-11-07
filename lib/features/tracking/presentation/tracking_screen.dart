export 'tracking_story_view.dart' show formatEventTime, shortHash, custodianLabel;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/text_size_button.dart';
import '../../../app/theme_mode_button.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/money.dart';
import '../../../shared/widgets/error_message.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../../shared/motion/pax_motion.dart';
import '../../../shared/widgets/loaders.dart';
import '../data/tracking_api.dart';
import '../domain/tracking_map.dart';
import '../domain/tracking_story.dart';
import 'tracking_map_view.dart';
import 'tracking_story_view.dart';
import '../../../shared/widgets/pax_app_bar.dart';
import '../../../shared/motion/pax_route.dart';

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

/// Forma de un `trackingCode` (dos bloques Base64 URL separados por un punto, como lo emite el backend). Solo sirve
/// para decidir si se pega solo: el backend sigue siendo quien dice si vale.
final _trackingCodeShape = RegExp(r'^[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}$');

bool looksLikeTrackingCode(String text) => text.length <= 512 && _trackingCodeShape.hasMatch(text);

class _TrackingScreenState extends State<TrackingScreen> with WidgetsBindingObserver {
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

  /// Recorrido de cada lote: se piden todos al abrir, cada uno con el código en `Authorization`.
  final Map<String, HistoryState> _histories = {};

  /// El campo se llenó solo con el código del portapapeles (5c): se avisa y se puede borrar.
  bool _autoPasted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadZones();
    final code = widget.initialCode;
    if (code == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoPaste());
    }
    if (code != null) {
      _codeField.text = code;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submit();
      });
    }
  }

  /// Al volver a la app (p. ej. tras copiar el código en el correo), se vuelve a mirar el portapapeles.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoPaste();
  }

  /// Pegado automático: solo con el formulario a la vista y el campo vacío, y solo si lo copiado tiene la forma de un
  /// código de seguimiento. El código sigue solo en la memoria de esta pantalla (ADR-043 §0).
  Future<void> _autoPaste() async {
    if (!mounted || _summary != null || _loading || _codeField.text.isNotEmpty) return;
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    } on Object {
      return; // sin portapapeles (plataforma o permiso): se escribe o se pega a mano
    }
    if (text == null || !looksLikeTrackingCode(text)) return;
    if (!mounted || _summary != null || _codeField.text.isNotEmpty) return;
    setState(() {
      _codeField.text = text!;
      _autoPasted = true;
      _error = null;
    });
  }

  void _clearAutoPaste() => setState(() {
    _codeField.clear();
    _autoPasted = false;
  });

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeField.dispose();
    _code = null;
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeField.text.trim();
    if (code.isEmpty) return;
    // Un enlace de PaxFide pegado aquí pasa por el único DeepLinkParser (D9 R1) y nunca viaja como código.
    final services = AppScope.of(context);
    final link = services.deepLinkParser.parseText(code);
    if (link.isApproved) {
      if (link.route == AppRoutes.tracking) {
        // El parser descarta el código de un enlace de seguimiento a propósito (ADR-043 §0).
        setState(() => _error = 'Ese enlace no trae el código. Pega el código de seguimiento que recibiste al donar.');
        return;
      }
      _codeField.clear();
      setState(() => _autoPasted = false);
      await services.router.openDeepLink(link);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _api.summary(code);
      if (!mounted) return;
      _codeField.clear();
      setState(() {
        _autoPasted = false;
        _code = code;
        _summary = s;
        _loading = false;
      });
      _loadNarrative();
      _loadIntegrity();
      for (final l in s.logistics) {
        _loadHistory(l.assetRef);
      }
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

  Future<void> _loadHistory(String assetRef) async {
    final code = _code;
    if (code == null) return;
    setState(() => _histories[assetRef] = const HistoryLoading());
    try {
      final h = await _api.history(code, assetRef);
      if (mounted && _code == code) setState(() => _histories[assetRef] = HistoryReady(h));
    } on AppException {
      if (mounted && _code == code) setState(() => _histories[assetRef] = const HistoryFailed());
    }
  }

  void _forget() => setState(() {
    _code = null;
    _summary = null;
    _narrative = null;
    _integrity = null;
    _histories.clear();
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
                        if (text != null && text.isNotEmpty && mounted) {
                          setState(() {
                            _codeField.text = text;
                            _autoPasted = false;
                          });
                        }
                      },
                child: const Text('Pegar'),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        if (_autoPasted) ...[
          const SizedBox(height: 10),
          Row(
            key: const Key('tracking.autoPasted'),
            children: [
              Icon(Icons.content_paste_go, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('Pegamos el código que copiaste.')),
              TextButton(
                key: const Key('tracking.autoPasted.clear'),
                onPressed: _loading ? null : _clearAutoPaste,
                child: const Text('Borrar'),
              ),
            ],
          ),
        ],
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
    final muted = theme.colorScheme.onSurfaceVariant;
    final f = s.financial;
    final base = f.originalAmount <= 0 ? 1 : f.originalAmount;
    final campaignLine = [s.campaignTitle, s.organizationName].whereType<String>().join(' · ');
    final payment = PaymentFacts(
      firstClearedAt: f.firstClearedAt,
      lastClearedAt: f.lastClearedAt,
      amount: f.originalAmount,
      currency: f.currency,
    );
    final assets = s.logistics.length;
    Widget figure(String label, int value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
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
    Widget columnTag(String text, Color dot) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: TextStyle(fontFamily: 'monospace', fontSize: 11, letterSpacing: 0.6, color: muted),
          ),
        ],
      ),
    );
    var i = 0;
    Widget rise(Widget w) => RiseIn(index: i++, child: w);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cabecera de la historia (web: kicker, título, campaña y estado).
        rise(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DONACIÓN · ${formatMinorUnits(f.originalAmount, f.currency)}',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 0.5, color: muted),
              ),
              const SizedBox(height: 4),
              Text('Historia de tu donación', style: theme.textTheme.headlineSmall),
              if (campaignLine.isNotEmpty)
                Text(
                  campaignLine,
                  key: const Key('tracking.campaign'),
                  style: TextStyle(color: muted),
                ),
              const SizedBox(height: 8),
              StatusChip(
                [
                  if (s.status != null) donationStateLabel(s.status!),
                  if (assets > 0) assets == 1 ? '1 bien' : '$assets bienes',
                ].join(' · '),
                key: const Key('tracking.pill'),
                icon: Icons.volunteer_activism_outlined,
                tone: Tone.info,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('tracking.other'),
                  onPressed: _forget,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text('Usar otro código'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        rise(columnTag('Recorrido', theme.colorScheme.primary)),
        rise(TrackingTree(items: s.logistics, payment: payment, histories: _histories, onRetry: _loadHistory)),
        // M-25 (ADR del mapa, D4): el mapa bajo el árbol, solo con teselas configuradas y algún paso con punto.
        if (_mapRoutes(s) case final routes when routes.isNotEmpty) ...[
          if (AppScope.of(context).config.mapTileUrl case final tiles?) ...[
            const SizedBox(height: 12),
            rise(TrackingMapView(routes: routes, tileUrl: tiles, tileProvider: AppScope.of(context).mapTileProvider)),
          ],
        ],
        if (s.logistics.isNotEmpty) ...[
          const SizedBox(height: 20),
          rise(columnTag('Recorrido en serpiente', theme.colorScheme.tertiary)),
          rise(
            SnakeRoute(
              items: s.logistics,
              histories: _histories,
              payment: payment,
              campaignLine: campaignLine.isEmpty ? null : campaignLine,
            ),
          ),
        ],
        const SizedBox(height: 20),
        rise(columnTag('Detalle y verificación', theme.colorScheme.secondary)),
        // M-18: integridad comprobada por el servidor (`GET /donations/tracking/integrity`). Sin datos, no se afirma nada.
        rise(_integrityCard(context)),
        const SizedBox(height: 12),
        rise(
          SectionCard(
            title: 'Hechos registrados',
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
        ),
        const SizedBox(height: 12),
        _narrativeSection(context),
        const SizedBox(height: 12),
        Text.rich(
          const TextSpan(
            children: [
              TextSpan(
                text: 'Privacidad y transparencia: ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: 'los custodios se identifican solo por su categoría. Nunca se muestra quién recibe la ayuda.',
              ),
            ],
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }

  /// La tabla de zonas de la app, leída una vez por apertura (M-25).
  static ZonePoints? _zoneTable;
  ZonePoints? _zones = _zoneTable;

  Future<void> _loadZones() async {
    if (_zones != null) return;
    try {
      final zones = _zoneTable = ZonePoints.parse(await rootBundle.loadString('assets/map/zonas.json'));
      if (mounted) setState(() => _zones = zones);
    } on Object {
      // sin tabla no hay mapa; la línea de tiempo sigue igual
    }
  }

  /// Los recorridos del mapa: con el historial ya cargado, sus paradas; si no, la zona actual del lote.
  List<MapRoute> _mapRoutes(TrackingSummary s) {
    final zones = _zones;
    if (zones == null) return const [];
    return routesFor(
      s.logistics,
      (ref) => switch (_histories[ref]) {
        HistoryReady(:final entries) => entries,
        _ => null,
      },
      zones,
    );
  }

  Widget _integrityCard(BuildContext context) {
    final i = _integrity;
    return Card(
      key: const Key('tracking.integrity'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: PaxMotion.of(context, PaxMotion.normal),
        curve: PaxMotion.standard,
        child: _integrityLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: Column(children: [MerkleTreeLoader(), SizedBox(height: 4), Text('Verificando integridad…')]),
              )
            : ListTile(
                leading: Icon(integrityIcon(i?.verdict)),
                title: const Text('Verificación de integridad'),
                subtitle: Text(i == null ? 'No se pudo comprobar ahora' : integrityTitle(i.verdict)),
                trailing: i == null
                    ? TextButton(
                        key: const Key('tracking.integrity.retry'),
                        onPressed: _loadIntegrity,
                        child: const Text('Reintentar'),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: i == null
                    ? null
                    : () => Navigator.of(context).push(
                        PaxPageRoute<void>(fullscreenDialog: true, builder: (_) => VerificationScreen(integrity: i)),
                      ),
              ),
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
