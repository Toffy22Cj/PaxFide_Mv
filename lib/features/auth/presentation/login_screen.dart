import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/qr_scanner_sheet.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/error_message.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../biometrics/biometric_login.dart';
import 'auth_layout.dart';
import 'biometric_login_dialog.dart';

/// `/login` (§13). Sin selector de rol: el rol sale de `GET /me` tras entrar (encargo §3).
/// Estados: formulario; enviando; credenciales inválidas; error de red. Reintentar es seguro (no duplica nada).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _sending = false;
  String? _error;

  /// La biometría está activada en este teléfono: se ofrece al abrir y con el botón (M-28).
  bool _biometricOffered = false;
  late final BiometricLogin _biometric = AppScope.of(context).biometricLogin;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerBiometric());
    }
  }

  /// Al abrir el login, si la biometría está activada, aparece el recuadro solo.
  Future<void> _offerBiometric() async {
    if (!mounted || !await _biometric.canOffer() || !mounted) return;
    setState(() => _biometricOffered = true);
    await _biometricLogin();
  }

  Future<void> _biometricLogin() async {
    if (_sending) return;
    final services = AppScope.of(context);
    final result = await showBiometricLoginDialog(context, _biometric);
    if (!mounted || result == null) return;
    switch (result) {
      case BiometricLoginSucceeded(:final token):
        setState(() {
          _sending = true;
          _error = null;
        });
        try {
          await services.session.loginWithToken(token);
        } on AppException catch (e) {
          services.pendingIntents.discard();
          if (mounted) {
            setState(() {
              _sending = false;
              _error = describeError(e);
            });
          }
        }
      case BiometricLoginRevoked():
        setState(() {
          _biometricOffered = false;
          _error = 'La biometría ya no sirve en este teléfono. Entra con tu contraseña y vuelve a activarla.';
        });
      case BiometricLoginNetworkError():
        setState(() => _error = 'Sin conexión con el servidor. Inténtalo de nuevo cuando tengas señal.');
      case BiometricLoginDismissed():
        break;
    }
  }

  /// "¿Entrar con tu huella o tu rostro la próxima vez?" tras un login con contraseña. Devuelve true si el usuario
  /// dijo que sí y lo confirmó con su huella o su rostro.
  Future<bool> _askToEnableBiometric() async {
    if (!await _biometric.canOfferEnrollment() || !mounted) return false;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('biometric-offer'),
        icon: const Icon(Icons.fingerprint, size: 40),
        title: const Text('¿Entrar con tu huella o tu rostro la próxima vez?'),
        content: const Text('No tendrás que escribir la contraseña. Tu contraseña no se guarda en el teléfono.'),
        actions: [
          TextButton(
            key: const Key('biometric-offer-no'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            key: const Key('biometric-offer-yes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    if (yes != true) return false;
    return _biometric.confirmEnrollment();
  }

  /// Con la sesión ya iniciada: registra el teléfono y avisa del resultado.
  static Future<void> _registerBiometric(BiometricLogin biometric, ScaffoldMessengerState messenger) async {
    final result = await biometric.register();
    final text = switch (result) {
      BiometricEnableResult.enabled => 'Listo. La próxima vez podrás entrar con tu huella o tu rostro.',
      BiometricEnableResult.tooManyDevices =>
        'No se activó la biometría: ya está activada en 10 teléfonos con esta cuenta.',
      BiometricEnableResult.networkError => 'No se pudo activar la biometría. Inténtalo la próxima vez que entres.',
    };
    messenger.showSnackBar(SnackBar(key: const Key('biometric-registered'), content: Text(text)));
  }

  /// Dejar de usar la biometría en este teléfono, desde el login.
  Future<void> _forgetBiometric() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Dejar de usar la biometría en este teléfono?'),
        content: const Text('Para entrar usarás tu contraseña. Podrás volver a activarla después de entrar.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(
            key: const Key('biometric-forget-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Dejar de usarla'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _biometric.forget();
    if (mounted) setState(() => _biometricOffered = false);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Escribe tu email y tu contraseña.');
      return;
    }
    final services = AppScope.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // Con el JWT en la mano y antes de salir del login: ofrecer la biometría si el teléfono la tiene (M-28).
      final token = await services.authApi.login(email, password);
      final enroll = await _askToEnableBiometric();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final biometric = _biometric;
      await services.session.loginWithToken(token);
      if (enroll) _registerBiometric(biometric, messenger);
    } on AppException catch (e) {
      services.pendingIntents.discard(); // R2: el login fracasó → la intención desaparece
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e is UnauthorizedException ? 'Email o contraseña incorrectos.' : describeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AuthLayout(
      title: 'Entrar',
      brand: true,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: 'Email',
              child: TextField(
                key: const Key('login.email'),
                controller: _email,
                enabled: !_sending,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Contraseña',
              child: PasswordField(
                key: const Key('login.password'),
                controller: _password,
                enabled: !_sending,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorMessage(_error!, textKey: const Key('login.error')),
            ],
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('login.submit'),
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Entrar'),
            ),
            if (_biometricOffered) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('login-biometric'),
                onPressed: _sending ? null : _biometricLogin,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Entrar con huella o rostro'),
              ),
              TextButton(
                key: const Key('login-biometric-forget'),
                onPressed: _sending ? null : _forgetBiometric,
                child: const Text('No usar la biometría en este teléfono'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '¿No tienes cuenta?',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
            TextButton(
              onPressed: _sending ? null : () => services.router.push(AppRoutes.register),
              child: const Text('Crear una cuenta'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('o', style: TextStyle(color: muted)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('login.tracking'),
                    onPressed: _sending ? null : () => services.router.push(AppRoutes.tracking),
                    child: const Text('Seguir una donación', textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('login.scan'),
                    onPressed: _sending ? null : () => scanQr(context),
                    child: const Text('Escanear QR', textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
