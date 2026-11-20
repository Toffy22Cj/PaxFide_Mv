import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../biometrics/biometric_authenticator.dart';
import '../domain/session_state.dart';

/// «Pedir la huella o el rostro al abrir la app» (enmienda 8 de ADR-043, PROPUESTA).
///
/// Decide **una sola vez**, cuando la sesión se resuelve al arrancar: si se restauró una sesión (el usuario ya estaba
/// dentro), la preferencia está encendida y el teléfono puede pedir la biometría, la app queda tapada hasta que la
/// huella o el rostro sean correctos. Una sesión que se inicia después (contraseña, Google o biometría en el login) no
/// la pide: acaba de verificarse. Mientras se decide, la app también está tapada, para que Inicio no se vea un instante.
///
/// «Entrar con contraseña» cierra la sesión (sin tocar lo guardado sin conexión, H2) y deja el login. No hay forma de
/// saltarse el bloqueo sin la huella, el rostro o la contraseña. La huella nunca sale del teléfono y no se llama al
/// backend: la sesión ya está iniciada.
class BiometricLockGate extends StatefulWidget {
  const BiometricLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate> {
  late AppServices _services;
  bool _listening = false;

  /// Ya se miró la sesión al arrancar: no se vuelve a decidir.
  bool _decided = false;

  /// Se está leyendo la preferencia (tapa la app sin pedir nada todavía).
  bool _checking = false;
  bool _locked = false;
  bool _prompting = false;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listening) return;
    _listening = true;
    _services = AppScope.of(context);
    _services.session.addListener(_onSession);
    _onSession();
  }

  @override
  void dispose() {
    if (_listening) _services.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    final status = _services.session.state.status;
    if (_decided) {
      // Si la sesión se cierra (contraseña, expiración), no hay nada que desbloquear.
      if (_locked && status != SessionStatus.authenticated && mounted) setState(() => _locked = false);
      return;
    }
    if (status == SessionStatus.unknown || status == SessionStatus.restoring) return;
    _decided = true;
    if (status == SessionStatus.authenticated) {
      _checking = true;
      if (mounted) setState(() {});
      _decide();
    }
  }

  Future<void> _decide() async {
    var lock = false;
    try {
      lock = await _services.biometricLogin.shouldLockOnOpen();
    } catch (_) {
      lock = false;
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _locked = lock;
    });
    if (lock) await _unlock();
  }

  Future<void> _unlock() async {
    if (_prompting) return;
    _prompting = true;
    BiometricCheck result;
    try {
      result = await _services.biometricLogin.unlock();
    } catch (_) {
      result = BiometricCheck.failed;
    }
    _prompting = false;
    if (!mounted) return;
    setState(() {
      if (result == BiometricCheck.success) {
        _locked = false;
        _message = null;
      } else {
        _message = result == BiometricCheck.canceled
            ? 'Cancelaste la verificación.'
            : 'No pudimos verificar tu huella o tu rostro. Inténtalo de nuevo.';
      }
    });
  }

  Future<void> _usePassword() => _services.session.logout();

  @override
  Widget build(BuildContext context) {
    final covered = _locked || _checking;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Debajo, la app sigue montada (conserva su pantalla), pero ni se toca ni la lee un lector de pantalla.
        ExcludeSemantics(
          excluding: covered,
          child: IgnorePointer(ignoring: covered, child: widget.child),
        ),
        if (covered)
          Positioned.fill(
            child: _LockCover(
              checking: _checking,
              message: _message,
              onUnlock: _unlock,
              onPassword: _usePassword,
            ),
          ),
      ],
    );
  }
}

class _LockCover extends StatelessWidget {
  const _LockCover({required this.checking, required this.message, required this.onUnlock, required this.onPassword});

  final bool checking;
  final String? message;
  final VoidCallback onUnlock;
  final VoidCallback onPassword;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      key: const Key('biometric-lock'),
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: checking
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fingerprint, size: 64),
                      const SizedBox(height: 16),
                      Text('PaxFide está bloqueada', style: text.titleLarge, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                        'Usa tu huella o tu rostro para abrirla.',
                        style: text.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          message!,
                          key: const Key('biometric-lock-message'),
                          style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        key: const Key('biometric-lock-unlock'),
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Usar huella o rostro'),
                        onPressed: onUnlock,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('biometric-lock-password'),
                        onPressed: onPassword,
                        child: const Text('Entrar con contraseña'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
