import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/command_outcome.dart';
import '../../../core/offline/outbox_item.dart';
import '../../../core/offline/outbox_status.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/quantity.dart';
import '../../../shared/theme/pax_theme.dart';
import '../../../shared/widgets/qr_sheet.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/physical_asset_api.dart';
import '../domain/action_resolver.dart';
import '../domain/asset_action.dart';
import '../domain/lifecycle_status.dart';
import 'command_form_sheet.dart';
import 'outbox_entry_card.dart';

/// `/assets/:assetRef` (§13): un envío, su recorrido y el siguiente paso.
///
/// El botón del paso solo se MUESTRA a `EMPLOYEE` según `/me`; el backend
/// autoriza cada petición (P7). Los pasos se guardan en el Outbox de la
/// cuenta (A1) y sobreviven a los reinicios. Un 403 es estado de pantalla.
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
      // Almacén ilegible: lo explica la pantalla de pendientes.
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
      CommandOutcome.acknowledged => 'Listo, quedó registrado.',
      CommandOutcome.failed => 'No se pudo registrar.',
      CommandOutcome.ambiguous => 'Se cortó la conexión. Toca "Comprobar" para ver si quedó registrado.',
      CommandOutcome.notSent => 'Sin conexión: lo guardamos en el teléfono para enviarlo después.',
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sí quedó registrado.')));
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Todavía no aparece registrado. Puedes enviarlo otra vez.')),
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
      title: 'Envío',
      actions: [
        if (qr != null)
          IconButton(
            key: const Key('asset-qr'),
            tooltip: 'Mostrar código QR del envío',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => showQrSheet(context, title: 'Código QR del envío', url: qr),
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
        title: 'No puedes ver este envío.',
        detail: 'Puede que el código sea incorrecto o que pertenezca a otra organización.',
      );
    }
    if (error != null && _asset == null) return ErrorRetryView(message: describeError(error), onRetry: _load);

    final a = _asset!;
    final p = PaxPalette.of(context);
    final principal = _services.session.value.principal;
    LifecycleStatus? status;
    AssetAction action;
    try {
      status = LifecycleStatus.fromApi(a.lifecycleStatus);
      action = const ActionResolver().resolve(status);
    } on UnknownLifecycleStatusException {
      action = AssetAction.readOnly;
    }
    // Un paso sin resolver bloquea otro sobre el mismo envío (DDM-22).
    final unresolved = _entries.any((e) => e.status != OutboxStatus.failed);
    final canShowAction = (principal?.isFieldOperator ?? false) && action != AssetAction.readOnly && !unresolved;
    final unit = a.unitOfMeasure == null ? null : unitLabel(a.unitOfMeasure!);

    return Column(
      key: const Key('asset-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(formatQuantityWithUnit(a.quantity, unit),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: p.text)),
        const SizedBox(height: 4),
        Text(
          a.currentLocation ?? (a.lifecycleStatus == 'DISPATCHED' ? 'En camino' : 'Sin ubicación registrada'),
          style: TextStyle(fontSize: 13.5, color: p.textMuted),
        ),
        const SizedBox(height: 16),
        _Journey(status: status),
        const SizedBox(height: 16),
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
        if (canShowAction && _entries.isEmpty)
          SectionCard(
            icon: Icons.flag_outlined,
            title: 'Siguiente paso: ${actionLabel(action)}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(actionHint(action), style: TextStyle(fontSize: 13, color: p.textMuted)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('asset-action'),
                  onPressed: _busy ? null : () => _startAction(action),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(actionLabel(action)),
                ),
              ],
            ),
          ),
        if (status == null)
          const Notice(text: 'No reconocemos el estado de este envío. Actualiza la app.')
        else if (action == AssetAction.readOnly)
          const Notice(kind: NoticeKind.success, text: 'Este envío ya terminó su recorrido.'),
        if (_busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
        SectionCard(
          icon: Icons.info_outline,
          title: 'Datos del envío',
          child: Column(
            children: [
              LabeledValue('Estado', lifecycleLabel(a.lifecycleStatus)),
              LabeledValue('Cantidad', formatQuantityWithUnit(a.quantity, unit)),
              LabeledValue('A cargo de', a.currentCustodianRef ?? '—'),
              LabeledValue('Código', a.assetRef),
            ],
          ),
        ),
      ],
    );
  }
}

/// Recorrido de un envío: En bodega → En camino → Recibido → Entregado.
class _Journey extends StatelessWidget {
  const _Journey({required this.status});
  final LifecycleStatus? status;

  static const _steps = [
    (LifecycleStatus.registered, 'En bodega', Icons.warehouse_outlined),
    (LifecycleStatus.dispatched, 'En camino', Icons.local_shipping_outlined),
    (LifecycleStatus.received, 'Recibido', Icons.inventory_outlined),
    (LifecycleStatus.delivered, 'Entregado', Icons.volunteer_activism_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    final current = status == LifecycleStatus.depleted
        ? _steps.length
        : _steps.indexWhere((s) => s.$1 == status);
    return Row(
      key: const Key('asset-journey'),
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= current ? paxAccent : p.surfaceAlt,
                    border: Border.all(color: i <= current ? paxAccent : p.border),
                  ),
                  child: Icon(_steps[i].$3, size: 18, color: i <= current ? Colors.white : p.textMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[i].$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: i == current ? FontWeight.w800 : FontWeight.w500,
                    color: i <= current ? p.text : p.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (i < _steps.length - 1)
            Container(
              width: 18,
              height: 2,
              margin: const EdgeInsets.only(bottom: 22),
              color: i < current ? paxAccent : p.border,
            ),
        ],
      ],
    );
  }
}
