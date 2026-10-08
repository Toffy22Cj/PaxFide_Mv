import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/pending_intent.dart';
import '../../../app/qr_scanner_sheet.dart';
import '../data/login_gateway.dart';
import '../data/session_controller.dart';

/// Estados de presentación del login. Cada fallo tiene su propio mensaje
/// (regla 2.6).
enum LoginUiState {
  initial,
  loading,
  invalidCredentials,
  networkError,
  unavailable,
}

/// Pantalla de `/login` (ADR-043 D8).
///
/// No elige rol (sale de `GET /me`) ni navega: cambia la sesión y el guard
/// decide el destino (invariante 6 del router).
class LoginScreen extends StatefulWidget {
  final LoginGateway loginGateway;
  final SessionController session;

  /// La intención de un deep link desaparece si el login falla (D9 R2, DDM-12).
  final PendingIntentHolder? pendingIntents;

  const LoginScreen({
    super.key,
    required this.loginGateway,
    required this.session,
    this.pendingIntents,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  LoginUiState _state = LoginUiState.initial;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_state == LoginUiState.loading) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _state = LoginUiState.loading);

    final LoginResult result;
    try {
      result = await widget.loginGateway.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (_) {
      widget.pendingIntents?.clear();
      if (mounted) setState(() => _state = LoginUiState.networkError);
      return;
    }

    if (!mounted) return;
    if (result is! LoginSucceeded) widget.pendingIntents?.clear();

    switch (result) {
      case LoginSucceeded(:final token):
        final established = await widget.session.establish(token);
        if (!mounted) return;
        // Con éxito el guard sustituye esta pantalla por /home.
        if (established != EstablishResult.authenticated) widget.pendingIntents?.clear();
        setState(() => _state = established == EstablishResult.authenticated
            ? LoginUiState.initial
            : LoginUiState.invalidCredentials);
      case LoginRejected():
        setState(() => _state = LoginUiState.invalidCredentials);
      case LoginNetworkError():
        setState(() => _state = LoginUiState.networkError);
      case LoginUnavailable():
        setState(() => _state = LoginUiState.unavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return Row(
              children: [
                Expanded(flex: 5, child: _buildBrandingPanel()),
                Expanded(
                  flex: 6,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 32.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _buildLoginForm(isDesktop: true),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildLoginForm(isDesktop: false),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrandingPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 56.0, vertical: 48.0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071A14), Color(0xFF0F2D24), Color(0xFF0A1F18)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              text: 'PaxFide',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'serif', letterSpacing: -1.2, color: Colors.white),
              children: [TextSpan(text: '.', style: TextStyle(color: Color(0xFF10B981)))],
            ),
          ),
          const Spacer(),
          const Text(
            'Donaciones que llegan.',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2, letterSpacing: -0.8),
          ),
          const SizedBox(height: 14),
          const Text(
            'Transparentes  |  Trazables  |  Con impacto real',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF38BDF8), letterSpacing: 0.8),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sigue cada donación desde el aporte hasta la entrega, con un registro que se puede verificar.',
            style: TextStyle(fontSize: 15, color: Color(0xFF94A3B8), height: 1.5),
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x6622C55E), blurRadius: 8, spreadRadius: 2)],
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cadena de custodia de cada activo entregado',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0)),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Text('© 2026 PaxFide.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildLoginForm({required bool isDesktop}) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDesktop) ...[
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                text: 'PaxFide',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'serif', letterSpacing: -1.2, color: Color(0xFF0F172A)),
                children: [TextSpan(text: '.', style: TextStyle(color: Color(0xFF10B981)))],
              ),
            ),
            const SizedBox(height: 24),
          ],
          const Text('Iniciar sesión', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: -0.6)),
          const SizedBox(height: 6),
          const Text(
            'Entra con tu cuenta de donante u operador.',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          if (_state != LoginUiState.initial && _state != LoginUiState.loading) ...[
            _buildStateMessage(),
            const SizedBox(height: 16),
          ],
          _buildFieldLabel('Correo electrónico'),
          TextFormField(
            key: const Key('login-email'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'El correo es obligatorio';
              if (!value.contains('@')) return 'Introduce un correo válido';
              return null;
            },
            decoration: _inputDecoration(hintText: 'nombre@correo.com', prefixIcon: Icons.alternate_email_rounded),
          ),
          const SizedBox(height: 18),
          _buildFieldLabel('Contraseña'),
          TextFormField(
            key: const Key('login-password'),
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            validator: (value) {
              if (value == null || value.isEmpty) return 'La contraseña es requerida';
              return null;
            },
            decoration: _inputDecoration(
              hintText: '••••••••••••',
              prefixIcon: Icons.lock_outline_rounded,
              suffixWidget: IconButton(
                splashRadius: 16,
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19, color: const Color(0xFF64748B)),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              key: const Key('login-submit'),
              onPressed: _state == LoginUiState.loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E4A38),
                disabledBackgroundColor: const Color(0xFF1E4A38).withValues(alpha: 0.6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _state == LoginUiState.loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Text('Entrar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton(
                key: const Key('login-register'),
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.register),
                child: const Text('Crear cuenta'),
              ),
              TextButton(
                key: const Key('login-tracking'),
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.tracking),
                child: const Text('Consultar seguimiento'),
              ),
              TextButton.icon(
                key: const Key('login-scan'),
                onPressed: () => scanQr(context),
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Escanear QR'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateMessage() {
    final (key, message) = switch (_state) {
      LoginUiState.invalidCredentials => (
          'login-error-credentials',
          'Correo o contraseña incorrectos, o la cuenta no está activa.',
        ),
      LoginUiState.networkError => (
          'login-error-network',
          'No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
        ),
      LoginUiState.unavailable => (
          'login-unavailable',
          'El inicio de sesión no está disponible: la app no tiene configurado el servidor.',
        ),
      LoginUiState.initial || LoginUiState.loading => ('', ''),
    };
    return Container(
      key: Key(key),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B), height: 1.35)),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
    );
  }

  InputDecoration _inputDecoration({required String hintText, required IconData prefixIcon, Widget? suffixWidget}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(prefixIcon, size: 19, color: const Color(0xFF64748B)),
      suffixIcon: suffixWidget,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E4A38), width: 1.5)),
    );
  }
}