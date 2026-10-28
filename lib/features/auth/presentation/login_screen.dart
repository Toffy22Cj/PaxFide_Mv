import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/qr_scanner_sheet.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/pax_app_bar.dart';
import '../biometrics/biometric_login.dart';
import 'auth_layout.dart';
import 'biometric_login_dialog.dart';
import 'forgot_password_sheet.dart';
import 'legal_acceptance_dialog.dart';

/// `/login` (§13). Sin selector de rol: el rol sale de `GET /me` tras entrar (encargo §3).
/// Si la cuenta tiene términos o políticas de datos pendientes (403 `AcceptanceRequired`),
/// abre un diálogo de aceptación legal y reintenta con las versiones pendientes aceptadas.
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

  /// "Recordarme en este teléfono": sin marcar, la sesión no se guarda y al cerrar la app hay que volver a entrar.
  bool _remember = true;

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
      setState(() => _error = 'Escribe tu correo electrónico y tu contraseña.');
      return;
    }
    final services = AppScope.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // Con el JWT en la mano y antes de salir del login: ofrecer la biometría si el teléfono la tiene (M-28).
      String token;
      try {
        token = await services.authApi.login(email, password);
      } on AcceptanceRequiredException catch (pending) {
        if (!mounted) return;
        final accepted = await showLegalAcceptanceDialog(context, pending);
        if (!accepted) {
          services.pendingIntents.discard();
          if (mounted) {
            setState(() {
              _sending = false;
              _error = 'Para entrar debes aceptar las condiciones vigentes.';
            });
          }
          return;
        }
        try {
          token = await services.authApi.login(
            email,
            password,
            acceptedTermsVersion: pending.pendingTermsVersion,
            acceptedDataPolicyVersion: pending.pendingDataPolicyVersion,
          );
        } on AcceptanceRequiredException {
          services.pendingIntents.discard();
          if (mounted) {
            setState(() {
              _sending = false;
              _error = 'Las condiciones cambiaron mientras entrabas. Inténtalo de nuevo.';
            });
          }
          return;
        }
      }
      final enroll = await _askToEnableBiometric();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final biometric = _biometric;
      await services.session.loginWithToken(token, remember: _remember);
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

  Future<void> _openForgotPassword() async {
    final services = AppScope.of(context);
    await showForgotPasswordSheet(context, initialEmail: _email.text.trim(), authApi: services.authApi);
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final ink = AuthInk(Theme.of(context).brightness == Brightness.dark);
    final fieldStyle = TextStyle(color: ink.title, fontWeight: FontWeight.w500);
    return AuthLayout(
      title: 'Iniciar Sesión',
      subtitle: 'Gestiona tus donaciones, sigue su recorrido y apoya convocatorias.',
      tab: AuthTab.login,
      // Enmienda 3: con la bienvenida (u otra pantalla) debajo, flecha para volver.
      back: services.router.stack.length > 1,
      footer: AuthSwitch(
        ink: ink,
        text: '¿No tienes una cuenta aún?',
        action: 'Regístrate gratis',
        actionKey: const Key('login.register'),
        onTap: _sending ? null : () => services.router.push(AppRoutes.register),
      ),
      below: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: PaxGlass(
          radius: 999,
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  key: const Key('login.tracking'),
                  style: TextButton.styleFrom(foregroundColor: ink.title, minimumSize: const Size(0, 44)),
                  onPressed: _sending ? null : () => services.router.push(AppRoutes.tracking),
                  icon: const Icon(Icons.route_outlined, size: 18),
                  label: const Text('Seguir una donación', overflow: TextOverflow.ellipsis),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  key: const Key('login.scan'),
                  style: TextButton.styleFrom(foregroundColor: ink.title, minimumSize: const Size(0, 44)),
                  onPressed: _sending ? null : () => scanQr(context),
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Escanear QR', overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              ink: ink,
              label: 'Correo electrónico',
              child: TextField(
                key: const Key('login.email'),
                controller: _email,
                enabled: !_sending,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                style: fieldStyle,
                decoration: authInput(ink, icon: Icons.mail_outline, hint: 'ejemplo@correo.com'),
              ),
            ),
            const SizedBox(height: 14),
            AuthField(
              ink: ink,
              label: 'Contraseña',
              trailing: TextButton(
                key: const Key('login.forgot'),
                style: TextButton.styleFrom(
                  foregroundColor: ink.link,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: _sending ? null : _openForgotPassword,
                child: const Text(
                  '¿Olvidaste tu contraseña?',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              child: PasswordField(
                key: const Key('login.password'),
                ink: ink,
                controller: _password,
                enabled: !_sending,
                hint: 'Tu contraseña',
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 6),
            MergeSemantics(
              child: InkWell(
                key: const Key('login.remember'),
                borderRadius: BorderRadius.circular(8),
                onTap: _sending ? null : () => setState(() => _remember = !_remember),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _remember,
                        onChanged: _sending ? null : (v) => setState(() => _remember = v ?? true),
                        activeColor: ink.button,
                        checkColor: ink.onButton,
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Text('Recordarme en este teléfono', style: TextStyle(fontSize: 13, color: ink.body)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              AuthNotice(_error!, ink: ink, textKey: const Key('login.error')),
            ],
            const SizedBox(height: 12),
            AuthSubmitButton(
              key: const Key('login.submit'),
              ink: ink,
              label: 'Iniciar Sesión',
              icon: Icons.arrow_forward,
              busy: _sending,
              onPressed: _sending ? null : _submit,
            ),
            if (_biometricOffered) ...[
              const SizedBox(height: 10),
              AuthOutlineButton(
                key: const Key('login-biometric'),
                ink: ink,
                label: 'Entrar con huella o rostro',
                leading: const Icon(Icons.fingerprint, size: 20),
                onPressed: _sending ? null : _biometricLogin,
              ),
              TextButton(
                key: const Key('login-biometric-forget'),
                style: TextButton.styleFrom(foregroundColor: ink.link),
                onPressed: _sending ? null : _forgetBiometric,
                child: const Text('No usar la biometría en este teléfono'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
