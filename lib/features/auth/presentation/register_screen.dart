import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/theme/pax_tokens.dart';
import '../domain/legal_versions.dart';
import '../google/google_id_token_provider.dart';
import 'auth_layout.dart';

/// `/register`: `POST /auth/register` (`{email, password, acceptedTermsVersion, acceptedDataPolicyVersion}` → 201).
/// No inicia sesión: el backend no devuelve token.
/// Exige aceptar las versiones vigentes de los términos y de la política de tratamiento de datos ([currentTermsVersion]
/// y [currentDataPolicyVersion]).
/// La única regla de contraseña es la del backend: al menos 12 caracteres (`PasswordTooShort`); se comprueba antes de
/// enviar y el backend la vuelve a validar.
/// Mínimo de la contraseña según el backend (`PasswordTooShort`, referencia-api-v1 §1, develop 1b012da).
const minPasswordLength = 12;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _sending = false;
  bool _done = false;
  bool _acceptTerms = false;
  bool _acceptDataPolicy = false;
  String? _error;

  /// Registro con Google (ADR-050 Enmienda 3): la cuenta de Google elegida. Sustituye al correo escrito; el `idToken`
  /// solo vive aquí, en memoria.
  GoogleIdTokenObtained? _google;

  Future<void> _chooseGoogle() async {
    setState(() => _error = null);
    final result = await AppScope.of(context).google.obtain();
    if (!mounted) return;
    switch (result) {
      case GoogleIdTokenObtained():
        setState(() => _google = result);
      case GoogleIdTokenCanceled():
        break;
      case GoogleIdTokenFailed():
        setState(() => _error = 'No se pudo usar Google en este teléfono. Crea la cuenta con tu correo.');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    final google = _google;
    if ((google == null && email.isEmpty) || password.isEmpty) {
      setState(
        () => _error = google == null
            ? 'Escribe un correo electrónico y una contraseña.'
            : 'Escribe una contraseña para tu cuenta.',
      );
      return;
    }
    if (password.length < minPasswordLength) {
      setState(() => _error = 'La contraseña debe tener al menos $minPasswordLength caracteres.');
      return;
    }
    // Se escribe dos veces para no crear la cuenta con un error de tecleo que nadie vio.
    if (_repeat.text.isEmpty) {
      setState(() => _error = 'Repite la contraseña para confirmarla.');
      return;
    }
    if (_repeat.text != password) {
      setState(() => _error = 'Las dos contraseñas no coinciden.');
      return;
    }
    if (!_acceptTerms || !_acceptDataPolicy) {
      setState(
        () => _error = 'Para crear la cuenta debes aceptar los términos y autorizar el tratamiento de tus datos.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    if (google != null) return _submitWithGoogle(google, password);
    try {
      await AppScope.of(context).authApi.register(
        email,
        password,
        acceptedTermsVersion: currentTermsVersion,
        acceptedDataPolicyVersion: currentDataPolicyVersion,
      );
      if (!mounted) return;
      AppScope.of(context).session.markJustRegistered();
      setState(() {
        _sending = false;
        _done = true;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = switch (e) {
          ConflictException() => 'Ya existe una cuenta con ese correo electrónico.',
          BadRequestException() =>
            'Revisa el correo electrónico y que la contraseña tenga al menos $minPasswordLength caracteres.',
          _ => describeError(e),
        };
      });
    }
  }

  /// `POST /auth/google/register`: la cuenta nace verificada y vinculada, así que se entra directamente.
  Future<void> _submitWithGoogle(GoogleIdTokenObtained google, String password) async {
    final services = AppScope.of(context);
    try {
      final token = await services.authApi.googleRegister(
        google.idToken,
        password,
        acceptedTermsVersion: currentTermsVersion,
        acceptedDataPolicyVersion: currentDataPolicyVersion,
      );
      if (!mounted) return;
      if (token != null) {
        services.session.markJustRegistered(); // la bienvenida de primera vez, como el alta con correo
        await services.session.loginWithToken(token);
        return;
      }
      setState(() {
        _sending = false;
        _done = true;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (e is GoogleRegisterException && e.reason == 'GoogleIdTokenInvalid') _google = null;
        _error = switch (e) {
          GoogleRegisterException(reason: 'DuplicateEmail') =>
            'Ya existe una cuenta con ese correo. Entra con tu contraseña y vincula Google en Cuenta.',
          GoogleRegisterException(reason: 'GoogleAccountAlreadyLinked') =>
            'Esa cuenta de Google ya tiene una cuenta de PaxFide. Usa «Entrar con Google».',
          GoogleRegisterException(reason: 'GoogleIdTokenInvalid') => 'Google no confirmó la cuenta. Vuelve a elegirla.',
          GoogleRegisterException(reason: 'PasswordTooShort') =>
            'La contraseña debe tener al menos $minPasswordLength caracteres.',
          GoogleRegisterException() => 'Revisa los datos y vuelve a intentarlo.',
          GoogleSignInUnavailableException() =>
            'Google no responde ahora. Inténtalo en un momento o crea la cuenta con tu correo.',
          _ => describeError(e),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final ink = AuthInk(Theme.of(context).brightness == Brightness.dark);
    void toLogin() {
      final stack = services.router.stack;
      if (stack.length > 1 && stack[stack.length - 2] == AppRoutes.login) {
        services.router.back();
      } else {
        services.router.push(AppRoutes.login);
      }
    }

    if (_done) {
      return AuthLayout(
        title: 'Cuenta creada',
        subtitle: _google != null ? 'Tu cuenta ya está lista. Entra con Google o con tu correo y tu contraseña.' : 'Te enviamos un correo para confirmar tu dirección. Ábrelo y después entra con tu correo y tu contraseña.',
        back: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthNotice(
              _google != null
                  ? 'Tu cuenta de donante está creada y vinculada a Google.'
                  : 'Tu cuenta de donante está creada. Falta confirmar tu correo.',
              ink: ink,
              kind: AuthNoticeKind.success,
            ),
            const SizedBox(height: 16),
            AuthSubmitButton(ink: ink, label: 'Ir a entrar', icon: Icons.arrow_forward, onPressed: toLogin),
          ],
        ),
      );
    }
    final length = _password.text.length;
    return AuthLayout(
      title: 'Crear Cuenta',
      subtitle: 'Crea tu cuenta para donar y seguir cada paso de tus donaciones.',
      tab: AuthTab.register,
      back: true,
      footer: AuthSwitch(
        ink: ink,
        text: '¿Ya tienes una cuenta?',
        action: 'Inicia sesión aquí',
        actionKey: const Key('register.login'),
        onTap: _sending ? null : toLogin,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (services.google.isAvailable && _google == null) ...[
            AuthOutlineButton(
              key: const Key('register.google'),
              ink: ink,
              label: 'Registrarse con Google',
              leading: Text(
                'G',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink.title),
              ),
              onPressed: _sending ? null : _chooseGoogle,
            ),
            const SizedBox(height: 8),
            Text(
              'O crea la cuenta con tu correo electrónico',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: ink.body),
            ),
            const SizedBox(height: 12),
          ],
          if (_google case final g?)
            AuthField(
              ink: ink,
              label: 'Correo electrónico',
              child: Row(
                key: const Key('register.googleEmail'),
                children: [
                  Icon(Icons.verified_user_outlined, size: 20, color: ink.title),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g.email == null ? 'Te registras con tu cuenta de Google' : 'Te registras con ${g.email}',
                      style: TextStyle(color: ink.title, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    key: const Key('register.googleOther'),
                    style: TextButton.styleFrom(foregroundColor: ink.link),
                    onPressed: _sending ? null : () => setState(() => _google = null),
                    child: const Text('Usar otro correo'),
                  ),
                ],
              ),
            )
          else
            AuthField(
              ink: ink,
              label: 'Correo electrónico',
              child: TextField(
                key: const Key('register.email'),
                controller: _email,
                enabled: !_sending,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                style: TextStyle(color: ink.title, fontWeight: FontWeight.w500),
                decoration: authInput(ink, icon: Icons.mail_outline, hint: 'tu@correo.com'),
              ),
            ),
          const SizedBox(height: 14),
          AuthField(
            ink: ink,
            label: 'Contraseña segura',
            child: PasswordField(
              key: const Key('register.password'),
              ink: ink,
              controller: _password,
              enabled: !_sending,
              hint: 'Mínimo $minPasswordLength caracteres',
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Barra del landing (`.pass-strength-bar`) con la única regla real: el largo mínimo del backend.
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (length / minPasswordLength).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: ink.line,
              color: length >= minPasswordLength ? PaxTokens.brandGreen500 : PaxTokens.brandYellow400,
              semanticsLabel: 'Largo de la contraseña',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            length >= minPasswordLength
                ? 'Largo suficiente'
                : 'Al menos $minPasswordLength caracteres (llevas $length)',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: ink.muted),
          ),
          const SizedBox(height: 14),
          AuthField(
            ink: ink,
            label: 'Confirmar contraseña',
            child: PasswordField(
              key: const Key('register.passwordRepeat'),
              ink: ink,
              controller: _repeat,
              enabled: !_sending,
              hint: 'Escríbela otra vez',
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_repeat.text.isNotEmpty && _repeat.text != _password.text) ...[
            const SizedBox(height: 4),
            Text(
              'Las contraseñas no coinciden.',
              key: const Key('register.passwordRepeat.mismatch'),
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 10),
          MergeSemantics(
            child: InkWell(
              key: const Key('register.acceptTerms'),
              borderRadius: BorderRadius.circular(8),
              onTap: _sending ? null : () => setState(() => _acceptTerms = !_acceptTerms),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: _sending ? null : (v) => setState(() => _acceptTerms = v ?? false),
                      activeColor: ink.button,
                      checkColor: ink.onButton,
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: Text('Acepto los términos y condiciones', style: TextStyle(fontSize: 13, color: ink.body)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          MergeSemantics(
            child: InkWell(
              key: const Key('register.acceptDataPolicy'),
              borderRadius: BorderRadius.circular(8),
              onTap: _sending ? null : () => setState(() => _acceptDataPolicy = !_acceptDataPolicy),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Checkbox(
                      value: _acceptDataPolicy,
                      onChanged: _sending ? null : (v) => setState(() => _acceptDataPolicy = v ?? false),
                      activeColor: ink.button,
                      checkColor: ink.onButton,
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: Text(
                        'Autorizo el tratamiento de mis datos personales',
                        style: TextStyle(fontSize: 13, color: ink.body),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 14), AuthNotice(_error!, ink: ink)],
          const SizedBox(height: 18),
          AuthSubmitButton(
            key: const Key('register.submit'),
            ink: ink,
            label: _sending ? 'Crear cuenta…' : 'Crear cuenta',
            icon: Icons.check,
            busy: _sending,
            onPressed: _sending ? null : _submit,
          ),
        ],
      ),
    );
  }
}
