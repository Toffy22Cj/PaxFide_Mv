import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/command_outcome.dart';
import '../../../core/offline/outbox_item.dart';
import '../../../core/offline/outbox_status.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/quantity.dart';
import '../../../shared/widgets/qr_sheet.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/physical_asset_api.dart';
import '../domain/action_resolver.dart';
import '../domain/asset_action.dart';
import '../domain/lifecycle_status.dart';
import 'command_form_sheet.dart';
import 'outbox_entry_card.dart';

/// `/assets/:assetRef` (§13): `GET /physical-assets/{assetRef}` +
/// `ActionResolver` + estado del Outbox (incluido `AMBIGUOUS`).
///
/// Estados: carga, contenido, 403 (también inexistente u otra organización,
/// DD-01), error. La acción solo se MUESTRA a `EMPLOYEE` según `/me`; el
/// backend autoriza cada petición (P7). El estado del comando sale del Outbox
/// de la cuenta (A1) y sobrevive a los reinicios.
class AssetScreen extends StatefulWidget {
  const AssetScreen({super.key, required this.assetRef});
  final String assetRef;

  @override
  State<AssetScreen> createState() => _AssetScreenState();
}

class _AssetScreenState extends State<AssetScreen> {
  late final AppServices _services = AppScope.of(context);

  PhysicalAssetDto? _asset;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  List<OutboxItem> _entries = const [];
  bool _started = false;

  String? get _accountId => _services.session.value.principal?.accountId;

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
      final a = await _services.physicalAssetApi.get(widget.assetRef);
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

  void _notify(CommandOutcome outcome) {
    final text = switch (outcome) {
      CommandOutcome.acknowledged => 'Operación registrada.',
      CommandOutcome.failed => 'El servidor rechazó la operación.',
      CommandOutcome.ambiguous => 'No pudimos confirmar la operación. Verifica el estado.',
      CommandOutcome.notSent => 'Sin conexión: la operación quedó guardada sin enviar.',
    };
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _startAction(AssetAction action) async {
    final account = _accountId;
    if (account == null) return;
    final cmd = await showCommandForm(context, action, widget.assetRef);
    if (cmd == null || !mounted) return;
    await _run(() async {
      final (_, outcome) = await _services.assetOperations.submit(cmd, accountId: account);
      _notify(outcome);
      if (outcome == CommandOutcome.acknowledged) await _load();
    });
  }

  Future<void> _verify(OutboxItem item) => _run(() async {
        final ok = await _services.assetOperations.verify(item, accountId: _accountId!);
        if (ok) {
          await _load();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Todavía no podemos confirmarla: el estado no coincide.')),
          );
        }
      });

  Future<void> _send(OutboxItem item) => _run(() async {
        final outcome = await _services.syncEngine.send(item.commandId, _accountId!);
        _notify(outcome);
        if (outcome == CommandOutcome.acknowledged) await _load();
      });

  Future<void> _discard(OutboxItem item) async {
    if (!await confirmDiscard(context)) return;
    await _run(() => _services.syncEngine.discard(item.commandId, _accountId!));
  }

  @override
  Widget build(BuildContext context) {
    final qr = _asset == null ? null : _services.publicLinks.asset(widget.assetRef);
    return AppPage(
      title: 'Activo',
      actions: [
        if (qr != null)
          IconButton(
            key: const Key('asset-qr'),
            tooltip: 'Mostrar QR del activo',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => showQrSheet(context, title: 'QR del activo', url: qr),
          ),
        IconButton(
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
          onPressed: _busy
              ? null
              : () async {
                  await _load();
                  await _loadEntries();
                },
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
        key: Key('asset-forbidden'),
        icon: Icons.lock_outline,
        title: 'No tienes acceso a este activo.',
        detail: 'Puede que no exista o que sea de otra organización.',
      );
    }
    if (error != null && _asset == null) return ErrorRetryView(message: describeError(error), onRetry: _load);

    final a = _asset!;
    final principal = _services.session.value.principal;
    AssetAction action;
    bool unknownStatus = false;
    try {
      action = const ActionResolver().resolve(LifecycleStatus.fromApi(a.lifecycleStatus));
    } on UnknownLifecycleStatusException {
      action = AssetAction.readOnly;
      unknownStatus = true;
    }
    // Una operación sin resolver (PENDING, IN_FLIGHT, AMBIGUOUS) bloquea otra
    // sobre el mismo activo (DDM-22).
    final unresolved = _entries.any((e) => e.status != OutboxStatus.failed);
    final canShowAction = (principal?.isFieldOperator ?? false) && action != AssetAction.readOnly && !unresolved;

    return Column(
      key: const Key('asset-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in _entries)
          OutboxEntryCard(
            item: e,
            busy: _busy,
            onSend: () => _send(e),
            onVerify: () => _verify(e),
            onRetrySame: () => _send(e),
            onDiscard: () => _discard(e),
            onNewOperation: canShowAction ? () => _startAction(action) : null,
          ),
        if (canShowAction && !_busy && _entries.isEmpty)
          FilledButton.icon(
            key: const Key('asset-action'),
            onPressed: () => _startAction(action),
            icon: const Icon(Icons.play_arrow),
            label: Text(actionLabel(action)),
          ),
        if (_busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Datos del activo',
          child: Column(
            children: [
              LabeledValue('Referencia', a.assetRef),
              LabeledValue('Estado', lifecycleLabel(a.lifecycleStatus)),
              LabeledValue('Cantidad', formatQuantityWithUnit(a.quantity, a.unitOfMeasure == null ? null : unitLabel(a.unitOfMeasure!))),
              LabeledValue('Custodio actual', a.currentCustodianRef ?? '—'),
              LabeledValue(
                'Ubicación actual',
                a.currentLocation ?? (a.lifecycleStatus == 'DISPATCHED' ? 'En tránsito' : 'Sin ubicación registrada'),
              ),
            ],
          ),
        ),
        if (unknownStatus)
          const Text('Estado desconocido para esta versión de la app: no se ofrecen acciones.')
        else if (action == AssetAction.readOnly)
          const Text('Este activo no tiene más acciones.'),
      ],
    );
  }
}
