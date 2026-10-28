import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../app/public_links.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/command_outcome.dart';
import '../../../core/offline/outbox_item.dart';
import '../../../core/offline/outbox_status.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/quantity.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/physical_asset_api.dart';
import '../domain/action_resolver.dart';
import '../domain/asset_action.dart';
import '../domain/asset_operations.dart';
import '../domain/lifecycle_status.dart';
import 'command_form_sheet.dart';
import 'field_action_flow.dart';
import 'outbox_entry_card.dart';

String lifecycleLabel(String wire) => switch (LifecycleStatus.fromWire(wire)) {
  LifecycleStatus.registered => 'Registrado',
  LifecycleStatus.dispatched => 'Despachado',
  LifecycleStatus.received => 'Recibido',
  LifecycleStatus.delivered => 'Entregado',
  LifecycleStatus.depleted => 'Agotado (dividido)',
  null => wire,
};

/// `/assets/:assetRef` (§13): `GET /physical-assets/{assetRef}` + `ActionResolver` + estado del Outbox (incluido
/// `AMBIGUOUS`). Estados: carga; contenido; 403 (también inexistente u otra organización, DD-01); 404; error.
/// La acción solo se **muestra** a `EMPLOYEE` según `/me`; el backend autoriza cada petición (P7).
/// El estado del comando sale del Outbox de la cuenta (H2) y sobrevive a los reinicios.
class AssetScreen extends StatefulWidget {
  const AssetScreen({super.key, required this.assetRef});
  final String assetRef;

  @override
  State<AssetScreen> createState() => _AssetScreenState();
}

class _AssetScreenState extends State<AssetScreen> {
  late final AppServices _services = AppScope.of(context);
  late final PhysicalAssetApi _api = PhysicalAssetApi(_services.apiClient);
  late final AssetOperations _ops = AssetOperations(engine: _services.syncEngine, api: _api);

  PhysicalAssetDto? _asset;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  List<OutboxItem> _entries = const [];
  bool _started = false;

  String? get _accountId => _services.session.principal?.accountId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _services.syncEngine.addListener(_loadEntries);
      _load();
      _loadEntries();
    }
  }

  @override
  void dispose() {
    _services.syncEngine.removeListener(_loadEntries);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final a = await _api.get(widget.assetRef);
      if (!mounted) return;
      setState(() {
        _asset = a;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadEntries() async {
    final account = _accountId;
    if (account == null) return;
    try {
      final all = await _services.syncEngine.entriesFor(account);
      if (!mounted) return;
      setState(() => _entries = all.where((i) => i.resourceRef == widget.assetRef).toList());
    } on AppException {
      // Almacén ilegible: lo explica /operator/pending.
    }
  }

  Future<void> _run(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startAction(AssetAction action) async {
    final account = _accountId;
    if (account == null) return;
    final outcome = await runFieldAction(
      context,
      action: action,
      assetRef: widget.assetRef,
      operations: _ops,
      accountId: account,
    );
    if (outcome == CommandOutcome.acknowledged && mounted) await _load();
    await _loadEntries();
  }

  Future<void> _verify(OutboxItem item) => _run(() async {
    final ok = await _ops.verify(item, accountId: _accountId!);
    if (ok) await _load();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Todavía no podemos confirmarla: el estado no coincide.')));
    }
  });

  Future<void> _send(OutboxItem item) => _run(() async {
    final outcome = await _services.syncEngine.send(item.commandId, _accountId!);
    if (outcome == CommandOutcome.acknowledged) await _load();
  });

  Future<void> _discard(OutboxItem item) async {
    if (!await confirmDiscard(context)) return;
    await _run(() => _services.syncEngine.discard(item.commandId, _accountId!));
  }

  @override
  Widget build(BuildContext context) {
    final qr = _asset == null ? null : PublicLinks(_services.config.publicOrigin).asset(widget.assetRef);
    return AppShell(
      location: AppRoutes.assetPath(widget.assetRef),
      title: 'Activo',
      actions: [
        if (qr != null)
          IconButton(
            key: const Key('asset.qr'),
            tooltip: 'Mostrar QR del activo',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => _services.router.push(AppRoutes.assetQrPath(widget.assetRef)),
          ),
      ],
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading && _asset == null) return const LoadingView();
    final error = _error;
    if (error is ForbiddenException) {
      return const MessageView(
        icon: Icons.lock_outline,
        title: 'No tienes acceso a este activo.',
        detail: 'Puede que no exista o que sea de otra organización.',
      );
    }
    if (error is NotFoundException) {
      return const MessageView(icon: Icons.search_off, title: 'No encontramos este activo. Verifica el código QR.');
    }
    if (error != null && _asset == null) return ErrorRetryView(message: describeError(error), onRetry: _load);

    final a = _asset!;
    final principal = _services.session.principal;
    final action = const ActionResolver().resolveWire(a.lifecycleStatus);
    // Una operación sin resolver (PENDING, IN_FLIGHT, AMBIGUOUS) bloquea otra sobre el mismo activo.
    final unresolved = _entries.any((e) => e.status != OutboxStatus.failed);
    final canShowAction = (principal?.showsOperatorActions ?? false) && action != AssetAction.readOnly && !unresolved;

    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        await _loadEntries();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Activo', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            a.assetRef,
            style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(
              lifecycleLabel(a.lifecycleStatus),
              key: const Key('asset.status'),
              icon: Icons.inventory_2_outlined,
              tone: action == AssetAction.readOnly ? Tone.neutral : Tone.success,
            ),
          ),
          const SizedBox(height: 14),
          if (action == AssetAction.readOnly) ...[
            const NoticeBanner('Este activo ya fue entregado. Solo se puede consultar.', tone: Tone.info),
            const SizedBox(height: 12),
          ],
          for (final e in _entries) ...[
            OutboxEntryCard(
              item: e,
              busy: _busy,
              onSend: () => _send(e),
              onVerify: () => _verify(e),
              onDiscard: () => _discard(e),
              onNewOperation: canShowAction ? () => _startAction(action) : null,
            ),
            const SizedBox(height: 8),
          ],
          // Entregar pide la foto de la entrega dentro del formulario (ADR-051).
          if (canShowAction && !_busy && _entries.isEmpty) ...[
            FilledButton(
              key: const Key('asset.action'),
              onPressed: () => _startAction(action),
              child: Text(actionLabel(action)),
            ),
            const SizedBox(height: 12),
          ],
          if (_busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a.assetType != null)
                  KeyedSubtree(key: const Key('asset.type'), child: LabeledValue('Tipo', a.assetType!)),
                LabeledValue('Cantidad', formatQuantityWithUnit(a.quantity, a.unitOfMeasure)),
                LabeledValue('Custodio actual', a.currentCustodianRef ?? '—', mono: true),
                KeyedSubtree(
                  key: const Key('asset.location'),
                  child: LabeledValue('Ubicación actual', a.currentLocation ?? 'Sin ubicación registrada'),
                ),
                KeyedSubtree(
                  key: const Key('asset.campaign'),
                  child: LabeledValue('Convocatoria', a.campaignRef ?? 'Sin convocatoria', mono: a.campaignRef != null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
