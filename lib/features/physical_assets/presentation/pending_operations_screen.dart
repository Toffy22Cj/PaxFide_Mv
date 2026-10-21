import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/outbox_item.dart';
import '../../../core/offline/outbox_status.dart';
import '../../../core/storage/outbox_store.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/session_controller.dart';
import '../data/physical_asset_api.dart';
import '../domain/asset_operations.dart';
import 'outbox_entry_card.dart';

/// `/operator/pending` (§9, precisión de ownership): ruta de UI cuya fuente es el `OutboxStore` local. No llama a
/// ningún endpoint de listado; la única lectura remota es `GET /physical-assets/{assetRef}` al "Verificar estado".
/// Solo muestra las entradas de la cuenta de la sesión (H2).
class PendingOperationsScreen extends StatefulWidget {
  const PendingOperationsScreen({super.key});

  @override
  State<PendingOperationsScreen> createState() => _PendingOperationsScreenState();
}

class _PendingOperationsScreenState extends State<PendingOperationsScreen> {
  late final AppServices _services = AppScope.of(context);
  late final AssetOperations _ops = AssetOperations(
    engine: _services.syncEngine,
    api: PhysicalAssetApi(_services.apiClient),
  );
  List<OutboxItem>? _entries;
  Object? _error;
  bool _busy = false;
  bool _started = false;

  String? get _accountId => _services.session.principal?.accountId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _services.syncEngine.addListener(_load);
      _services.session.addListener(_load);
      _load();
    }
  }

  @override
  void dispose() {
    _services.syncEngine.removeListener(_load);
    _services.session.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final account = _accountId;
    if (account == null) return;
    try {
      final e = await _services.syncEngine.entriesFor(account);
      if (mounted) {
        setState(() {
          _entries = e;
          _error = null;
        });
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
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

  @override
  Widget build(BuildContext context) {
    return AppShell(
      location: AppRoutes.operatorPending,
      title: 'Operaciones pendientes',
      body: ListenableBuilder(
        listenable: _services.session,
        builder: (context, _) {
          final account = _accountId;
          if (account == null) {
            return _services.session.profileStatus == ProfileStatus.unavailable
                ? ErrorRetryView(message: 'No pudimos cargar tu perfil.', onRetry: _services.session.reloadProfile)
                : const LoadingView();
          }
          if (_error is OutboxStoreUnreadableException) {
            return const MessageView(
              icon: Icons.report_problem_outlined,
              title: 'No se pueden leer las operaciones guardadas en este dispositivo.',
              detail: 'No se ha borrado nada. Avisa al equipo antes de reinstalar la app.',
            );
          }
          final entries = _entries;
          if (entries == null) return const LoadingView();
          if (entries.isEmpty) {
            return const MessageView(icon: Icons.inbox_outlined, title: 'No hay operaciones pendientes de tu cuenta.');
          }
          Future<bool> discard(OutboxItem e) async {
            if (!await confirmDiscard(context)) return false;
            await _run(() => _services.syncEngine.discard(e.commandId, account));
            // Se quita ya de la lista: una tarjeta deslizada no puede seguir en pantalla hasta la recarga.
            if (mounted) setState(() => _entries = [...?_entries]..removeWhere((x) => x.commandId == e.commandId));
            return true;
          }

          // M-03: deslizar hacia abajo actualiza; una rechazada se puede descartar deslizándola (con confirmación).
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final e in entries)
                  _swipeToDiscard(
                    e,
                    discard,
                    OutboxEntryCard(
                      item: e,
                      busy: _busy,
                      showAsset: true,
                      onOpenAsset: () => _services.router.push(AppRoutes.assetPath(e.resourceRef)),
                      onSend: () => _run(() => _services.syncEngine.send(e.commandId, account)),
                      onVerify: () => _run(() async {
                        final ok = await _ops.verify(e, accountId: account);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Todavía no podemos confirmarla: el estado no coincide.')),
                          );
                        }
                      }),
                      onDiscard: () => discard(e),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Solo las rechazadas por el servidor (FAILED) se pueden descartar; deslizarla pide la misma confirmación.
Widget _swipeToDiscard(OutboxItem e, Future<bool> Function(OutboxItem) discard, Widget child) {
  if (e.status != OutboxStatus.failed) return child;
  return Builder(
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return Dismissible(
        key: Key('outbox.swipe.${e.commandId}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => discard(e),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.delete_outline, color: scheme.onErrorContainer, semanticLabel: 'Descartar'),
        ),
        child: child,
      );
    },
  );
}
