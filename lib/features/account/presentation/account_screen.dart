import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../app/text_size_button.dart';
import '../../../app/theme_mode_button.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/outbox_status.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/theme/text_size_controller.dart';
import '../../../shared/widgets/error_message.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/principal.dart';
import '../../auth/domain/session_controller.dart';
import '../data/invitation_api.dart';

String roleLabel(String role) => switch (role) {
  Principal.employee => 'Empleado',
  Principal.administrator => 'Administrador',
  Principal.representative => 'Representante',
  _ => role,
};

/// `/account` (E-12, M-26): tu rol y organización, aceptar una invitación, apariencia y cerrar sesión con
/// confirmación (avisa si hay operaciones guardadas en el teléfono). Cambiar la contraseña (M-27) espera su ADR.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return AppShell(
      location: AppRoutes.account,
      title: 'Cuenta',
      body: ListenableBuilder(
        listenable: services.session,
        builder: (context, _) {
          final p = services.session.principal;
          if (p == null) {
            return services.session.profileStatus == ProfileStatus.unavailable
                ? ErrorRetryView(message: 'No pudimos cargar tu perfil.', onRetry: services.session.reloadProfile)
                : const LoadingView();
          }
          final text = Theme.of(context).textTheme;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                key: const Key('account.profile'),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('Rol'),
                      subtitle: Text(p.roles.isEmpty ? 'Donante' : p.roles.map(roleLabel).join(', ')),
                    ),
                    ListTile(
                      leading: const Icon(Icons.apartment_outlined),
                      title: const Text('Organización'),
                      subtitle: Text(
                        p.organizationId == null
                            ? 'No perteneces a ninguna organización'
                            : 'Perteneces a una organización',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (p.organizationId == null) ...[const _InvitationCard(), const SizedBox(height: 12)],
              Text('Apariencia', style: text.titleMedium),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.format_size),
                      title: const Text('Tamaño del texto'),
                      subtitle: ValueListenableBuilder<TextSize>(
                        valueListenable: services.textSize,
                        builder: (context, s, _) => Text(s.label),
                      ),
                      trailing: const TextSizeButton(),
                    ),
                    ListTile(
                      leading: const Icon(Icons.contrast),
                      title: const Text('Tema'),
                      subtitle: ValueListenableBuilder<ThemeMode>(
                        valueListenable: services.theme,
                        builder: (context, m, _) => Text(ThemeModeButton.labels[m]!),
                      ),
                      trailing: const ThemeModeButton(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const Key('account.logout'),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                onPressed: () => _confirmLogout(context, services, p.accountId),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Cerrar sesión pide confirmación; si hay operaciones de esta cuenta sin confirmar, lo avisa. No borra nada de la
/// cola (siguen en el teléfono para cuando vuelva a entrar).
Future<void> _confirmLogout(BuildContext context, AppServices services, String accountId) async {
  var pending = 0;
  try {
    pending = (await services.syncEngine.entriesFor(accountId))
        .where((i) => i.status != OutboxStatus.acknowledged)
        .length;
  } on Object {
    pending = 0;
  }
  if (!context.mounted) return;
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const Key('account.logout.confirm'),
      title: const Text('¿Cerrar sesión?'),
      content: Text(
        pending == 0
            ? 'Para volver a entrar necesitarás tu contraseña o tu biometría.'
            : 'Tienes $pending ${pending == 1 ? 'operación guardada' : 'operaciones guardadas'} en este teléfono sin '
                  'confirmar. No se borran: las verás en Pendientes cuando vuelvas a entrar con esta cuenta.',
        key: const Key('account.logout.message'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('account.logout.yes'),
          onPressed: () => Navigator.of(c).pop(true),
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
  if (yes == true) await services.session.logout();
}

/// Aceptar una invitación a una organización con el código del correo (ADR-049). El código no se guarda.
class _InvitationCard extends StatefulWidget {
  const _InvitationCard();

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final token = _token.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Pega el código de la invitación.');
      return;
    }
    final services = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await InvitationApi(services.apiClient).accept(token);
      _token.clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Listo. Ya eres parte de la organización.')));
      }
      await services.session.reloadProfile();
    } on ForbiddenException {
      if (mounted) setState(() => _error = 'Esa invitación no es válida, ya caducó o es para otro correo.');
    } on ConflictException {
      if (mounted) setState(() => _error = 'Tu cuenta ya pertenece a una organización.');
    } on AppException catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('account.invitation'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Te invitaron a una organización?', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            LabeledField(
              label: 'Código de la invitación',
              child: TextField(
                key: const Key('account.invitation.token'),
                controller: _token,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(helperText: 'Viene en el correo de invitación.'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorMessage(_error!, textKey: const Key('account.invitation.error')),
            ],
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('account.invitation.accept'),
              onPressed: _busy ? null : _accept,
              child: const Text('Aceptar invitación'),
            ),
          ],
        ),
      ),
    );
  }
}
