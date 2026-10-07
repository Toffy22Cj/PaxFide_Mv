import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/physical_asset_api.dart';
import '../domain/action_resolver.dart';
import '../domain/asset_action.dart';
import '../domain/asset_command.dart';
import '../domain/command_id.dart';
import '../domain/command_outcome.dart';
import '../domain/lifecycle_status.dart';
import 'command_form_sheet.dart';

String lifecycleLabel(String wire) => switch (LifecycleStatus.fromWire(wire)) {
  LifecycleStatus.registered => 'Registrado',
  LifecycleStatus.dispatched => 'Despachado',
  LifecycleStatus.received => 'Recibido',
  LifecycleStatus.delivered => 'Entregado',
  LifecycleStatus.depleted => 'Agotado (dividido)',
  null => wire,
};

/// Último comando enviado desde esta pantalla (en memoria; el Outbox persistente llega en el bloque 2.4).
class _SentCommand {
  _SentCommand(this.command, this.commandId, this.outcome);
  final AssetCommand command;
  final String commandId;
  CommandOutcome outcome;
  int? statusCode;
}

/// `/assets/:assetRef` (§13): `GET /physical-assets/{assetRef}` + `ActionResolver` + estado del comando.
/// Estados: carga; contenido; 403 (también inexistente u otra organización, DD-01); 404; error.
/// La acción solo se **muestra** a `EMPLOYEE` según `/me`; el backend autoriza cada petición (P7).
class AssetScreen extends StatefulWidget {
  const AssetScreen({super.key, required this.assetRef});
  final String assetRef;

  @override
  State<AssetScreen> createState() => _AssetScreenState();
}

class _AssetScreenState extends State<AssetScreen> {
  late final AppServices _services = AppScope.of(context);
  late final PhysicalAssetApi _api = PhysicalAssetApi(_services.apiClient);
  final _ids = CommandIdGenerator();

  PhysicalAssetDto? _asset;
  Object? _error;
  bool _loading = true;
  bool _sending = false;
  _SentCommand? _sent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asset == null && _error == null && _loading) _load();
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

  Future<void> _startAction(AssetAction action) async {
    final cmd = await showCommandForm(context, action, widget.assetRef);
    if (cmd == null || !mounted) return;
    await _send(_SentCommand(cmd, _ids.next(), CommandOutcome.notSent));
  }

  /// Envía con el `Command-Id` de [sent]. El reintento de un `AMBIGUOUS` usa el **mismo** id; uno nuevo solo para una
  /// "Nueva operación" tras `FAILED`.
  Future<void> _send(_SentCommand sent) async {
    setState(() {
      _sending = true;
      _sent = sent;
    });
    try {
      final r = await _api.postCommand(path: sent.command.path, body: sent.command.body, commandId: sent.commandId);
      sent
        ..outcome = classifyResponse(r)
        ..statusCode = r.statusCode;
    } on TransportException catch (e) {
      sent.outcome = classifyTransport(e);
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent.outcome == CommandOutcome.acknowledged) await _load();
  }

  /// "Verificar estado": el estado observado coincide con el esperado → confirmada. No prueba que este
  /// `Command-Id` lo causara (límite epistémico de D6).
  Future<void> _verify() async {
    final sent = _sent;
    if (sent == null) return;
    setState(() => _sending = true);
    try {
      final a = await _api.get(widget.assetRef);
      if (a.lifecycleStatus == sent.command.action.expectedStatusAfter?.wire) {
        sent.outcome = CommandOutcome.acknowledged;
      }
      if (mounted) setState(() => _asset = a);
    } on AppException {
      // Sigue AMBIGUOUS.
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(location: AppRoutes.assetPath(widget.assetRef), title: 'Activo', body: _body(context));
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
    final canShowAction = (principal?.showsOperatorActions ?? false) && action != AssetAction.readOnly;
    final sent = _sent;
    final blocking = sent != null && sent.outcome == CommandOutcome.ambiguous;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (sent != null)
            _OutcomeCard(
              sent: sent,
              sending: _sending,
              onVerify: _verify,
              onRetrySame: () => _send(sent),
              onNew: () {
                setState(() => _sent = null);
                _startAction(sent.command.action);
              },
            ),
          if (canShowAction && !blocking && !_sending)
            FilledButton.icon(
              key: const Key('asset.action'),
              onPressed: () => _startAction(action),
              icon: const Icon(Icons.play_arrow),
              label: Text(actionLabel(action)),
            ),
          if (_sending) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(title: const Text('Referencia'), subtitle: Text(a.assetRef)),
                ListTile(
                  key: const Key('asset.status'),
                  title: const Text('Estado'),
                  subtitle: Text(lifecycleLabel(a.lifecycleStatus)),
                ),
                ListTile(title: const Text('Cantidad'), subtitle: Text('${a.quantity} ${a.unitOfMeasure}')),
                ListTile(title: const Text('Custodio actual'), subtitle: Text(a.currentCustodianRef)),
                ListTile(title: const Text('Ubicación actual'), subtitle: Text(a.currentLocation)),
              ],
            ),
          ),
          if (action == AssetAction.readOnly)
            const Padding(padding: EdgeInsets.all(8), child: Text('Este activo no tiene más acciones.')),
        ],
      ),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({
    required this.sent,
    required this.sending,
    required this.onVerify,
    required this.onRetrySame,
    required this.onNew,
  });

  final _SentCommand sent;
  final bool sending;
  final VoidCallback onVerify;
  final VoidCallback onRetrySame;
  final VoidCallback onNew;

  String _failedReason() => switch (sent.statusCode) {
    403 => 'Tu cuenta no puede hacer esta operación con este activo.',
    409 => 'El estado del activo ya no lo permite.',
    401 => 'Tu sesión terminó antes de enviar.',
    _ => 'Revisa los datos e inténtalo como una operación nueva.',
  };

  @override
  Widget build(BuildContext context) {
    final label = actionLabel(sent.command.action);
    return switch (sent.outcome) {
      CommandOutcome.acknowledged => Card(
        child: ListTile(leading: const Icon(Icons.check_circle), title: Text('$label: confirmada')),
      ),
      CommandOutcome.failed => Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.block),
              title: Text('$label: el servidor la rechazó'),
              subtitle: Text(_failedReason()),
            ),
            OverflowBar(
              children: [TextButton(onPressed: sending ? null : onNew, child: const Text('Nueva operación'))],
            ),
          ],
        ),
      ),
      CommandOutcome.ambiguous => Card(
        key: const Key('asset.ambiguous'),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text('$label: no pudimos confirmar la operación'),
              subtitle: const Text('Puede que el servidor la haya registrado. Verifica el estado antes de reintentar.'),
            ),
            OverflowBar(
              children: [
                FilledButton(
                  key: const Key('asset.verify'),
                  onPressed: sending ? null : onVerify,
                  child: const Text('Verificar estado'),
                ),
                TextButton(
                  key: const Key('asset.retrySame'),
                  onPressed: sending ? null : onRetrySame,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
      ),
      CommandOutcome.notSent => Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_off),
              title: Text('$label: no se envió'),
              subtitle: const Text('Sin conexión con el servidor. No se registró nada.'),
            ),
            OverflowBar(
              children: [TextButton(onPressed: sending ? null : onRetrySame, child: const Text('Enviar de nuevo'))],
            ),
          ],
        ),
      ),
    };
  }
}
