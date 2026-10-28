import 'package:flutter/material.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../data/auth_api.dart';
import 'auth_layout.dart';

/// Hoja modal inferior para solicitar recuperación de contraseña (`Key('forgot.sheet')`).
Future<void> showForgotPasswordSheet(BuildContext context, {required String initialEmail, required AuthApi authApi}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ForgotPasswordSheet(initialEmail: initialEmail, authApi: authApi),
  );
}

class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({super.key, required this.initialEmail, required this.authApi});

  final String initialEmail;
  final AuthApi authApi;

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  late final TextEditingController _emailController = TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = 'Escribe tu correo electrónico.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await widget.authApi.requestPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _successMessage =
            'Si existe una cuenta con ese correo, te enviamos un enlace para crear una contraseña nueva. '
            'Revisa tu bandeja y sigue el enlace desde tu navegador.';
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = describeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AuthInk(Theme.of(context).brightness == Brightness.dark);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      key: const Key('forgot.sheet'),
      decoration: BoxDecoration(
        color: ink.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: ink.cardEdge),
          left: BorderSide(color: ink.cardEdge),
          right: BorderSide(color: ink.cardEdge),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: ink.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink.title),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: Icon(Icons.close, color: ink.muted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Escribe el correo electrónico asociado a tu cuenta. Te enviaremos las instrucciones para restablecer tu contraseña.',
              style: TextStyle(fontSize: 13.5, color: ink.body, height: 1.4),
            ),
            const SizedBox(height: 16),
            AuthField(
              ink: ink,
              label: 'Correo electrónico',
              child: TextField(
                key: const Key('forgot.email'),
                controller: _emailController,
                enabled: !_sending,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                style: TextStyle(color: ink.title, fontWeight: FontWeight.w500),
                decoration: authInput(ink, icon: Icons.mail_outline, hint: 'ejemplo@correo.com'),
                onSubmitted: (_) => _submit(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthNotice(_error!, ink: ink, kind: AuthNoticeKind.error, textKey: const Key('forgot.error')),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 12),
              AuthNotice(
                _successMessage!,
                ink: ink,
                kind: AuthNoticeKind.success,
                textKey: const Key('forgot.success'),
              ),
            ],
            const SizedBox(height: 16),
            AuthSubmitButton(
              key: const Key('forgot.submit'),
              ink: ink,
              label: 'Enviar enlace',
              icon: Icons.send_outlined,
              busy: _sending,
              onPressed: _sending ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
