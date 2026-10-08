import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/outbox_item.dart';
import '../../../core/storage/outbox_store.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/session_state.dart';
import 'outbox_entry_card.dart';

/// `/operator/pending`: ruta de UI cuya fuente es el `OutboxStore` local. No
/// llama a ningún endpoint de listado; la única lectura remota es
/// `GET /physical-assets/{assetRef}` al "Verificar estado". Solo muestra las
/// entradas de la cuenta de la sesión (ADR-043 §0, A1).
class PendingOperationsScreen extends StatefulWidget {
  const PendingOperationsScreen({super.key});

  @override
  State<PendingOperationsScreen> createState() => _PendingOperationsScreenState();
}

class _PendingOperationsScreenState extends State<PendingOperationsScreen> {
  late final AppServices _services = AppScope.of(context);
  List<OutboxItem>? _entries;
  Object? _error;
  bool _busy = false;
  bool _started = false;

  String? get _accountId => _services.session.value.principal?.accountId;

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
    return AppPage(
      title: 'Pasos sin confirmar',
      body: ValueListenableBuilder<SessionState>(
        valueListenable: _services.session,
        builder: (context, session, _) {
          final account = session.principal?.accountId;
          if (account == null) {
            return ErrorRetryView(
              message: 'No pudimos cargar tu perfil.',
              onRetry: () => _services.session.reloadPrincipal(),
            );
          }
          if (_error is OutboxStoreUnreadableException) {
            return const MessageView(
              icon: Icons.report_problem_outlined,
              title: 'No pudimos leer los pasos guardados en este teléfono.',
              detail: 'No se borró nada. Avisa a tu organización antes de reinstalar la app.',
            );
          }
          final entries = _entries;
          if (entries == null) return const LoadingView();
          if (entries.isEmpty) {
            return const MessageView(
              key: Key('pending-empty'),
              icon: Icons.inbox_outlined,
              title: 'No tienes pasos pendientes.',
              detail: 'Todo lo que registraste ya está confirmado.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_busy) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator()),
              for (final e in entries)
                OutboxEntryCard(
                  item: e,
                  busy: _busy,
                  showAsset: true,
                  onOpenAsset: () => Navigator.of(context).pushNamed(AppRoutes.assetPath(e.resourceRef)),
                  onSend: () => _run(() => _services.syncEngine.send(e.commandId, account)),
                  onRetrySame: () => _run(() => _services.syncEngine.send(e.commandId, account)),
                  onVerify: () => _run(() async {
                    final ok = await _services.assetOperations.verify(e, accountId: account);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Todavía no aparece registrado. Puedes enviarlo otra vez.')),
                      );
                    }
                  }),
                  onDiscard: () async {
                    if (await confirmDiscard(context)) {
                      await _run(() => _services.syncEngine.discard(e.commandId, account));
                    }
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
