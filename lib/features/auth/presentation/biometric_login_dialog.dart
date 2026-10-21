import 'package:flutter/material.dart';

import '../../../shared/widgets/pax_logo.dart';
import '../biometrics/biometric_login.dart';

/// Recuadro "Entrar por biometría" del login (M-28). Al abrirse pide la huella o el rostro sin que el usuario toque
/// nada. La X, tocar fuera o cancelar el aviso del teléfono lo cierran y queda el login con contraseña.
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Dialog(
      key: const Key('biometric-login-dialog'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PaxLogo(size: 64),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint, size: 36, color: scheme.primary),
                      const SizedBox(width: 16),
                      Icon(Icons.face_outlined, size: 36, color: scheme.primary),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Entrar por biometría', textAlign: TextAlign.center, style: text.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Pon tu huella o mira a la cámara cuando tu teléfono te lo pida.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Si prefieres tu contraseña, cierra este recuadro.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
                icon: const Icon(Icons.close),
                onPressed: _close,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
