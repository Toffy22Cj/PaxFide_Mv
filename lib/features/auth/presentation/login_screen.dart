import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import 'auth_layout.dart';

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
      await services.session.login(email, password);
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
    return AuthLayout(
      title: 'Entrar',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('login.email'),
              controller: _email,
              enabled: !_sending,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('login.password'),
              controller: _password,
              enabled: !_sending,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('login.error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('login.submit'),
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Entrar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _sending ? null : () => services.router.push(AppRoutes.register),
              child: const Text('Crear una cuenta'),
            ),
            TextButton(
              onPressed: _sending ? null : () => services.router.push(AppRoutes.tracking),
              child: const Text('Seguir una donación con su código'),
            ),
          ],
        ),
      ),
    );
  }
}
