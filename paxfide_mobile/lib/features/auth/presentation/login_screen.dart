import 'package:flutter/material.dart';
import '../domain/session_state.dart';
import '../../home/presentation/home_screen.dart';

enum LoginUiState {
  initial,
  loading,
  invalidCredentials,
  networkError,
  sessionExpired,
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedAccountType = UserRole.donor;
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

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    SessionManager.instance.setSession(
      SessionState.authenticated(
        role: _selectedAccountType,
        email: _emailController.text.trim(),
      ),
    );

    setState(() => _state = LoginUiState.initial);

    // Transición cinemática de entrada a HomeScreen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
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
            'Infraestructura fiduciaria integral para garantizar que cada recurso asignado llegue a su destino con auditoría verificable.',
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
                    'Cadena de custodia y trazabilidad en tiempo real',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0)),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Text('© 2026 PaxFide. Plataforma fiduciaria de impacto.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildLoginForm({required bool isDesktop}) {
    final isOrg = _selectedAccountType == UserRole.organization;

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
          Text(
            isOrg ? 'Panel ejecutivo para organizaciones fiduciarias.' : 'Acceso para personas y aportantes solidarios.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          _buildAccountTypeSelector(),
          const SizedBox(height: 20),
          _buildFieldLabel(isOrg ? 'Correo institucional / ONG' : 'Correo electrónico'),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'El correo es obligatorio';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Introduce un correo válido';
              return null;
            },
            decoration: _inputDecoration(hintText: isOrg ? 'contacto@organizacion.org' : 'nombre@correo.com', prefixIcon: Icons.alternate_email_rounded),
          ),
          const SizedBox(height: 18),
          _buildFieldLabel('Contraseña'),
          TextFormField(
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
                  : Text(isOrg ? 'Entrar como Organización' : 'Entrar como Donante', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: _buildAccountOption(label: 'Soy Donante', role: UserRole.donor)),
          Expanded(child: _buildAccountOption(label: 'Organización', role: UserRole.organization)),
        ],
      ),
    );
  }

  Widget _buildAccountOption({required String label, required UserRole role}) {
    final isSelected = _selectedAccountType == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedAccountType = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B))),
        ),
      ),
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