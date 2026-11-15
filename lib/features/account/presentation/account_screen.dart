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
import '../../../shared/widgets/state_views.dart';
import '../../auth/google/google_id_token_provider.dart';
import '../../auth/domain/principal.dart';
import '../../auth/domain/session_controller.dart';
import '../../auth/presentation/register_screen.dart' show minPasswordLength;
import '../data/organization_name.dart';
import '../data/account_api.dart';

String roleLabel(String role) => switch (role) {
  Principal.employee => 'Empleado',
  Principal.administrator => 'Administrador',
  Principal.representative => 'Representante',
  _ => role,
};

/// `/account` (E-12, M-26): correo y nombre (`GET`/`PUT /account/profile`), rol, organización (solo si la cuenta
/// tiene una), apariencia, cambiar la contraseña (M-27, `POST /account/password`), desactivar la cuenta (M-30,
/// `POST /account/deactivate`) y cerrar sesión con confirmación (avisa si hay operaciones guardadas en el teléfono).
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
              const _ProfileCard(),
              const SizedBox(height: 12),
              Card(
                key: const Key('account.profile'),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('Rol'),
                      subtitle: Text(p.roles.isEmpty ? 'Donante' : p.roles.map(roleLabel).join(', ')),
                    ),
                    // El donante nunca pertenece a una organización (ADR-026): la fila solo es para quien la tiene.
                    if (p.organizationId != null) _OrganizationTile(principal: p),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Apariencia y ciudad', style: text.titleMedium),
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
                    // La ciudad de Inicio (web: «Animación de la ciudad»). Se recuerda en este teléfono.
                    ValueListenableBuilder<bool>(
                      valueListenable: services.cityPause,
                      builder: (context, paused, _) => SwitchListTile(
                        key: const Key('account.cityAnimation'),
                        secondary: const Icon(Icons.location_city_outlined),
                        title: const Text('Animación de la ciudad'),
                        subtitle: Text(paused ? 'En pausa' : 'En movimiento'),
                        value: !paused,
                        onChanged: (_) => services.cityPause.toggle(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Seguridad', style: text.titleMedium),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      key: const Key('account.password'),
                      leading: const Icon(Icons.password),
                      title: const Text('Cambiar contraseña'),
                      subtitle: const Text('Las demás sesiones de tu cuenta se cerrarán'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _changePassword(context, services),
                    ),
                    if (services.google.isAvailable)
                      ListTile(
                        key: const Key('account.google'),
                        leading: const Icon(Icons.link),
                        title: const Text('Cuenta de Google'),
                        subtitle: const Text('Vincúlala para entrar también con Google'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _googleOptions(context, services),
                      ),
                    ListTile(
                      key: const Key('account.deactivate'),
                      leading: Icon(Icons.person_off_outlined, color: Theme.of(context).colorScheme.error),
                      title: Text('Desactivar mi cuenta', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      subtitle: const Text('No se borra nada, pero ya no podrás entrar'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _deactivate(context, services, p.accountId),
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

/// Correo y nombre de la cuenta (`GET /account/profile`). El nombre es privado: solo lo ve la propia cuenta.
class _ProfileCard extends StatefulWidget {
  const _ProfileCard();

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  late final AccountApi _api = AccountApi(AppScope.of(context).apiClient);
  late Future<AccountProfile> _profile = _api.profile();

  Future<void> _editName(AccountProfile current) async {
    final updated = await showDialog<AccountProfile>(
      context: context,
      builder: (_) => _NameDialog(api: _api, current: current),
    );
    if (updated != null && mounted) {
      setState(() {
        _profile = Future.value(updated);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('account.identity'),
      child: FutureBuilder<AccountProfile>(
        future: _profile,
        builder: (context, snap) {
          final p = snap.data;
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
          }
          if (p == null) {
            return ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('No pudimos cargar tu correo'),
              trailing: TextButton(
                key: const Key('account.identity.retry'),
                onPressed: () => setState(() {
                  _profile = _api.profile();
                }),
                child: const Text('Reintentar'),
              ),
            );
          }
          return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Correo'),
                subtitle: Text(p.email, key: const Key('account.email')),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Nombre'),
                subtitle: Text(p.fullName ?? 'Sin nombre', key: const Key('account.name')),
                trailing: TextButton(
                  key: const Key('account.name.edit'),
                  onPressed: () => _editName(p),
                  child: const Text('Editar'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Editar nombre y apellido. Vacío borra el campo; cada parte, como mucho [AccountApi.maxNameLength] caracteres.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.api, required this.current});
  final AccountApi api;
  final AccountProfile current;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _given = TextEditingController(text: widget.current.givenName ?? '');
  late final _family = TextEditingController(text: widget.current.familyName ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _given.dispose();
    _family.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tooLong = [_given.text.trim(), _family.text.trim()].any((v) => v.runes.length > AccountApi.maxNameLength);
    if (tooLong) {
      setState(() => _error = 'Cada parte del nombre puede tener como mucho ${AccountApi.maxNameLength} caracteres.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await widget.api.updateProfile(givenName: _given.text, familyName: _family.text);
      if (mounted) Navigator.of(context).pop(p);
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is BadRequestException ? 'Revisa el nombre y el apellido.' : describeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('account.name.dialog'),
    title: const Text('Tu nombre'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Solo lo ves tú. No aparece en tus donaciones ni en la organización.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('account.name.given'),
            controller: _given,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('account.name.family'),
            controller: _family,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Apellido'),
          ),
          if (_error != null) ...[const SizedBox(height: 8), ErrorMessage(_error!)],
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      FilledButton(key: const Key('account.name.save'), onPressed: _busy ? null : _save, child: const Text('Guardar')),
    ],
  );
}

/// Campo de contraseña con "mostrar/ocultar".
class _SecretField extends StatefulWidget {
  const _SecretField({required this.fieldKey, required this.controller, required this.label, this.enabled = true});
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => TextField(
    key: widget.fieldKey,
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: !_visible,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: IconButton(
        tooltip: _visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
        icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: () => setState(() => _visible = !_visible),
      ),
    ),
  );
}

/// M-27: cambiar la contraseña. La sesión actual sigue con el token nuevo; las demás quedan cerradas (ADR-050 D4).
Future<void> _changePassword(BuildContext context, AppServices services) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<_PasswordResult>(context: context, builder: (_) => _PasswordDialog(services));
  switch (result) {
    case _PasswordResult.changed:
      messenger.showSnackBar(
        const SnackBar(
          key: Key('account.password.done'),
          content: Text('Contraseña cambiada. Se cerraron las demás sesiones de tu cuenta.'),
        ),
      );
    case _PasswordResult.signInAgain:
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos confirmar el cambio. Vuelve a entrar con tu contraseña nueva o, si no funciona, '
            'con la anterior.',
          ),
        ),
      );
      await services.session.logout();
    case null:
      break;
  }
}

enum _PasswordResult { changed, signInAgain }

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog(this.services);
  final AppServices services;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    String? local;
    if (_current.text.isEmpty || _new.text.isEmpty) {
      local = 'Escribe tu contraseña actual y la nueva.';
    } else if (_new.text.length < minPasswordLength) {
      local = 'La contraseña nueva debe tener al menos $minPasswordLength caracteres.';
    } else if (_new.text != _repeat.text) {
      local = 'Las dos contraseñas nuevas no coinciden.';
    }
    if (local != null) {
      setState(() => _error = local);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await AccountApi(widget.services.apiClient)
          .changePassword(currentPassword: _current.text, newPassword: _new.text);
      await widget.services.session.replaceToken(token);
      if (mounted) Navigator.of(context).pop(_PasswordResult.changed);
    } on CurrentPasswordIncorrectException {
      _fail('La contraseña actual no es correcta.');
    } on NewPasswordTooShortException {
      _fail('La contraseña nueva debe tener al menos $minPasswordLength caracteres.');
    } on ServerErrorException {
      // ADR-038 #7: el cambio pudo confirmarse y las sesiones revocarse aunque el token no llegara.
      if (mounted) Navigator.of(context).pop(_PasswordResult.signInAgain);
    } on AppException catch (e) {
      _fail(describeError(e));
    }
  }

  void _fail(String message) {
    if (mounted) {
      setState(() {
        _busy = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('account.password.dialog'),
    title: const Text('Cambiar contraseña'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SecretField(
            fieldKey: const Key('account.password.current'),
            controller: _current,
            label: 'Contraseña actual',
            enabled: !_busy,
          ),
          const SizedBox(height: 8),
          _SecretField(
            fieldKey: const Key('account.password.new'),
            controller: _new,
            label: 'Contraseña nueva (al menos $minPasswordLength caracteres)',
            enabled: !_busy,
          ),
          const SizedBox(height: 8),
          _SecretField(
            fieldKey: const Key('account.password.repeat'),
            controller: _repeat,
            label: 'Repite la contraseña nueva',
            enabled: !_busy,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ErrorMessage(_error!, textKey: const Key('account.password.error')),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      FilledButton(
        key: const Key('account.password.save'),
        onPressed: _busy ? null : _submit,
        child: const Text('Cambiar'),
      ),
    ],
  );
}

/// M-30: desactivar la propia cuenta (ADR-050 D6). Pide la contraseña; al confirmarse se cierra la sesión y se
/// olvida la biometría de este teléfono. No se puede deshacer desde la app.
/// Una sola entrada para Google: el backend no dice si ya hay una vinculada, así que se elige qué hacer.
Future<void> _googleOptions(BuildContext context, AppServices services) async {
  final link = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('account.google.link'),
            leading: const Icon(Icons.link),
            title: const Text('Vincular mi cuenta de Google'),
            subtitle: const Text('Para entrar también con Google'),
            onTap: () => Navigator.of(sheet).pop(true),
          ),
          ListTile(
            key: const Key('account.google.unlink'),
            leading: const Icon(Icons.link_off),
            title: const Text('Desvincular Google'),
            subtitle: const Text('Si la vinculaste antes. Seguirás entrando con tu correo y tu contraseña'),
            onTap: () => Navigator.of(sheet).pop(false),
          ),
        ],
      ),
    ),
  );
  if (link == null || !context.mounted) return;
  await _google(context, services, link: link);
}

/// Vincular o desvincular Google (ADR-050 D9), siempre con la contraseña actual. El backend no dice si ya hay una
/// vinculada; repetir cualquiera de las dos no cambia nada.
Future<void> _google(BuildContext context, AppServices services, {required bool link}) async {
  final messenger = ScaffoldMessenger.of(context);
  final done = await showDialog<bool>(
    context: context,
    builder: (_) => _GoogleDialog(services: services, link: link),
  );
  if (done != true) return;
  messenger.showSnackBar(
    SnackBar(
      key: const Key('account.google.done'),
      content: Text(
        link
            ? 'Listo. Ya puedes entrar con Google. Te enviamos un correo de aviso.'
            : 'Google quedó desvinculado. Entra con tu correo y tu contraseña.',
      ),
    ),
  );
}

class _GoogleDialog extends StatefulWidget {
  const _GoogleDialog({required this.services, required this.link});
  final AppServices services;
  final bool link;

  @override
  State<_GoogleDialog> createState() => _GoogleDialogState();
}

class _GoogleDialogState extends State<_GoogleDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Escribe tu contraseña para confirmar.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = AccountApi(widget.services.apiClient);
    try {
      if (widget.link) {
        final result = await widget.services.google.obtain();
        if (!mounted) return;
        switch (result) {
          case GoogleIdTokenObtained(:final idToken):
            await api.linkGoogle(idToken: idToken, currentPassword: _password.text);
          case GoogleIdTokenCanceled():
            setState(() => _busy = false);
            return;
          case GoogleIdTokenFailed():
            setState(() {
              _busy = false;
              _error = 'No se pudo usar Google en este teléfono.';
            });
            return;
        }
      } else {
        await api.unlinkGoogle(currentPassword: _password.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e) {
          CurrentPasswordIncorrectException() => 'La contraseña no es correcta.',
          GoogleIdTokenInvalidException() => 'Google no confirmó la cuenta. Inténtalo de nuevo.',
          GoogleLinkConflictException(reason: 'GoogleAccountAlreadyLinked') =>
            'Esa cuenta de Google ya está vinculada a otra cuenta de PaxFide.',
          GoogleLinkConflictException(reason: 'AccountAlreadyLinkedToGoogle') =>
            'Tu cuenta ya tiene otra cuenta de Google vinculada. Desvincúlala primero.',
          GoogleLinkConflictException() => 'No se puede vincular esa cuenta de Google.',
          GoogleSignInUnavailableException() => 'Google no responde ahora. Inténtalo en un momento.',
          _ => describeError(e),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('account.google.dialog'),
    title: Text(widget.link ? 'Vincular tu cuenta de Google' : '¿Desvincular Google?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.link
                ? 'Confirma tu contraseña y elige tu cuenta de Google. Después podrás entrar con ella.'
                : 'Ya no podrás entrar con Google. Tu cuenta y tus donaciones no cambian.',
          ),
          const SizedBox(height: 12),
          _SecretField(
            fieldKey: const Key('account.google.password'),
            controller: _password,
            label: 'Contraseña actual',
            enabled: !_busy,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ErrorMessage(_error!, textKey: const Key('account.google.error')),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
      FilledButton(
        key: const Key('account.google.confirm'),
        onPressed: _busy ? null : _submit,
        child: Text(widget.link ? 'Elegir cuenta de Google' : 'Desvincular'),
      ),
    ],
  );
}

Future<void> _deactivate(BuildContext context, AppServices services, String accountId) async {
  var pending = 0;
  try {
    pending = (await services.syncEngine.entriesFor(accountId))
        .where((i) => i.status != OutboxStatus.acknowledged)
        .length;
  } on Object {
    pending = 0;
  }
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final done = await showDialog<bool>(
    context: context,
    builder: (_) => _DeactivateDialog(services: services, pending: pending),
  );
  if (done != true) return;
  await services.biometricLogin.forget();
  await services.session.logout();
  messenger.showSnackBar(
    const SnackBar(key: Key('account.deactivate.done'), content: Text('Tu cuenta quedó desactivada.')),
  );
}

class _DeactivateDialog extends StatefulWidget {
  const _DeactivateDialog({required this.services, required this.pending});
  final AppServices services;
  final int pending;

  @override
  State<_DeactivateDialog> createState() => _DeactivateDialogState();
}

class _DeactivateDialogState extends State<_DeactivateDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  static String _blocked(String reason) => switch (reason) {
    'RepresentativeTransferRequired' =>
      'Eres representante de tu organización. Antes de desactivar tu cuenta, transfiere ese rol desde la web.',
    'ActiveCampaignResponsible' =>
      'Eres responsable de una convocatoria abierta. Pide que te retiren de ella antes de desactivar tu cuenta.',
    'PlatformAdministratorDeactivation' => 'Una cuenta de administración de la plataforma no se puede desactivar.',
    _ => 'Tu cuenta no se puede desactivar en este momento.',
  };

  Future<void> _submit() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Escribe tu contraseña para confirmar.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AccountApi(widget.services.apiClient).deactivate(currentPassword: _password.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e) {
          CurrentPasswordIncorrectException() => 'La contraseña no es correcta.',
          DeactivationBlockedException(:final reason) => _blocked(reason),
          _ => describeError(e),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('account.deactivate.dialog'),
    title: const Text('¿Desactivar tu cuenta?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'No se borra nada: tus donaciones y su recorrido siguen registrados. Pero ya no podrás entrar con esta '
            'cuenta, y no se puede deshacer desde la app.',
          ),
          if (widget.pending > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Tienes ${widget.pending} ${widget.pending == 1 ? 'operación guardada' : 'operaciones guardadas'} en '
              'este teléfono sin confirmar: no podrás enviarlas.',
              key: const Key('account.deactivate.pending'),
            ),
          ],
          const SizedBox(height: 12),
          _SecretField(
            fieldKey: const Key('account.deactivate.password'),
            controller: _password,
            label: 'Contraseña actual',
            enabled: !_busy,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ErrorMessage(_error!, textKey: const Key('account.deactivate.error')),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
      FilledButton(
        key: const Key('account.deactivate.confirm'),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        onPressed: _busy ? null : _submit,
        child: const Text('Desactivar'),
      ),
    ],
  );
}

/// «Organización» con su nombre (C4b). Mientras se lee, «Cargando…»; si no se puede saber, un texto neutro.
class _OrganizationTile extends StatefulWidget {
  const _OrganizationTile({required this.principal});
  final Principal principal;

  @override
  State<_OrganizationTile> createState() => _OrganizationTileState();
}

class _OrganizationTileState extends State<_OrganizationTile> {
  late final Future<String?> _name = loadOrganizationName(
    AppScope.of(context).apiClient,
    organizationId: widget.principal.organizationId,
    roles: widget.principal.roles,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _name,
    builder: (context, snap) => ListTile(
      key: const Key('account.organization'),
      leading: const Icon(Icons.apartment_outlined),
      title: const Text('Organización'),
      subtitle: Text(
        snap.connectionState != ConnectionState.done ? 'Cargando…' : (snap.data ?? 'Perteneces a una organización'),
        key: const Key('account.organization.name'),
      ),
    ),
  );
}
