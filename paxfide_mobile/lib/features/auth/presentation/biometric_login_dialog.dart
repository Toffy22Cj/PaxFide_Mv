import 'package:flutter/material.dart';

import '../biometrics/biometric_login.dart';

/// Recuadro "Entrar por biometría" del login (ADR-043 §8.8). Al abrirse pide la huella o el rostro sin que el usuario
/// toque nada. La X, tocar fuera o cancelar el aviso del teléfono lo cierran y queda el login con contraseña.
///
/// Devuelve el resultado, o null si el usuario lo cerró antes de terminar.
Future<BiometricLoginResult?> showBiometricLoginDialog(BuildContext context, BiometricLogin biometricLogin) {
  return showDialog<BiometricLoginResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _BiometricLoginDialog(biometricLogin: biometricLogin),
  );
}

class _BiometricLoginDialog extends StatefulWidget {
  const _BiometricLoginDialog({required this.biometricLogin});
  final BiometricLogin biometricLogin;

  @override
  State<_BiometricLoginDialog> createState() => _BiometricLoginDialogState();
}

class _BiometricLoginDialogState extends State<_BiometricLoginDialog> {
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final result = await widget.biometricLogin.login();
    // Si el usuario ya lo cerró con la X o tocando fuera, el resultado no se usa.
    if (!mounted || _closed) return;
    _closed = true;
    Navigator.of(context).pop(result is BiometricLoginDismissed ? null : result);
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('biometric-login-dialog'),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(color: Color(0xFFE7F5EF), shape: BoxShape.circle),
                    child: const Icon(Icons.fingerprint, size: 44, color: Color(0xFF1E4A38)),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Entrar por biometría',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pon tu huella o mira a la cámara cuando tu teléfono te lo pida.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Si prefieres tu contraseña, cierra este recuadro.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.4),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                key: const Key('biometric-login-close'),
                tooltip: 'Usar mi contraseña',
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                onPressed: _close,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
