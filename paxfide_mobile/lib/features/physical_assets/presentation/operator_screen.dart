import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/qr_scanner_sheet.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/quantity.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/physical_asset_api.dart';

/// `/operator`: activos de la organización (`GET /organizations/{id}/physical-assets`),
/// escáner de QR y apertura manual por referencia (DDM-16). Solo navega:
/// ninguna acción se ejecuta desde aquí. Un 403 es estado de pantalla.
class OperatorScreen extends StatefulWidget {
  const OperatorScreen({super.key});

  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  late final AppServices _services = AppScope.of(context);
  final _manual = TextEditingController();
  List<PhysicalAssetDto>? _assets;
  Object? _error;
  bool _started = false;
  String? _manualError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  @override
  void dispose() {
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

  void _openManual() {
    final ref = _manual.text.trim();
    if (!AppRoutes.isValidParam(ref)) {
      setState(() => _manualError = 'Referencia no válida');
      return;
    }
    setState(() => _manualError = null);
    Navigator.of(context).pushNamed(AppRoutes.assetPath(ref));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Operaciones',
      actions: [
        IconButton(
          key: const Key('operator-pending'),
          tooltip: 'Operaciones pendientes',
          icon: const Icon(Icons.pending_actions_outlined),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.operatorPending),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: const Key('operator-scan'),
            onPressed: () => scanQr(context),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Escanear QR de un activo'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('operator-manual'),
            controller: _manual,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'O escribe la referencia del activo',
              border: const OutlineInputBorder(),
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
          Text('Activos de tu organización', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _list(context),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    final e = _error;
    if (e is ForbiddenException) {
      return const MessageView(icon: Icons.lock_outline, title: 'Tu cuenta no puede ver los activos de la organización.');
    }
    if (e != null) return ErrorRetryView(message: describeError(e), onRetry: _load);
    final assets = _assets;
    if (assets == null) return const LoadingView();
    if (assets.isEmpty) return const Text('No hay activos registrados.');
    return Column(
      key: const Key('operator-assets'),
      children: [
        for (final a in assets)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              key: Key('operator-asset-${a.assetRef}'),
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(lifecycleLabel(a.lifecycleStatus)),
              subtitle: Text(
                '${formatQuantityWithUnit(a.quantity, a.unitOfMeasure == null ? null : unitLabel(a.unitOfMeasure!))}'
                ' · ${a.currentLocation ?? (a.lifecycleStatus == 'DISPATCHED' ? 'en tránsito' : 'sin ubicación')}\n${a.assetRef}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.assetPath(a.assetRef)),
            ),
          ),
      ],
    );
  }
}
