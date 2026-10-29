import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../app/qr_scanner_sheet.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/quantity.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/session_controller.dart';
import '../data/physical_asset_api.dart';
import 'asset_screen.dart';
import '../../../app/pending_count.dart';

/// `/operator` → **Mi día** (E-01): cuántos activos de la organización hay por despachar, en tránsito y entregados
/// (`GET /organizations/{id}/physical-assets`, máx. 200); tocar una tarjeta muestra la lista filtrada. Atajos a
/// Escanear, escribir la referencia y Pendientes. Sin `EMPLOYEE` en `/me`: "sin acceso operativo" (nunca un redirect).
class OperatorScreen extends StatelessWidget {
  const OperatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return AppShell(
      location: AppRoutes.operator,
      title: 'Mi día',
      body: ListenableBuilder(
        listenable: services.session,
        builder: (context, _) {
          final p = services.session.principal;
          if (p == null) {
            return services.session.profileStatus == ProfileStatus.unavailable
                ? ErrorRetryView(message: 'No pudimos cargar tu perfil.', onRetry: services.session.reloadProfile)
                : const LoadingView();
          }
          if (!p.showsOperatorActions) {
            return const MessageView(icon: Icons.lock_outline, title: 'Tu cuenta no tiene acceso operativo.');
          }
          return _MyDay(organizationId: p.organizationId);
        },
      ),
    );
  }
}

/// Grupos de Mi día según el estado del activo.
enum _Group {
  toDispatch('Por despachar', Icons.inventory_2_outlined, {'REGISTERED'}),
  inTransit('En tránsito', Icons.local_shipping_outlined, {'DISPATCHED', 'RECEIVED'}),
  delivered('Entregados', Icons.task_alt, {'DELIVERED'});

  const _Group(this.label, this.icon, this.statuses);
  final String label;
  final IconData icon;
  final Set<String> statuses;
}

class _MyDay extends StatefulWidget {
  const _MyDay({required this.organizationId});
  final String? organizationId;

  @override
  State<_MyDay> createState() => _MyDayState();
}

class _MyDayState extends State<_MyDay> {
  late final AppServices _services = AppScope.of(context);
  List<PhysicalAssetDto>? _assets;
  Object? _error;
  bool _loading = false;
  _Group? _filter;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final org = widget.organizationId;
    if (org == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await PhysicalAssetApi(_services.apiClient).listForOrganization(org);
      if (mounted) setState(() => _assets = list);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _typeRef() async {
    final ref = await showDialog<String>(context: context, builder: (_) => const _AssetRefDialog());
    if (ref == null || ref.isEmpty || !mounted) return;
    if (!AppRoutes.isValidParam(ref)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esa referencia no es válida.')));
      return;
    }
    _services.router.push(AppRoutes.assetPath(ref));
  }

  @override
  Widget build(BuildContext context) {
    final assets = _assets;
    final error = _error;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error is TransportException)
            const Card(
              key: Key('myday.offline'),
              child: ListTile(
                leading: Icon(Icons.cloud_off),
                title: Text('Sin conexión'),
                subtitle: Text('Puedes escanear y guardar operaciones; se envían desde Pendientes.'),
              ),
            ),
          HighlightCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.qr_code_scanner, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text('Escanear el QR de un activo', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('operator.scan'),
                    onPressed: () => scanQr(context),
                    child: const Text('Escanear activo'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('operator.type'),
            onPressed: _typeRef,
            child: const Text('Escribir el código del activo'),
          ),
          const SizedBox(height: 10),
          _PendingCard(onOpen: () => _services.router.push(AppRoutes.operatorPending)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('operator.campaigns'),
            onPressed: () => _services.router.push(AppRoutes.myCampaigns),
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Mis convocatorias'),
          ),
          const SizedBox(height: 16),
          if (_loading && assets == null) const LoadingView(),
          if (error != null && error is! TransportException && assets == null)
            ErrorRetryView(message: describeError(error), onRetry: _load),
          if (assets != null && assets.isEmpty)
            const MessageView(icon: Icons.inventory_2_outlined, title: 'Tu organización todavía no tiene activos.'),
          if (assets != null && assets.isNotEmpty) ...[
            for (final g in _Group.values)
              Card(
                key: Key('myday.${g.name}'),
                color: _filter == g ? Theme.of(context).colorScheme.secondaryContainer : null,
                child: ListTile(
                  leading: Icon(g.icon),
                  title: Text(g.label),
                  trailing: Text(
                    '${assets.where((a) => g.statuses.contains(a.lifecycleStatus)).length}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  onTap: () => setState(() => _filter = _filter == g ? null : g),
                ),
              ),
            if (_filter != null) ...[
              const SizedBox(height: 8),
              Text(_filter!.label, style: Theme.of(context).textTheme.titleMedium),
              for (final a in assets.where((a) => _filter!.statuses.contains(a.lifecycleStatus)))
                ListTile(
                  key: Key('myday.asset.${a.assetRef}'),
                  title: Text(a.assetRef),
                  subtitle: Text(
                    [
                      ?a.assetType,
                      lifecycleLabel(a.lifecycleStatus),
                      formatQuantityWithUnit(a.quantity, a.unitOfMeasure),
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _services.router.push(AppRoutes.assetPath(a.assetRef)),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// "Operaciones pendientes" con su número (las de esta cuenta guardadas en el teléfono, sin las confirmadas).
class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: PendingCountBuilder(
        builder: (context, pending) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Operaciones pendientes', style: Theme.of(context).textTheme.titleSmall)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(99)),
                  child: Text('$pending', style: TextStyle(color: scheme.onPrimaryContainer)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Guardadas en este dispositivo por tu cuenta', style: TextStyle(color: scheme.onSurfaceVariant)),
            TextButton(key: const Key('operator.pending'), onPressed: onOpen, child: const Text('Ver pendientes')),
          ],
        ),
      ),
    );
  }
}

/// Diálogo con su propio controlador (se libera cuando el diálogo termina de cerrarse).
class _AssetRefDialog extends StatefulWidget {
  const _AssetRefDialog();

  @override
  State<_AssetRefDialog> createState() => _AssetRefDialogState();
}

class _AssetRefDialogState extends State<_AssetRefDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Referencia del activo'),
    content: TextField(
      key: const Key('operator.assetRef'),
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'assetRef'),
      onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text.trim()), child: const Text('Abrir')),
    ],
  );
}
