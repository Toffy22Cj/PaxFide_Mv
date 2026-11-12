import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../app/pending_count.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/session_controller.dart';
import '../data/physical_asset_api.dart';
import '../domain/asset_labels.dart';
import 'asset_screen.dart';

/// `/operator` → **Mi día** (E-01): cuántos activos de la organización hay por despachar, en tránsito y entregados
/// (`GET /organizations/{id}/physical-assets`, máx. 200); tocar una tarjeta muestra la lista filtrada. Escanear y
/// Pendientes son pestañas: aquí solo se escribe el código y se abren Mis convocatorias. Sin `EMPLOYEE` en `/me`: "sin acceso operativo" (nunca un redirect).
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
                subtitle: Text('Puedes escanear y guardar operaciones; se envían solas al volver la señal.'),
              ),
            ),
          // Escanear tiene su pestaña abajo; Pendientes vive aquí, en Mi día.
          OutlinedButton.icon(
            key: const Key('operator.type'),
            onPressed: _typeRef,
            icon: const Icon(Icons.keyboard_outlined),
            label: const Text('Escribir el código del activo'),
          ),
          const SizedBox(height: 10),
          const _PendingTile(),
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
                  leading: Icon(lifecycleIcon(a.lifecycleStatus)),
                  title: Text(assetTitle(a)),
                  subtitle: Text(
                    [lifecycleLabel(a.lifecycleStatus), ?a.zoneName, 'Cód. ${shortRef(a.assetRef)}'].join(' · '),
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

/// «Operaciones pendientes» con su número (las de esta cuenta guardadas en el teléfono, sin las confirmadas). Abre
/// la lista, que vuelve a Mi día con la flecha.
class _PendingTile extends StatelessWidget {
  const _PendingTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: PendingCountBuilder(
        builder: (context, n) => ListTile(
          key: const Key('operator.pending'),
          leading: const Icon(Icons.pending_actions),
          title: const Text('Operaciones pendientes'),
          subtitle: Text(
            n == 0
                ? 'Nada por enviar en este teléfono'
                : (n == 1 ? '1 operación guardada en este teléfono' : '$n operaciones guardadas en este teléfono'),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (n > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(99)),
                  child: Text('$n', style: TextStyle(color: scheme.onPrimaryContainer)),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => AppScope.of(context).router.push(AppRoutes.operatorPending),
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
    title: const Text('Código del activo'),
    content: TextField(
      key: const Key('operator.assetRef'),
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Código del activo'),
      onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text.trim()), child: const Text('Abrir')),
    ],
  );
}
