import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/qr_scanner_sheet.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/quantity.dart';
import '../../../shared/theme/pax_theme.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/physical_asset_api.dart';
import '../domain/action_resolver.dart';
import '../domain/asset_action.dart';
import '../domain/lifecycle_status.dart';
import 'command_form_sheet.dart';

/// `/operator`: pantalla completa con [OperatorView].
class OperatorScreen extends StatelessWidget {
  const OperatorScreen({super.key});

  @override
  Widget build(BuildContext context) => const AppPage(title: 'Operaciones de campo', body: OperatorView());
}

/// Envíos de la organización (`GET /organizations/{id}/physical-assets`),
/// escáner y búsqueda por código (DDM-16). Solo navega: los pasos se
/// registran en la pantalla del envío. Un 403 es estado de pantalla.
class OperatorView extends StatefulWidget {
  const OperatorView({super.key});

  @override
  State<OperatorView> createState() => _OperatorViewState();
}

class _OperatorViewState extends State<OperatorView> {
  late final AppServices _services = AppScope.of(context);
  final _manual = TextEditingController();
  List<PhysicalAssetDto>? _assets;
  Object? _error;
  bool _started = false;
  String? _manualError;
  int _pending = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _services.syncEngine.addListener(_loadPending);
      _load();
      _loadPending();
    }
  }

  @override
  void dispose() {
    _services.syncEngine.removeListener(_loadPending);
    _manual.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final org = _services.session.value.principal?.organizationId;
    if (org == null) {
      setState(() => _assets = const []);
      return;
    }
    setState(() {
      _error = null;
      _assets = null;
    });
    try {
      final items = await _services.physicalAssetApi.organizationAssets(org);
      if (mounted) setState(() => _assets = items);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadPending() async {
    final account = _services.session.value.principal?.accountId;
    if (account == null) return;
    try {
      final entries = await _services.syncEngine.entriesFor(account);
      if (mounted) setState(() => _pending = entries.length);
    } on AppException {
      if (mounted) setState(() => _pending = 0);
    }
  }

  void _openManual() {
    final ref = _manual.text.trim();
    if (!AppRoutes.isValidParam(ref)) {
      setState(() => _manualError = 'Escribe un código válido');
      return;
    }
    setState(() => _manualError = null);
    Navigator.of(context).pushNamed(AppRoutes.assetPath(ref));
  }

  Future<void> _open(String assetRef) async {
    await Navigator.of(context).pushNamed(AppRoutes.assetPath(assetRef));
    if (mounted) _load(); // al volver, estados actualizados
  }

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pending > 0)
          Notice(
            key: const Key('operator-pending-notice'),
            kind: NoticeKind.warning,
            title: _pending == 1 ? 'Tienes 1 paso sin confirmar' : 'Tienes $_pending pasos sin confirmar',
            text: 'Quedaron guardados en este teléfono. Revísalos para enviarlos o comprobarlos.',
            action: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const Key('home-entry-operator-pending'),
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.operatorPending),
                child: const Text('Revisar'),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('operator-scan'),
                onPressed: () => scanQr(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear código QR'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('operator-manual'),
          controller: _manual,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'O escribe el código del envío',
            errorText: _manualError,
            suffixIcon: IconButton(
              key: const Key('operator-manual-open'),
              icon: const Icon(Icons.arrow_forward),
              onPressed: _openManual,
            ),
          ),
          onSubmitted: (_) => _openManual(),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text('Envíos de tu organización', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.text))),
            IconButton(tooltip: 'Actualizar', icon: Icon(Icons.refresh, color: p.textMuted, size: 20), onPressed: _load),
          ],
        ),
        const SizedBox(height: 4),
        _list(context),
      ],
    );
  }

  Widget _list(BuildContext context) {
    final e = _error;
    if (e is ForbiddenException) {
      return const MessageView(icon: Icons.lock_outline, title: 'Tu cuenta no puede ver los envíos de la organización.');
    }
    if (e != null) return ErrorRetryView(message: describeError(e), onRetry: _load);
    final assets = _assets;
    if (assets == null) return const LoadingView();
    if (assets.isEmpty) {
      return const MessageView(icon: Icons.inventory_2_outlined, title: 'Todavía no hay envíos registrados.');
    }
    // Primero los que tienen un paso pendiente.
    final sorted = [...assets]..sort((a, b) => _order(a).compareTo(_order(b)));
    return Column(
      key: const Key('operator-assets'),
      children: [for (final a in sorted) _AssetCard(asset: a, onTap: () => _open(a.assetRef))],
    );
  }

  static int _order(PhysicalAssetDto a) => switch (a.lifecycleStatus) {
        'DISPATCHED' => 0,
        'RECEIVED' => 1,
        'REGISTERED' => 2,
        _ => 3,
      };
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset, required this.onTap});
  final PhysicalAssetDto asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    AssetAction next = AssetAction.readOnly;
    try {
      next = const ActionResolver().resolve(LifecycleStatus.fromApi(asset.lifecycleStatus));
    } on UnknownLifecycleStatusException {
      next = AssetAction.readOnly;
    }
    final color = next == AssetAction.readOnly ? p.textMuted : paxAccent;
    final unit = asset.unitOfMeasure == null ? null : unitLabel(asset.unitOfMeasure!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('operator-asset-${asset.assetRef}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: p.border)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.inventory_2_outlined, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatQuantityWithUnit(asset.quantity, unit),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.text)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          lifecycleLabel(asset.lifecycleStatus),
                          ?asset.currentLocation,
                        ].join(' · '),
                        style: TextStyle(fontSize: 12.5, color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                if (next != AssetAction.readOnly)
                  StatusChip(actionLabel(next))
                else
                  Icon(Icons.chevron_right, color: p.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
