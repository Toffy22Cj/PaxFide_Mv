import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../app/qr_scanner_sheet.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/session_controller.dart';

/// `/operator` (§13): entrada al escáner (transitorio) y a `/operator/pending`. Sin datos propios.
/// Sin `EMPLOYEE` en `/me` se muestra el estado "sin acceso operativo" (nunca un redirect).
class OperatorScreen extends StatelessWidget {
  const OperatorScreen({super.key});

  Future<void> _typeRef(BuildContext context) async {
    final services = AppScope.of(context);
    final ref = await showDialog<String>(context: context, builder: (_) => const _AssetRefDialog());
    if (ref == null || ref.isEmpty) return;
    if (!AppRoutes.isValidParam(ref)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referencia no válida.')));
      }
      return;
    }
    services.router.push(AppRoutes.assetPath(ref));
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return AppShell(
      location: AppRoutes.operator,
      title: 'Operaciones',
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  key: const Key('operator.scan'),
                  leading: const Icon(Icons.qr_code_scanner),
                  title: const Text('Escanear el QR de un activo'),
                  onTap: () => scanQr(context),
                ),
              ),
              Card(
                child: ListTile(
                  key: const Key('operator.type'),
                  leading: const Icon(Icons.keyboard),
                  title: const Text('Escribir la referencia del activo'),
                  onTap: () => _typeRef(context),
                ),
              ),
              Card(
                child: ListTile(
                  key: const Key('operator.pending'),
                  leading: const Icon(Icons.pending_actions),
                  title: const Text('Operaciones pendientes'),
                  subtitle: const Text('Las guardadas en este dispositivo por tu cuenta'),
                  onTap: () => services.router.push(AppRoutes.operatorPending),
                ),
              ),
            ],
          );
        },
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
