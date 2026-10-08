import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/auth_api.dart';

/// Pantalla de `/register` (ADR-043 §0, A4): `POST /auth/register`.
///
/// No inicia sesión: al crear la cuenta lleva al login. No elige rol: una
/// cuenta nueva es donante hasta que una organización la invite.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _sending = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await AppScope.of(context).authApi.register(_email.text.trim(), _password.text);
      if (mounted) setState(() => _done = true);
    } on RegisterRejectedException catch (e) {
      setState(() => _error = e.reason == RegisterRejection.duplicateEmail
          ? 'Ya existe una cuenta con ese correo.'
          : 'Revisa el correo y que la contraseña tenga al menos ${AuthApi.minPasswordLength} caracteres.');
    } on AppException catch (e) {
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return AppPage(
        title: 'Crear cuenta',
        body: MessageView(
          key: const Key('register-done'),
          icon: Icons.check_circle_outline,
          title: 'Cuenta creada',
          detail: 'Ya puedes entrar con tu correo y contraseña.',
          action: FilledButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.login),
            child: const Text('Ir a iniciar sesión'),
          ),
        ),
      );
    }
    return AppPage(
      title: 'Crear cuenta',
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Crea una cuenta de donante para ver el historial de tus donaciones.'),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(_error!, key: const Key('register-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            TextFormField(
              key: const Key('register-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo electrónico', border: OutlineInputBorder()),
              validator: (v) => (v == null || !v.contains('@')) ? 'Introduce un correo válido' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register-password'),
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                helperText: 'Al menos ${AuthApi.minPasswordLength} caracteres',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.length < AuthApi.minPasswordLength)
                  ? 'Debe tener al menos ${AuthApi.minPasswordLength} caracteres'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register-confirm'),
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Repite la contraseña', border: OutlineInputBorder()),
              validator: (v) => v != _password.text ? 'Las contraseñas no coinciden' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('register-submit'),
              onPressed: _sending ? null : _submit,
              child: Text(_sending ? 'Creando…' : 'Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
