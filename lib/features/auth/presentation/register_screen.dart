import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/error_message.dart';
import '../../../shared/widgets/pax_ui.dart';
import 'auth_layout.dart';

/// `/register`: `POST /auth/register` (`{email, password}` → 201). No inicia sesión: el backend no devuelve token.
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
  bool _sending = false;
  bool _done = false;
  String? _error;

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
      setState(() => _error = 'Escribe un email y una contraseña.');
      return;
    }
    if (password.length < minPasswordLength) {
      setState(() => _error = 'La contraseña debe tener al menos $minPasswordLength caracteres.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await AppScope.of(context).authApi.register(email, password);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _done = true;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = switch (e) {
          ConflictException() => 'Ya existe una cuenta con ese email.',
          BadRequestException() => 'Revisa el email y que la contraseña tenga al menos $minPasswordLength caracteres.',
          _ => describeError(e),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    if (_done) {
      return AuthLayout(
        title: 'Crear una cuenta',
        back: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const IconCircle(Icons.check),
            const SizedBox(height: 16),
            Text('Cuenta creada', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Ya puedes entrar con tu email y tu contraseña.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: services.router.back, child: const Text('Ir a entrar')),
          ],
        ),
      );
    }
    return AuthLayout(
      title: 'Crear una cuenta',
      back: true,
      subtitle: 'Consulta tus donaciones desde una misma cuenta.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: 'Email',
            child: TextField(
              key: const Key('register.email'),
              controller: _email,
              enabled: !_sending,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Contraseña',
            child: PasswordField(
              key: const Key('register.password'),
              controller: _password,
              enabled: !_sending,
              helperText: 'Al menos $minPasswordLength caracteres',
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorMessage(_error!)],
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('register.submit'),
            onPressed: _sending ? null : _submit,
            child: Text(_sending ? 'Crear cuenta…' : 'Crear cuenta'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _sending ? null : services.router.back, child: const Text('Ya tengo cuenta')),
        ],
      ),
    );
  }
}
